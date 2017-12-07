/**********************************************************************
* Felix Winterstein, Imperial College London, 2016
*
* File: filter_stream.cl
*
* Revision 1.01
* Additional Comments: distributed under an Apache-2.0 license, see LICENSE
*
**********************************************************************/

#include "snode.h"
#include "snode.cl"
#include "dyn_mem_alloc.cl"

#define CENTER_SET_POOL_SIZE    512
#define STACK_SIZE              1024

#define BATCH_SIZE              128

//#define DEBUG
//#define PROFILE

#pragma OPENCL EXTENSION cl_altera_channels : enable

typedef struct __attribute__ ((packed)) _chan0_t {
    uchar ctrl;
    stack_t s;
} chan0_t;
channel chan0_t chan0_data __attribute__((depth(BATCH_SIZE)));

typedef struct __attribute__ ((packed)) _chan1_t {
    uchar ctrl;
    svm_pointer_t u;
    kdTree_t tn;
    center_set_pointer_t cs;
    bool d;
    center_index_t current_k;
    center_index_t current_indices;
    data_type current_centers;
} chan1_t;
channel chan1_t chan1_data __attribute__((depth(BATCH_SIZE)));

typedef center_set_pointer_t chan2_t;
channel chan2_t chan2_data __attribute__((depth(CENTER_SET_POOL_SIZE)));


typedef struct __attribute__ ((packed)) _chan3_t {
    uchar ctrl;
    uint count;
    data_type wgtCent;
    distance_type sum_sq;
    center_index_t search_idx;
} chan3_t;
channel chan3_t chan3_data __attribute__((depth(BATCH_SIZE)));


// multiply and scale two coords
distance_type mul_scale(coord_type op1, coord_type op2)
{
    coord_type tmp_op1 = op1;
    coord_type tmp_op2 = op2;
    distance_type result = (distance_type)(tmp_op1*tmp_op2);
    result = result >> FRACTIONAL_BITS;
    return result;
}

// inner product of p1 and p2
void dot_product(data_type p1,data_type p2, distance_type *r)
{
    distance_type tmp = 0;
    #pragma unroll
    for (uint d=0;d<D;d++) {
        distance_type tmp_mul = p1.value[d]*p2.value[d];
        tmp += tmp_mul;       
    }
    *r = tmp;    
}

// compute the Euclidean distance between p1 and p2
void compute_distance(data_type p1, data_type p2, distance_type *dist)
{        
    distance_type tmp_dist = 0;
    
    #pragma unroll
    for (uint d=0; d<D; d++) {
        coord_type tmp = p1.value[d]-p2.value[d];
        distance_type tmp_mul = mul_scale(tmp,tmp);
        tmp_dist += tmp_mul;
    }
    *dist = tmp_dist;
}

// find center closest to a given point
void find_closest_center_to_point(data_type p, data_type *cntr_positions, center_index_t *cntr_idxs, center_index_t k, center_index_t *idx, data_type *c_closest)
{
    distance_type min_dist;
    center_index_t min_idx;
    data_type best_z;              

    for (uint i=0; i<k; i++) {
        distance_type tmp_dist;
        center_index_t tmp_idx = cntr_idxs[i];
        data_type c = cntr_positions[tmp_idx];
        compute_distance(p, c, &tmp_dist);

        bool update = (tmp_dist < min_dist) || (i==0);
        min_dist = (update) ? tmp_dist : min_dist;
        min_idx = (update) ? tmp_idx : min_idx;  
        best_z = (update) ? c : best_z;  

        #ifdef DEBUG
        printf("center %u: %d %d %d (dist = %d) (min_dist=%d)\n", tmp_idx, c.value[0], c.value[1], c.value[2],tmp_dist,min_dist);
        #endif

    }
    *idx = min_idx;
    *c_closest = best_z;
}


// check whether any point of bounding box is closer to z than to z*
void tooFar(data_type closest_cand, data_type cand, data_type bnd_lo, data_type bnd_hi, bool *too_far)
{

    distance_type boxDot = 0;
    distance_type ccDot = 0;
            
    #pragma unroll
    for (uint d = 0; d<D; d++) {
        coord_type ccComp = cand.value[d] - closest_cand.value[d];
        distance_type tmp_mul = mul_scale(ccComp,ccComp);
        ccDot += tmp_mul;      
        coord_type bnd = (ccComp > 0) ? bnd_hi.value[d] : bnd_lo.value[d];
 
        coord_type tmp_diff2 = bnd - closest_cand.value[d];
        boxDot += mul_scale(tmp_diff2,ccComp);     
    }
    *too_far = ( ccDot > (boxDot<<1) );
}



__kernel void filter0 ( svm_pointer_t root,
                        uint k,
                        __global uint16 *restrict tree_memory,
                        __global int4 *restrict initial_centers,
                        __global uint *restrict visited_nodes
                        //__global int4 *restrict new_centers,
                        //__global int *restrict distortion
                     )
{

    // initialize dynamically allocated pool of center sets   
    center_index_t cs_pool[KMAX*CENTER_SET_POOL_SIZE];
    center_set_pointer_t freelist[CENTER_SET_POOL_SIZE];

    center_set_pointer_t next_free_location;
    kernel_init_allocator(freelist, &next_free_location, CENTER_SET_POOL_SIZE);
    center_set_pointer_t cs_0 = kernel_malloc(freelist, &next_free_location);
    center_set_pointer_t max_alloc = 0;
    center_set_pointer_t heap_consumption = 1;
    for (center_index_t i=0; i<k; i++) {
        cs_pool[(cs_0 << KMAX_BITS) + i] = i;
    }


    // initialize stack
    stack_t s0;
    s0.u = root;
    s0.c = cs_0;
    s0.d = false;
    s0.k = k;

    __local stack_t stack[STACK_SIZE];
    stack[0] = s0;
    uint sp = 1;
 
    // buffer current centers locally
    data_type current_centers[KMAX];
    for (center_index_t i=0; i<k; i++) {
        current_centers[i] = vector_2_data_type(initial_centers[i]);
    }


    // initialize visited nodes counter
    uint vn = 0;

    bool terminate = false;

    #ifdef PROFILE
    ulong cumulative_rd_count = 0;
    ulong batch_count = 0;
    #endif

    do {    


        uint read_counter = 0;
        uint cumulative_k = 0;
        uint r_sp = sp;

        do {    
            r_sp--; 
            stack_t s = stack[(sp!=0) ? r_sp : 0];
            chan0_t ch0_data;
            ch0_data.ctrl = (sp!=0) ? 1 : 0;
            ch0_data.s = s;
            cumulative_k += (sp!=0) ? s.k : 1;
            read_counter++;
            write_channel_altera(chan0_data,ch0_data);
        }  while ( (sp!=0) && (r_sp!=0) && (read_counter < BATCH_SIZE));

        #ifdef PROFILE
        cumulative_rd_count = cumulative_rd_count+cumulative_k;
        batch_count = batch_count+1;
        #endif

        sp = r_sp;

        chan0_t s_record0;
        kdTree_t tn0;
        center_index_t search_idx0;
        data_type search_centre0;        
        distance_type min_dist0;
        center_index_t min_idx0;
        data_type best_z0;

        chan1_t s_record1;
        center_set_pointer_t new_cs1;
        center_index_t new_k1;
        center_index_t new_idx;
        bool max_heap_usage_reached1;

        uint inner_iteration_index0 = 0;
        uint outer_iteration_index0 = 0;
        uint readout_counter = 0;
        
        for (uint process_counter=0; process_counter<cumulative_k; process_counter++) {

            bool batch_start = (inner_iteration_index0 == 0);

            if (batch_start) {
                s_record0 = read_channel_altera(chan0_data);
            }
            svm_pointer_t u             = s_record0.s.u;
            center_set_pointer_t cs     = s_record0.s.c;
            center_index_t current_k    = s_record0.s.k;
            bool terminate_loop         = (s_record0.ctrl == 0);     

            bool batch_end = (inner_iteration_index0 == current_k-1);

            // fetch tree node from memory                
            if (batch_start && !terminate_loop) {
                tn0 = vector_2_kdTree_t(tree_memory[u]);                
            }

            // compute mid point
            data_type midPoint;
            #pragma unroll
            for (uint d=0; d<D; d++) {
                midPoint.value[d] = (tn0.bnd_lo.value[d] + tn0.bnd_hi.value[d]) >> 1;
            }

            // determine comparison point for closest-distance-search depending on whether we are at a leaf node or not
            data_type comp_point = ( (tn0.left == 0) && (tn0.right == 0) ) ? tn0.wgtCent : midPoint; 

            #ifdef DEBUG
            if (batch_start) {
                //printf("u: %u\n",u);
                printf("comp_point: %d %d %d\n",comp_point.value[0], comp_point.value[1], comp_point.value[2]);
            }
            #endif


            // find closest center (and its index) to comp_point              
            distance_type tmp_dist;
            center_index_t tmp_idx;
            if (!terminate_loop)
                tmp_idx = cs_pool[(cs << KMAX_BITS)+inner_iteration_index0];
            else
                tmp_idx = 0;
            data_type c = current_centers[tmp_idx];
            compute_distance(comp_point, c, &tmp_dist);

            bool update = (tmp_dist < min_dist0) || (inner_iteration_index0==0);
            min_dist0 = (update) ? tmp_dist : min_dist0;
            min_idx0= (update) ? tmp_idx : min_idx0;  
            best_z0 = (update) ? c : best_z0;   

            #ifdef DEBUG
            printf("center %u: %d %d %d (dist = %d) (min_dist=%d)\n", tmp_idx, c.value[0], c.value[1], c.value[2],tmp_dist,min_dist0);
            #endif               

            search_idx0 = (batch_end) ? min_idx0 : search_idx0;
            search_centre0 = (batch_end) ? best_z0 : search_centre0;            
            
            if (batch_end || terminate_loop) {
                chan1_t w;
                w.ctrl = (!terminate_loop) ? 1 : 0;
                w.u = u;
                w.tn = tn0;
                w.cs = cs;
                w.current_k = current_k;
                w.d = s_record0.s.d;
                w.current_indices = search_idx0;
                w.current_centers = search_centre0;
                write_channel_altera(chan1_data,w);

                //printf("%u: search center %u: %d %d %d\n", outer_iteration_index0, search_idx0, search_centre0.value[0], search_centre0.value[1], search_centre0.value[2]);
                //printf("filter0: u=%u, l=%u, r=%u, cs=%u, d=%u, k=%u, z*=%d %d %d\n",u, tn0.left, tn0.right, cs, s_record0.s.d ? 1 : 0, current_k,search_centre0.value[0],search_centre0.value[1],search_centre0.value[2]);

                #ifdef DEBUG
                printf("vn: %u\n", vn);
                #endif
            }

            vn = (batch_end && !terminate_loop) ? vn+1 : vn;            

            outer_iteration_index0 = (batch_end) ? outer_iteration_index0+1 : outer_iteration_index0;
            inner_iteration_index0 = (batch_end) ? 0 : inner_iteration_index0 +1; 



        } // end of for

        uint inner_iteration_index1 = 0;
        uint outer_iteration_index1 = 0;
        new_idx = 0;

        #pragma ivdep array(cs_pool)
        #pragma ivdep array(stack)
        #pragma ivdep array(freelist)
        for (uint process_counter=0; process_counter<cumulative_k; process_counter++) {

            bool batch_start = (inner_iteration_index1 == 0);

            if (batch_start) {
                s_record1  = read_channel_altera(chan1_data);
            }
            svm_pointer_t u             = s_record1.u;
            kdTree_t tn1                = s_record1.tn;
            center_set_pointer_t cs     = s_record1.cs;
            bool d                      = s_record1.d;
            center_index_t current_k    = s_record1.current_k;
            bool terminate_loop         = (s_record1.ctrl == 0);

            center_index_t search_idx1 = s_record1.current_indices;
            data_type search_centre1 = s_record1.current_centers;

            bool batch_end = (inner_iteration_index1 == current_k-1);


            center_index_t idx;
            if (!terminate_loop)
                idx = cs_pool[(cs << KMAX_BITS)+inner_iteration_index1];
            else
                idx = 0;
            data_type c = current_centers[idx];

            if (batch_start && !terminate_loop) {
                
                max_alloc = (max_alloc<heap_consumption) ? heap_consumption : max_alloc;
                max_heap_usage_reached1 = (heap_consumption >= CENTER_SET_POOL_SIZE-4);
                
                /*
                bool not_empty;
                center_set_pointer_t delayed_cs = read_channel_nb_altera(chan2_data, &not_empty);

                new_cs1 = fused_kernel_conditional_free_malloc(freelist, &next_free_location, cs, d, delayed_cs, not_empty, max_heap_usage_reached1, cs_0);

                if (max_heap_usage_reached1)
                    heap_consumption = (d && not_empty) ? heap_consumption-1 : ((!d && !not_empty) ? heap_consumption+1 : heap_consumption);
                else
                    heap_consumption = (d && not_empty) ? heap_consumption-2 : ((!d && !not_empty) ? heap_consumption : heap_consumption-1);
                */

                bool not_empty;
                center_set_pointer_t delayed_cs;
                if (!d) {
                    delayed_cs = read_channel_nb_altera(chan2_data, &not_empty);
                }
                center_set_pointer_t cs_to_delete = (d) ? cs : delayed_cs;

                new_cs1 = fused_kernel_conditional_free_malloc(freelist, &next_free_location, cs_to_delete, d || not_empty, max_heap_usage_reached1, cs_0);

                if (!max_heap_usage_reached1)
                    heap_consumption = (d || not_empty) ? heap_consumption : heap_consumption+1;
                else
                    heap_consumption = (d || not_empty) ? heap_consumption-1 : heap_consumption;

            }

            // candidate pruning and calculation of new value for k  

            bool too_far;
            tooFar(search_centre1, c, tn1.bnd_lo, tn1.bnd_hi, &too_far);
            bool write_new_center = (too_far==false);
            if (write_new_center && !max_heap_usage_reached1 && !terminate_loop) {        
                cs_pool[(new_cs1 << KMAX_BITS)+new_idx] = idx;
                #ifdef DEBUG
                printf("%u: new center %u\n",new_idx, idx);
                #endif 
            }
            new_idx = (batch_end) ? 0 : ((write_new_center && !max_heap_usage_reached1 ) ? new_idx+1 : new_idx);


            if (batch_start)
                new_k1 = (max_heap_usage_reached1) ? k : (( too_far==false ) ? 1 : 0);
            else
                new_k1 = (max_heap_usage_reached1) ? k : (( too_far==false ) ? new_k1+1 : new_k1);

            #ifdef DEBUG
            if (batch_end) {
                //printf("new k: %u\n", new_k1);
                #ifdef DEBUG
                printf("\n");
                #endif 
            }
            #endif
         
            // update distortion per centroid             
            data_type wgtCent_scaled = tn1.wgtCent;
            #pragma unroll
            for (uint d=0; d<D; d++) {
                wgtCent_scaled.value[d] = wgtCent_scaled.value[d]>>FRACTIONAL_BITS;
            }
            coord_type tmp1, tmp2, tmp3;         
            dot_product(search_centre1,wgtCent_scaled,&tmp1);
            dot_product(search_centre1,search_centre1,&tmp2);
                    
            tmp3 = (tmp2>>FRACTIONAL_BITS)*tn1.count;
            distance_type new_sum_sq = tn1.sum_sq+tmp3-2*tmp1;           

            bool deadend = ((tn1.left == 0) && (tn1.right == 0)) || (new_k1 == 1);

            if (batch_end && !terminate_loop) {

                if (deadend && !max_heap_usage_reached1) {
                    write_channel_altera(chan2_data, new_cs1);
                }  

                if ( !deadend) {
                    
                    stack_t st0;
                    st0.u = tn1.right;
                    st0.c = new_cs1;
                    st0.k = new_k1;
                    st0.d = (max_heap_usage_reached1) ? false : true;
                    stack[sp] = st0;                    

                    stack_t st1;
                    st1.u = tn1.left;
                    st1.c = new_cs1;
                    st1.k = new_k1;
                    st1.d = false;
                    stack[sp+1] = st1;          
                    sp+=2;

                } 
            }

            if ((batch_end && deadend) || terminate_loop ) {
                
                terminate = terminate_loop;

                chan3_t ch3_data;
                ch3_data.ctrl = (!terminate_loop) ? 1 : 0;
                ch3_data.wgtCent = tn1.wgtCent;
                ch3_data.sum_sq = new_sum_sq;
                ch3_data.count = tn1.count;
                ch3_data.search_idx = search_idx1;
                write_channel_altera(chan3_data,ch3_data);
            }

            outer_iteration_index1 = (batch_start) ? outer_iteration_index1+1 : outer_iteration_index1;
            inner_iteration_index1 = (batch_end) ? 0 : inner_iteration_index1 +1; 

        } // end of for
        
    } while (!terminate);

    #ifdef PROFILE
    printf("Net heap consumption: %u, max heap consumption: %u\n", heap_consumption, max_alloc);
    printf("av read count: %lu, batch counter: %lu\n", cumulative_rd_count/batch_count,batch_count);
    #endif

    visited_nodes[0] = vn;



}


__kernel void filter1 ( uint k,
                        __global int4 *restrict new_centers,
                        __global int *restrict distortion
                     )
{
    // set up centroid buffer
    centroid_t centroid_buffer[KMAX];

    bool terminate;

    bool one_hot = true;
    //#pragma ivdep
    do {

        chan3_t ch3_data = read_channel_altera(chan3_data);   
        
        terminate = (ch3_data.ctrl == 0);
        center_index_t search_idx = ch3_data.search_idx;
        distance_type sum_sq = ch3_data.sum_sq;
        uint count = ch3_data.count;
        data_type wgtCent = ch3_data.wgtCent;
    
        if (!terminate) {
            centroid_t selected_centroid = centroid_buffer[search_idx];
            distance_type prev_sum_sq = (!one_hot) ? centroid_buffer[search_idx].sum_sq : 0;
            data_type prev_wgtCent;
            #pragma unroll
            for (uint d=0; d<D; d++) {
                prev_wgtCent.value[d] = (!one_hot) ? centroid_buffer[search_idx].wgtCent.value[d] : 0;
            }
            uint prev_count = (!one_hot) ? centroid_buffer[search_idx].count : 0;
            
            #pragma unroll
            for (uint d=0; d<D; d++) {
                centroid_buffer[search_idx].wgtCent.value[d] = /*prev_wgtCent.value[d] +*/ wgtCent.value[d];
            }
            centroid_buffer[search_idx].sum_sq = /*prev_sum_sq  +*/ sum_sq;
            centroid_buffer[search_idx].count = /*prev_count +*/ count; 
        }

        one_hot = false;

    } while (!terminate);

    for(uint i=0; i<k; i++) {
        
        data_type c; 
        uint count = centroid_buffer[i].count;
        count = (count == 0) ? 1 : count;
        #pragma unroll 1
        for (uint d=0; d<D; d++) {
            c.value[d] = centroid_buffer[i].wgtCent.value[d] / (coord_type)count;
        }
        new_centers[i] = data_type_2_vector(c);
        
        distortion[i] = centroid_buffer[i].sum_sq;
    }

}



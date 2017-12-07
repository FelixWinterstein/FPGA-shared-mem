/**********************************************************************
* Felix Winterstein, Imperial College London, 2016
*
* File: build_kdTree.cpp
*
* Revision 1.01
* Additional Comments: distributed under an Apache-2.0 license, see LICENSE
*
**********************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <math.h>
#include "build_kdTree.h"


uint buildkdTree(data_type *data_points, uint *idx, uint n, data_type *bnd_lo, data_type *bnd_hi, uint *heap_ptr, cl_uint16 *tree_memory)
{        
    if (n <= 1) {
        
        kdTree_t leaf_node;        
        
        //compute sum of squares for this point
        distance_type tmp_sum_sq = 0;
        for(uint d=0; d<D; d++) {
            distance_type tmp = get_coord(data_points,idx,0,d);
            tmp_sum_sq += tmp*tmp;
        }                      
        
        leaf_node.bnd_hi    = *bnd_hi;
        leaf_node.bnd_lo    = *bnd_lo;
        leaf_node.left      = 0;
        leaf_node.right     = 0;
        leaf_node.wgtCent   = data_points[*(idx+0)]; // this is just the point itself
        leaf_node.sum_sq    = tmp_sum_sq;
        leaf_node.count     = n;      

        cl_uint16 leaf_node_conv = kdTree_t_2_vector(leaf_node);

        uint tmp_ptr = *heap_ptr+1;        
        *heap_ptr = tmp_ptr;  
        tree_memory[tmp_ptr] = leaf_node_conv;           

        return tmp_ptr;        

    } else {      

        uint n_lo;
        uint cdim;
        coord_type cval;
        uint left;
        uint right;
        
        split_bounding_box(data_points, idx, n, bnd_lo, bnd_hi, &n_lo, &cdim, &cval);
     
        coord_type hv = bnd_hi->value[cdim];
        coord_type lv = bnd_lo->value[cdim];

        //left subtree
        bnd_hi->value[cdim] = cval;
        left = buildkdTree(data_points,idx,n_lo, bnd_lo, bnd_hi, heap_ptr, tree_memory); 
        bnd_hi->value[cdim] = hv;

        //right subtree
        bnd_lo->value[cdim] = cval;
        right = buildkdTree(data_points,idx+n_lo,n-n_lo, bnd_lo, bnd_hi, heap_ptr, tree_memory);
        bnd_lo->value[cdim] = lv;           
        
        // compute sums
        kdTree_t tmp_left, tmp_right;
        tmp_left    = vector_2_kdTree_t(tree_memory[left]);
        tmp_right   = vector_2_kdTree_t(tree_memory[right]);
        data_type tmp_wgtCent;
        for (uint d=0; d<D; d++) {
            tmp_wgtCent.value[d] = tmp_left.wgtCent.value[d] + tmp_right.wgtCent.value[d];
        }
        distance_type tmp_sum_sq = tmp_left.sum_sq + tmp_right.sum_sq;

        
        kdTree_t int_node;            

        int_node.wgtCent    = tmp_wgtCent;
        int_node.sum_sq     = tmp_sum_sq;
        int_node.left       = left;
        int_node.right      = right;
        int_node.bnd_hi     = *bnd_hi;
        int_node.bnd_lo     = *bnd_lo;        
        int_node.count      = n;   

        cl_uint16 int_node_conv = kdTree_t_2_vector(int_node);

        uint tmp_ptr = *heap_ptr+1;        
        *heap_ptr = tmp_ptr;                  
        tree_memory[tmp_ptr] = int_node_conv;

        return tmp_ptr;

    }
    
}



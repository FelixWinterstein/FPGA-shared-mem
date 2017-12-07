/**********************************************************************
* Felix Winterstein, Imperial College London, 2016
*
* File: my_util.hpp
*
* Revision 1.01
* Additional Comments: distributed under an Apache-2.0 license, see LICENSE
*
**********************************************************************/

#ifndef MY_UTIL_H
#define MY_UTIL_H

#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <math.h>

#include <limits.h>

#include "CL/opencl.h"

#define D 3     // data dimensionality

typedef int coord_type;
typedef int distance_type;

// data point types
struct point_type {
    coord_type value[D];    
};
typedef struct point_type data_type;


// tree node types
typedef struct __attribute__((packed)) _kdTree_t {
    //data_type point;
    uint count;
    data_type wgtCent;
    distance_type sum_sq;
    data_type bnd_lo;
    data_type bnd_hi;
    uint left;
    uint right;
} kdTree_t;




//helper macros
#define get_coord(points, indx, idx, dim) ( (points+*(indx+idx))->value[dim] )
#define coord_swap(indx, i1, i2) { uint tmp = *(indx+i1);\
                                    *(indx+i1) = *(indx+i2);\
                                    *(indx+i2) = tmp; }

data_type vector_2_data_type(cl_int4 v) {
    data_type d;

    d.value[0] = v.s0;
    d.value[1] = v.s1;
    d.value[2] = v.s2;

    return d;
}

cl_int4 data_type_2_vector(data_type d) {
    cl_int4 v;

    v.s0 = d.value[0];
    v.s1 = d.value[1];
    v.s2 = d.value[2];
    v.s3 = 0;

    return v;
}



kdTree_t vector_2_kdTree_t(cl_uint16 v) {
    kdTree_t tn;

    tn.count = v.s0;

    tn.wgtCent.value[0] = v.s1;
    tn.wgtCent.value[1] = v.s2;
    tn.wgtCent.value[2] = v.s3;

    tn.sum_sq = v.s4;

    tn.bnd_lo.value[0] = v.s5;
    tn.bnd_lo.value[1] = v.s6;
    tn.bnd_lo.value[2] = v.s7;

    tn.bnd_hi.value[0] = v.s8;
    tn.bnd_hi.value[1] = v.s9;
    tn.bnd_hi.value[2] = v.sa;

    tn.left = v.sb;
    tn.right = v.sc;

    return tn;
}

cl_uint16 kdTree_t_2_vector(kdTree_t tn) {
    cl_uint16 v;

    v.s0 = tn.count;

    v.s1 = tn.wgtCent.value[0];
    v.s2 = tn.wgtCent.value[1];
    v.s3 = tn.wgtCent.value[2];

    v.s4 = tn.sum_sq;

    v.s5 = tn.bnd_lo.value[0];
    v.s6 = tn.bnd_lo.value[1];
    v.s7 = tn.bnd_lo.value[2];

    v.s8 = tn.bnd_hi.value[0];
    v.s9 = tn.bnd_hi.value[1];
    v.sa = tn.bnd_hi.value[2];

    v.sb = tn.left;
    v.sc = tn.right;

    v.sd = 0;
    v.se = 0;
    v.sf = 0;

    return v;
}


void make_data_points_file_name(char *result, uint n, uint k, uint d, double std_dev)
{
    sprintf(result,"./data_points_N%d_K%d_D%d_s%.2f.mat",n,k,d,std_dev);
}

void make_initial_centres_file_name(char *result, uint n, uint k, uint d, double std_dev, uint index)
{
    sprintf(result,"./initial_centers_N%d_K%d_D%d_s%.2f_%d.mat",n,k,d,std_dev,index);
}


bool read_data_points(uint n, uint k, double std_dev, data_type* points, uint* index)
{
    FILE *fp;
    
    char filename[256];
    make_data_points_file_name(filename,n,k,D,std_dev);

    printf("Reading file: %s\n",filename);

    fp=fopen(filename, "r");

    if (!fp)
        return false;

    char tmp[16];
    
    for (uint j=0; j<D; j++) {   
        for (uint i=0;i<n;i++) {
            if (fgets(tmp,16,fp) == 0) {
                fclose(fp);
                return false;                
            } else {
                //printf("%s\n",tmp);
                points[i].value[j]=atoi(tmp); // assume coord_type==int                
            }
        }
    }

    for (uint i=0;i<n;i++) {
        *(index+i) = i;
    }    
    
    fclose(fp);
    
    return true;
}

bool read_initial_centres(uint n, uint k, double std_dev, uint* cntr_idx)
{
    FILE *fp;

    char filename[256];
    make_initial_centres_file_name(filename,n,k,D,std_dev,1);

    printf("Reading file: %s\n",filename);

    fp=fopen(filename, "r");

    if (!fp)
        return false;

    char tmp[16];
    
    for (uint i=0;i<k;i++) {
        if (fgets(tmp,16,fp) == 0) {
            fclose(fp);
            return false;                
        } else {
            *(cntr_idx+i)=atoi(tmp); // assume coord_type==int
        }
    }

    
    fclose(fp);
    
    return true;
}




// find min/max in one dimension
void find_min_max(data_type *data_points, uint *idx , uint dim, uint n, coord_type *ret_min, coord_type *ret_max)
{    
    coord_type min = get_coord(data_points,idx,0,dim);
    coord_type max = get_coord(data_points,idx,0,dim);
    coord_type tmp;
    // inefficient way of searching the min/max
    for (int i=0; i<n; i++) {
        tmp = get_coord(data_points,idx,i,dim);        
        if (tmp < min) {
            min = tmp;
        }        
        if (tmp >= max) {
            max = tmp;
        }
    }

    *ret_min = min;
    *ret_max = max;
}

// ...
void dot_product(data_type p1,data_type p2, coord_type *r)
{
    coord_type tmp = 0;
    for (uint d=0;d<D;d++) {
        tmp += p1.value[d]*p2.value[d];
    }
    *r = tmp;
}


// bounding box is characterised by two points: low and high corner
void compute_bounding_box(data_type *data_points, uint *idx, uint n, data_type *bnd_lo, data_type *bnd_hi)
{
    coord_type max;
    coord_type min;
    
    for (uint i=0;i<D;i++) {
        find_min_max(data_points, idx,i,n,&min,&max);
        bnd_lo->value[i] = min;
        bnd_hi->value[i] = max;
    }
}


/*
 * The splitting routine is essentially a median search,
 * i.e. finding the median and split the array about it.
 * There are several algorithms for the median search
 * (an overview is given at http://ndevilla.free.fr/median/median/index.html):
 * - AHU (1)
 * - WIRTH (2)
 * - QUICKSELECT (3)
 * - TORBEN (4)
 * (1) and (2) are essentially the same in recursive and non recursive versions.
 * (2) is among the fastest in sequential programs.
 * (3) is similar to what quicksort uses and is as fast as (2).
 * Both (2) and (3) require permuting array elements.
 * (4) is significantly slower but only reads the array without modifying it.
 * The implementation below is a simplified version of (2).
 
*/

void split_bounding_box(data_type *data_points, uint *idx, uint n, data_type *bnd_lo, data_type *bnd_hi, uint *n_lo, uint *cdim, coord_type *cval)
{
    // search for dimension with longest egde
    coord_type longest_egde = bnd_hi->value[0] - bnd_lo->value[0];    
    uint dim = 0;
    
    for (uint d=0; d<D; d++) {        
        coord_type tmp = bnd_hi->value[d] - bnd_lo->value[d];
        if (longest_egde < tmp) {
            longest_egde = tmp;
            dim = d;
        }            
    }
    
    *cdim = dim;
    
    coord_type ideal_threshold = (bnd_hi->value[dim] + bnd_lo->value[dim]) / 2;    
    coord_type min,max;
    
    find_min_max(data_points,(idx+0),dim,n,&min,&max);
    
    coord_type threshold = ideal_threshold;
    
    if (ideal_threshold < min) {
        threshold = min;
    } else if (ideal_threshold > max) {
        threshold = max;
    }
    
    *cval = threshold;
    
    // Wirth's method
    int l = 0;
    int r = n-1;
       
    for(;;) {				// partition points[0..n-1]
	    while (l < n && get_coord(data_points,idx+0,l,dim) < threshold) l++;
	    while (r >= 0 && get_coord(data_points,idx+0,r,dim) >= threshold) r--;
	    if (l > r)
            break; 
	    coord_swap(idx+0,l,r);
	    l++; r--;
    }
    
    uint br1 = l;			// now: data_points[0..br1-1] < threshold <= data_points[br1..n-1]
    r = n-1;
    for(;;) {				// partition pa[br1..n-1] about threshold
	    while (l < n && get_coord(data_points,idx+0,l,dim) <= threshold) l++;
	    while (r >= br1 && get_coord(data_points,idx+0,r,dim) > threshold) r--;
	    if (l > r)
            break; 
    	coord_swap(idx+0,l,r);
	    l++; r--;
    }
    uint br2 = l;			// now: points[br1..br2-1] == threshold < points[br2..n-1]
    
    if (ideal_threshold < min) *n_lo = 0+1;
    else if (ideal_threshold > max) *n_lo = n-1;
    else if (br1 > n/2) *n_lo = br1;
    else if (br2 < n/2) *n_lo = br2;
    else *n_lo = n/2;
}


void compute_distance(data_type p1, data_type p2, coord_type *dist)
{
    coord_type tmp_dist = 0;
    for (uint i=0; i<D; i++) {
        coord_type tmp = p1.value[i]-p2.value[i];
        tmp_dist += (tmp*tmp);
    }
    *dist = tmp_dist;
}



#endif

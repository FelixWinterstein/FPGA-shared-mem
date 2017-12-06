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

//#define PAGE_ALIGNED_ALLOC

kdTree_t* buildkdTree(data_type *data_points, uint *idx, uint n, data_type *bnd_lo, data_type *bnd_hi)
{        
    if (n <= 1) {
        
        kdTree_t* leaf_node;
        
        #ifndef PAGE_ALIGNED_ALLOC
        leaf_node = new kdTree_t;
        #else        
        if (posix_memalign((void**)&leaf_node, 64, 64) != 0)
            printf("posix_memalign failure\n");
        #endif
        
        //compute sum of squares for this point
        distance_type tmp_sum_sq = 0;
        for(uint d=0; d<D; d++) {
            coord_type tmp = get_coord(data_points,idx,0,d);
            tmp_sum_sq += tmp*tmp;
        }  

        
        leaf_node->bnd_hi = *bnd_hi;
        leaf_node->bnd_lo = *bnd_lo;
        leaf_node->left = 0;
        leaf_node->right = 0;
        leaf_node->wgtCent = data_points[*(idx+0)]; // this is just the point itself
        leaf_node->sum_sq = tmp_sum_sq;
        leaf_node->count = n;                

        return leaf_node;        

    } else {      

        uint n_lo;
        uint cdim;
        coord_type cval;
        kdTree_t* left;
        kdTree_t* right;
        
        split_bounding_box(data_points, idx, n, bnd_lo, bnd_hi, &n_lo, &cdim, &cval);
     
        coord_type hv = bnd_hi->value[cdim];
        coord_type lv = bnd_lo->value[cdim];

        //left subtree
        bnd_hi->value[cdim] = cval;
        left = buildkdTree(data_points,idx,n_lo, bnd_lo, bnd_hi); 
        bnd_hi->value[cdim] = hv;

        //right subtree
        bnd_lo->value[cdim] = cval;
        right = buildkdTree(data_points,idx+n_lo,n-n_lo, bnd_lo, bnd_hi);
        bnd_lo->value[cdim] = lv;           
        
        // compute sums
        data_type tmp_wgtCent;
        for (uint d=0; d<D; d++) {
            tmp_wgtCent.value[d] = left->wgtCent.value[d] + right->wgtCent.value[d];
        }
        distance_type tmp_sum_sq = left->sum_sq + right->sum_sq;

        #ifndef PAGE_ALIGNED_ALLOC
        kdTree_t* int_node = new kdTree_t;
        #else
        kdTree_t *int_node;
        if (posix_memalign((void**)&int_node, 64, 64) != 0)
            printf("posix_memalign failure\n");
        #endif
        
        int_node->count = n;   
        int_node->wgtCent = tmp_wgtCent;
        int_node->sum_sq = tmp_sum_sq;
        int_node->bnd_lo = *bnd_lo;   
        int_node->bnd_hi = *bnd_hi;   
        int_node->left = left;
        int_node->right = right;  
        

        return int_node;
        
        //printf("%d %d\n",int_node->count, int_node->sum_sq);
    }
    
}

void deletekdTree(kdTree_t* u) {
    if ((u->left == NULL) && (u->right == NULL)) {


    } else {
        kdTree_t t = *u;

        //printf("count=%u\n",t.count);

        #ifndef PAGE_ALIGNED_ALLOC
        delete u;
        #else
        free(u);
        #endif
        deletekdTree(t.left);
        deletekdTree(t.right);
    }
}


/**********************************************************************
* Felix Winterstein, Imperial College London, 2016
*
* File: snode.h
*
* Revision 1.01
* Additional Comments: distributed under an Apache-2.0 license, see LICENSE
*
**********************************************************************/

#ifndef SNODE_H_
#define SNODE_H_

#define D 3                         // data dimensionality
#define KMAX_BITS 8                 // number of bits to index a center in a center set of maximal size
#define KMAX (1<<KMAX_BITS)         // max number of centers

#define FRACTIONAL_BITS  6

#if KMAX_BITS <= 8
typedef uchar center_index_t;
#elif KMAX_BITS>8 && KMAX_BITS <= 16
typedef ushort center_index_t;
#else
typedef uint center_index_t;
#endif

typedef uint center_set_pointer_t;
typedef uint svm_pointer_t;

typedef int coord_type;
typedef int distance_type;

// data point types
typedef struct /*__attribute__ ((packed))*/ _data_type {
    coord_type value[D];    
} data_type;

typedef struct /*__attribute__ ((packed))*/ _kdTree_t {
    //data_type point;
    uint count;
    data_type wgtCent;
    distance_type sum_sq;
    data_type bnd_lo;
    data_type bnd_hi;
    svm_pointer_t left;
    svm_pointer_t right;
} kdTree_t;

typedef struct /*__attribute__ ((packed))*/ _stack_t {
    svm_pointer_t u;
    center_set_pointer_t c;
    bool d;
    center_index_t k;
} stack_t;

typedef struct /*__attribute__ ((packed))*/ _centroid_t {
    data_type wgtCent;
    distance_type sum_sq;
    uint count;
} centroid_t;



#endif

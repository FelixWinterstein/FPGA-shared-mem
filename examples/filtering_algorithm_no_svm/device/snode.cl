/**********************************************************************
* Felix Winterstein, Imperial College London, 2016
*
* File: snode.cl
*
* Revision 1.01
* Additional Comments: distributed under an Apache-2.0 license, see LICENSE
*
**********************************************************************/

#include "snode.h"

data_type vector_2_data_type(int4 v) {
    data_type d;

    d.value[0] = v.s0;
    d.value[1] = v.s1;
    d.value[2] = v.s2;

    return d;
}

int4 data_type_2_vector(data_type d) {
    int4 v;

    v.s0 = d.value[0];
    v.s1 = d.value[1];
    v.s2 = d.value[2];
    v.s3 = 0;

    return v;
}


kdTree_t vector_2_kdTree_t(uint16 v) {
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

uint16 kdTree_t_2_vector(kdTree_t tn) {
    uint16 v;

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


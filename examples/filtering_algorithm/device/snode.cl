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


void vector_2_kdTree_t(ulong16 v, kdTree_t *tn, uint16 *profiling) {        

    tn->count = (v.s0 >> 0) & 0xFFFFFFFF;

    tn->wgtCent.value[0] = (v.s0 >> 32) & 0xFFFFFFFF;
    tn->wgtCent.value[1] = (v.s1 >> 0) & 0xFFFFFFFF;
    tn->wgtCent.value[2] = (v.s1 >> 32) & 0xFFFFFFFF;

    tn->sum_sq = (v.s2 >> 0) & 0xFFFFFFFF;

    tn->bnd_lo.value[0] = (v.s2 >> 32) & 0xFFFFFFFF;
    tn->bnd_lo.value[1] = (v.s3 >> 0) & 0xFFFFFFFF;
    tn->bnd_lo.value[2] = (v.s3 >> 32) & 0xFFFFFFFF;

    tn->bnd_hi.value[0] = (v.s4 >> 0) & 0xFFFFFFFF;
    tn->bnd_hi.value[1] = (v.s4 >> 32) & 0xFFFFFFFF;
    tn->bnd_hi.value[2] = (v.s5 >> 0) & 0xFFFFFFFF;

    tn->idx = (v.s5 >> 32) & 0xFFFFFFFF;

    tn->left = (v.s6 >> 0) & 0xFFFFFFFF;
    tn->right = (v.s6 >> 32) & 0xFFFFFFFF;


    profiling->s0 = (v.s8 >> 0) & 0xFFFFFFFF;
    profiling->s1 = (v.s8 >> 32) & 0xFFFFFFFF;
    profiling->s2 = (v.s9 >> 0) & 0xFFFFFFFF;
    profiling->s3 = (v.s9 >> 32) & 0xFFFFFFFF;
    profiling->s4 = (v.sa >> 0) & 0xFFFFFFFF;
    profiling->s5 = (v.sa >> 32) & 0xFFFFFFFF;
    profiling->s6 = (v.sb >> 0) & 0xFFFFFFFF;
    profiling->s7 = (v.sb >> 32) & 0xFFFFFFFF;
    profiling->s8 = (v.sc >> 0) & 0xFFFFFFFF;
    profiling->s9 = (v.sc >> 32) & 0xFFFFFFFF;
    profiling->sa = (v.sd >> 0) & 0xFFFFFFFF;
    profiling->sb = (v.sd >> 32) & 0xFFFFFFFF;
    profiling->sc = (v.se >> 0) & 0xFFFFFFFF;
    profiling->sd = (v.se >> 32) & 0xFFFFFFFF;
    profiling->se = (v.sf >> 0) & 0xFFFFFFFF;
    profiling->sf = (v.sf >> 32) & 0xFFFFFFFF;

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

    v.sb = tn.idx;
    
    v.sc = tn.left;
    v.sd = tn.right;

    v.se = 0;
    v.sf = 0;

    return v;
}


kdTree_t read_snode_bundled(__global int *p0,
                             svm_pointer_t ttbr0, svm_pointer_t addr, uint16 *pinfo)
{
    kdTree_t ret;
    ulong16 recv;
    recv =host_memory_bridge_ld_512bit (p0, ttbr0, addr);


    vector_2_kdTree_t(recv, &ret, pinfo);

    //printf("mem_access_counter=%u, pt_lookup_counter=%u\n", (recv.sf & 0xFFFF0000) >> 16, recv.sf & 0x0000FFFF);

    return ret;
}


void write_snode_bundled(__global int *p0,
                             svm_pointer_t ttbr0, svm_pointer_t addr, kdTree_t data)
{
    // FIXME: implement
    // uint16 data_conv = kdTree_t_2_vector(data);
    // host_memory_bridge_512bit (p0, ttbr0, addr, 1, data_conv);

}



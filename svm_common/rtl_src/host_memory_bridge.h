/**********************************************************************
* Felix Winterstein, Imperial College London, 2016
*
* File: host_memory_bridge.h
*
* Revision 1.01
* Additional Comments: distributed under an Apache-2.0 license, see LICENSE
*
**********************************************************************/

#ifndef HOST_MEMORY_BRIDGE_H_
#define HOST_MEMORY_BRIDGE_H_

typedef struct __attribute__ ((packed)) _svm_ret_type_uint2
{
    uint2 retval;
    uint2 status;
} svm_ret_type_uint2;

typedef struct __attribute__ ((packed)) _svm_ret_type_uint4
{
    uint4 retval;
    uint2 status;
} svm_ret_type_uint4;

typedef uint svm_pointer_t;

uint4 host_memory_bridge_ld_32bit (__global int *p0, svm_pointer_t ttbr0, svm_pointer_t va);
uint4 host_memory_bridge_st_32bit (__global int *p0, svm_pointer_t ttbr0, svm_pointer_t va, uint write_data);


//uint16 host_memory_bridge_512bit (__global int *p0, uint ttbr0, uint va, uint write, uint16 write_data);
ulong16 host_memory_bridge_ld_512bit (__global int *p0, svm_pointer_t ttbr0, svm_pointer_t va);

uint host_memory_bridge_aa_32bit (__global int *p0, svm_pointer_t ttbr0, svm_pointer_t lock_location, svm_pointer_t va, uint increment);


uint ddr_memory_bridge_32bit_ld(__global int* p0, uint index);
uint ddr_memory_bridge_32bit_st(__global int* p0, uint index, uint write_data);



#endif



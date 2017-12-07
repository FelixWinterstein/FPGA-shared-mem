/**********************************************************************
* Felix Winterstein, Imperial College London, 2016
*
* File: dyn_mem_alloc.cl
*
* Revision 1.01
* Additional Comments: distributed under an Apache-2.0 license, see LICENSE
*
**********************************************************************/

#include "snode.h"

center_set_pointer_t kernel_malloc(center_set_pointer_t* flist, center_set_pointer_t* next_free_location)
{
	center_set_pointer_t address = *next_free_location;
	*next_free_location = flist[(center_set_pointer_t)address];

	return address;
}

void kernel_free(center_set_pointer_t* flist, center_set_pointer_t* next_free_location, center_set_pointer_t address)
{
	flist[(center_set_pointer_t)address] = *next_free_location;
	*next_free_location = address;
}

void kernel_init_allocator(center_set_pointer_t* flist, center_set_pointer_t* next_free_location, const center_set_pointer_t heapsize)
{
	for (center_set_pointer_t i=0; i<heapsize; i++) {
		flist[(center_set_pointer_t)i] = i+1;
	}
	*next_free_location = 1;
}

center_set_pointer_t fused_kernel_conditional_free_malloc(center_set_pointer_t* flist,
                                                            center_set_pointer_t* next_free_location,
                                                            center_set_pointer_t address,
                                                            bool free_first,
                                                            bool heap_full,
                                                            center_set_pointer_t default_location) {
    center_set_pointer_t new_address;
    if (free_first) {
	    flist[(center_set_pointer_t)address] = *next_free_location;
        if (!heap_full) {
            new_address = address;
        } else {
            *next_free_location = address;
            new_address = default_location;
        }
    } else {
        if (!heap_full) {
    	    new_address = *next_free_location;
    	    *next_free_location = flist[(center_set_pointer_t)new_address];
        } else {
            new_address = default_location;
        }
    }
    return new_address;
}



/**********************************************************************
* Felix Winterstein, Imperial College London, 2016
*
* File: svm_utils.hpp
*
* Revision 1.01
* Additional Comments: distributed under a Apache-2.0 license, see LICENSE
*
**********************************************************************/

#ifndef SVM_BRIDGE_H_
#define SVM_BRIDGE_H_

#define AXI_CACHE_SECRUITY_BRIDGE   0xFF200100
#define LOCK_SERVER_CSR             0xFF200000
#define SCU_CONTROLLER              0xFFFEC000
#define L2_CACHE_CONTROLLER         0xFFFEF000


typedef uint32_t address_t;

#include <stdio.h>
#include <stdlib.h>
#include <math.h>


#include <stddef.h>
#include <assert.h>
#include <errno.h>
#include <string.h>

#include <sys/types.h>
#include <dirent.h>
#include <sys/stat.h>
#include <unistd.h>
#include <fcntl.h>

#include <stdint.h>
#include <assert.h>
#include <sys/mman.h>

#include "svm_utils.hpp"


#define FILENAMELEN         256
#define LINELEN             256
#define PAGE_SIZE           4096
#define MAP_SIZE            4096UL
#define MAP_MASK            (MAP_SIZE  - 1)

#define PROC_DIR_NAME       "/proc"
#define MAPS_NAME           "maps"
#define PAGEMAP_NAME        "pagemap"
// ERR() 
#define ERR(format, ...) fprintf(stderr, format, ## __VA_ARGS__)


//typedef uint lock_register_t;
//static volatile lock_register_t *lock_location = NULL;
#define NO_ACCESS 0
#define DEVICE_ACCESS 1
#define HOST_ACCESS 2


static volatile uint32_t *bus_p_w = NULL;
static volatile uint32_t *bus_p_r = NULL;

/*
* Get a virtual address from a physical one using mmap.
*/
void *getvaddr(off_t phys_addr)
{

    void *virtual_base;
    int memfd;

    void *mapped_dev_base;   

    memfd = open("/dev/mem", O_RDWR|O_SYNC); //to open this the program needs to be run as root
    if (memfd < 0) {
        printf("Can't open /dev/mem.\n");
        exit(0);
    }
    

    // Map one page of memory into user space such that the device is in that page, but it may not
    // be at the start of the page.

    virtual_base = mmap(NULL, PAGE_SIZE, (PROT_READ | PROT_WRITE), MAP_SHARED, memfd, phys_addr & ~MAP_MASK);
    if (virtual_base == MAP_FAILED) {
        printf("Can't map the memory to user space.\n");
        exit(0);
    }
    // get the address of the device in user space which will be an offset from the base
    // that was mapped as memory is mapped at the start of a page

    mapped_dev_base = virtual_base + (phys_addr & MAP_MASK);
    return mapped_dev_base;
}



/*
* Get a physical address from a virtual (doesn not work for mmap'ed va's).
*/
const int __endian_bit = 1;
#define is_bigendian() ( (*(char*)&__endian_bit) == 0 )
address_t lookup_physical_address(address_t va) {

    

    int pid = getpid();
    // Open pid/pagemap file for reading.
    // the pagemap file contains a binary array of 64-bit words, one for each page in process virtual address space, containing the physical address of the mapped page
    char pm_name[FILENAMELEN];
    sprintf(pm_name, "%s/%s/%s", PROC_DIR_NAME, "self", PAGEMAP_NAME);
    int pm = open(pm_name, O_RDONLY);
    if (pm == -1) {
        ERR("Unable to open \"%s\" for reading (errno=%d). (7)\n", pm_name, errno);
        return 0;
    }

    long index = ((unsigned long long)va / PAGE_SIZE) * sizeof(unsigned long long);                         

    // set file descriptor pm to appropriate index of pagemap file.
    off64_t o = lseek64(pm, index, SEEK_SET);
    if (o != index) {
        ERR("Error seeking to %ld in file \"%s\" (errno=%d). (8)\n", index, pm_name, errno);
        close(pm);
        return 0;
    }
     
    // pagemap entry
    unsigned long long pa;

    // Read a 64-bit word from each of the pagemap file
    ssize_t t = read(pm, &pa, sizeof(unsigned long long));
    if (t < 0) {
        ERR("Error reading file \"%s\" (errno=%d). (11)\n", pm_name, errno);
        close(pm);
        return 0;
    }

    if (pm != -1) {
        close(pm);
    }

    pa = pa & 0x7FFFFFFFFFFFFF;
    pa = pa*PAGE_SIZE + ((unsigned long long)va & (PAGE_SIZE-1) );


    return (address_t)pa;

}



/*
* Flush a level 2 cache line. If the byte specified by the address (adr)
* is cached by the Data cache, the cacheline containing that byte is
* invalidated. If the cacheline is modified (dirty), the entire
* contents of the cacheline are written to system memory before the
* line is invalidated.
*/
void flush_L2_cacheline(address_t addr) {

    asm volatile (
            "dsb" "\n\t"
    //      "isb" "\n\t"
    );  

    const unsigned cacheline = 32;
    address_t tmp_addr = addr & ~(cacheline - 1);
    printf("Flushing L2 cache line %08x\n",tmp_addr);
    
    volatile address_t *p2;

    
    // clean L2 line by PA
    p2 = (address_t *)getvaddr(L2_CACHE_CONTROLLER+0x7B0);
    *p2 = tmp_addr;
    // invalidate L2 line by PA
    p2 = (address_t *)getvaddr(L2_CACHE_CONTROLLER+0x770);
    *p2 = tmp_addr;
    
    // clean_inv L2 line by PA
    //p2 = (address_t *)getvaddr(L2_CACHE_CONTROLLER+0x7F0);
    //*p2 = tmp_addr;    


    asm volatile (
            "dsb" "\n\t"
    //      "isb" "\n\t"
    );  

}

/*
* Flush a level 1 Data cache line. If the byte specified by the address (adr)
* is cached by the Data cache, the cacheline containing that byte is
* invalidated.	If the cacheline is modified (dirty), the entire
* contents of the cacheline are written to system memory before the
* line is invalidated.
*/
void flush_L1_cacheline(address_t addr) {

    // flush L1 cache line
    FILE *fp = fopen("/sys/bus/platform/drivers/svm_driver/svm_driver","wb");
    if (fp == NULL) {
        printf("SVM driver not loaded\n");
        return;
    }

    const unsigned cacheline = 32;
    address_t tmp_addr = addr & ~(cacheline - 1);
    printf("Flushing L1 cache line %08x\n",tmp_addr);

    char buf[1+sizeof(address_t)];
    buf[0] = 0x02;   
    putc(buf[0],fp); 
    for (uint i=0; i<sizeof(address_t); i++) {
        buf[i+1] = (tmp_addr & 0xFF);
        putc(buf[i+1],fp);
        tmp_addr = tmp_addr >> 8;
    }

    fclose(fp);
}


/*
* Set the configuration of the AXI cache security bridge to enable the ACP for use.
* Check whether the SCU is enabled.
* Set the SMP bit through a call to the svm_driver kernel module.
*/
void enable_f2h_acp(bool enable)
{

    // SCU enabled?
    volatile address_t *p0 = (address_t*)getvaddr(SCU_CONTROLLER);    
    printf("SCU %s\n", ((*p0) & 0x1) ? "enabled" : "disabled" );

   
    // enable SMP bit, just in case it wasn't
    FILE *fp = fopen("/sys/bus/platform/drivers/svm_driver/svm_driver","wb");
    if (fp == NULL) {
        printf("SVM driver not loaded\n");
        return;
    }
    putc(0x1,fp);
    fclose(fp);

    // set up AXI security bridge for overwriting aX signals
    uint32_t awcache;
    uint32_t awprot;
    uint32_t awuser;
    uint32_t arcache;
    uint32_t aruser;
    uint32_t arprot;

    if(enable)
    {
        awcache = 0xF; // 4'b1111
        awuser  = 0x1; // 5'b00001
        arcache = 0xF; // 4'b1111
        aruser  = 0x1; // 5'b00001
    }
    else
    {
        awcache = 0x1; // 4'b0001
        awuser  = 0x0; // 5'b00000
        arcache = 0x1; // 4'b0001
        aruser  = 0x0; // 5'b0000
    }

    awprot  = 0x4; // 3'b100
    arprot  = 0x4; // 3'b100

    uint32_t *bus_p;

    bus_p = (uint32_t*)getvaddr(AXI_CACHE_SECRUITY_BRIDGE+0x00);
    *(bus_p) = awcache;

    bus_p = (uint32_t*)getvaddr(AXI_CACHE_SECRUITY_BRIDGE+0x04);
    *(bus_p) = awprot;

    bus_p = (uint32_t*)getvaddr(AXI_CACHE_SECRUITY_BRIDGE+0x08);
    *(bus_p) = awuser;

    bus_p = (uint32_t*)getvaddr(AXI_CACHE_SECRUITY_BRIDGE+0x10);
    *(bus_p) = arcache;

    bus_p = (uint32_t*)getvaddr(AXI_CACHE_SECRUITY_BRIDGE+0x14);
    *(bus_p) = arprot;

    bus_p = (uint32_t*)getvaddr(AXI_CACHE_SECRUITY_BRIDGE+0x18);
    *(bus_p) = aruser;

    bus_p = (uint32_t*)getvaddr(AXI_CACHE_SECRUITY_BRIDGE+0x1C);
    *(bus_p) = 0x0;

    printf("F2H ACP cacheable access is switched %s.\n", enable ? "on" : "off");

}


/*
* Flush a TLB entry. The cache line corresponding to the specified address is
* invalidated.	
*/
void flush_TLB() {

    FILE *fp = fopen("/sys/bus/platform/drivers/svm_driver/svm_driver","wb");
    if (fp == NULL) {
        printf("SVM driver not loaded\n");
        return;
    }

    const unsigned cacheline = 32;
    address_t tmp_addr = 0; // not need, deprecated
    printf("Flushing TLB\n");

    char buf[1+sizeof(address_t)];
    buf[0] = 0x03;   
    putc(buf[0],fp); 
    for (uint i=0; i<sizeof(address_t); i++) {
        buf[i+1] = (tmp_addr & 0xFF);
        putc(buf[i+1],fp);
        tmp_addr = tmp_addr >> 8;
    }

    fclose(fp);


    // access svm_driver kernel module for reading debug value foo
    fp = fopen("/sys/bus/platform/drivers/svm_driver/svm_driver","rb");
    if (fp == NULL) {
        printf("SVM driver not loaded\n");
        return;
    }

    address_t value;

    for (address_t i=0; i<2*sizeof(address_t); i++) {
        int c = getc(fp) & 0xFF;
    }

    // read third value from driver (driver-internal debugging variable)
    value=0;
    for (uint i=0; i<sizeof(uint); i++) {
        uint c = getc(fp) & 0xFF;
        value = value | (c << i*8);
    }  
    if (value != 0x12)
        printf("Flush failed\n");

    fclose(fp);

}


address_t get_ttbr0() {

    // access svm_driver kernel module in linux
    FILE *fp = fopen("/sys/bus/platform/drivers/svm_driver/svm_driver","rb");
    if (fp == NULL) {
        printf("SVM driver not loaded\n");
        return 0;
    }

    address_t value;

    // read first value from driver (TTBCR register content of the ARM MMU)
    value=0;
    for (address_t i=0; i<sizeof(address_t); i++) {
        int c = getc(fp) & 0xFF;
        value = value | (c << i*8);
    }
    address_t TTBCR_EAE = (value & (1<<31)) > 0 ? 1 : 0;
    address_t TTBCR_PD1 = (value & (1<<5)) > 0 ? 1 : 0;
    address_t TTBCR_PD0 = (value & (1<<4)) > 0 ? 1 : 0;
    address_t TTBCR_N = value & 0x7;
    printf("TTBCR=%08x, TTBCR_EAE=%u, TTBCR_PD1=%u, TTBCR_PD0=%u, TTBCR_N=%u\n", value, TTBCR_EAE, TTBCR_PD1, TTBCR_PD0, TTBCR_N);

    // read second value from driver (TTBR0 register content of the ARM MMU)
    value=0;
    for (uint i=0; i<sizeof(uint); i++) {
        int c = getc(fp) & 0xFF;
        value = value | (c << i*8);
    }    
    address_t TTBR0_S = (value & (1<<1)) > 0 ? 1 : 0;
    address_t table0_base = value >> 14;    
    address_t ttbr0_value = value;
    printf("TTBR0=%08x, table0_base_addr=%08x, TTBR0_S=%u\n",ttbr0_value,table0_base,TTBR0_S); 

    // read third value from driver (driver-internal debugging variable)
    value=0;
    for (uint i=0; i<sizeof(uint); i++) {
        uint c = getc(fp) & 0xFF;
        value = value | (c << i*8);
    }  
    printf("foo = %08x\n",value);

    fclose(fp);

    return ttbr0_value;
    
}


/*
* Manually walk the page tables of the ARM MMU. 
* Return the physical memory address given a virtual one and the TTBR0 value.
*/
address_t manual_table_walk(void *p, address_t ttbr0_value, bool verbose) {

    address_t p_va = (address_t)p;
    address_t va_table0_index = p_va >> 20; // length 12
    address_t va_table1_index = (p_va & ((1<<20)-1)) >> 12; // length 8
    address_t va_page_index = p_va & ((1<<12)-1); // length 12     
    //printf("p_va=%08x\n", p_va);   

    address_t table0_base = ttbr0_value >> 14;
    address_t table0_desc_addr = (table0_base << 14) | ( va_table0_index << 2 );
    volatile uint *table0_base_ptr = (uint*)getvaddr(table0_desc_addr);
    address_t table0_desc = *table0_base_ptr;
    address_t table0_desc_NS = (table0_desc & (1<<3)) > 0 ? 1 : 0;
    address_t table0_desc_type = table0_desc & 0x3;  
    address_t table1_base = table0_desc >> 10;
    if (verbose)
        printf("table0_desc_addr=%08x, table0_desc=%08x, desc_NS=%u, descriptor type=%u, table1_base_addr=%08x\n",table0_desc_addr, table0_desc, table0_desc_NS, table0_desc_type, table1_base);

    address_t table1_desc_addr = (table1_base << 10) | ( va_table1_index << 2 ) ;    
    volatile address_t *table1_base_ptr = (address_t*)getvaddr(table1_desc_addr);    
    address_t table1_desc = *table1_base_ptr;
    //*table1_base_ptr = (table1_desc | (1<<10));
    //table1_desc = *table1_base_ptr;
    address_t table1_desc_type = table1_desc & 0x3; 
    address_t ap10 = (table1_desc >> 4 ) & 0x3;
    address_t ap2 = (table1_desc & (1<<9) ) > 0 ? 1 : 0;
    address_t B = (table1_desc & (1<<2) ) > 0 ? 1 : 0;
    address_t C = (table1_desc & (1<<3) ) > 0 ? 1 : 0;
    address_t tex = (table1_desc >> 6 ) & 0x7;
    address_t S = (table1_desc & (1<<10) ) > 0 ? 1 : 0; 
    if (verbose)
        printf("table1_desc_addr = %08x, table1_desc=%08x, descriptor type=%u, ap2=%u, ap10=%u, B=%u, C=%u, tex=%u, S=%u\n",table1_desc_addr, table1_desc, table1_desc_type, ap2, ap10, B, C, tex, S);

    if (verbose) {
        printf("virtual address of p: %08p\n",p);
        printf("physical address of p (linux): %08p\n",lookup_physical_address(p_va));
    }

    address_t page_address = table1_desc >> 12;
    address_t pa = (page_address << 12) | va_page_index;
    if (verbose)
        printf("physical address of p (manually walked): %08x\n",pa);      

    return pa;
}


/*
* Display all physical pages used by the current process
*/
void display_memory_layout() {

    int pid = getpid();
    printf("My process ID : %d\nOS page size: %d\n", pid,getpagesize());

    // Open pid/maps file for reading
    // the maps file contains the page ranges of different regions of the application's virtual address space
    char m_name[FILENAMELEN];
    sprintf(m_name, "%s/%s/%s", PROC_DIR_NAME, "self", MAPS_NAME);
    FILE *m = fopen(m_name, "r");
    if (m == NULL) {
        ERR("Unable to open \"%s\" for reading (errno=%d) (5).\n", m_name, errno);
        return;
    }

    // Open pid/pagemap file for reading.
    // the pagemap file contains a binary array of 64-bit words, one for each page in process virtual address space, containing the physical address of the mapped page
    char pm_name[FILENAMELEN];
    sprintf(pm_name, "%s/%d/%s", PROC_DIR_NAME, pid, PAGEMAP_NAME);
    int pm = open(pm_name, O_RDONLY);
    if (pm == -1) {
        ERR("Unable to open \"%s\" for reading (errno=%d). (7)\n", pm_name, errno);
        fclose(m);
        return;
    }


    // For each line in the maps file...    
    char line[LINELEN];
    while (fgets(line, LINELEN, m) != NULL)
    {
        unsigned long vm_start;
        unsigned long vm_end;
        int num_pages;

        /* ...output the line...
         */
        //printf( "= %s", line);

        /* ...then evaluate the range of virtual
         *  addresses it asserts.
         */
        int n = sscanf(line, "%lX-%lX", &vm_start, &vm_end);
        if (n != 2)
        {
            ERR("Invalid line read from \"%s\": %s (6)\n", m_name, line);
            continue;
        }

        /* If the virtual address range is greater than 0...
         */
        unsigned long long pa_first, pa_last;
        num_pages = (vm_end - vm_start) / PAGE_SIZE;
        if (num_pages > 0)
        {
            // index of first page in this virtual address range (byte address)
            long index = (vm_start / PAGE_SIZE) * sizeof(unsigned long long);                         

            // set file descriptor pm to appropriate index of pagemap file.
            off64_t o = lseek64(pm, index, SEEK_SET);
            if (o != index)
            {
                ERR("Error seeking to %ld in file \"%s\" (errno=%d). (8)\n", index, pm_name, errno);
                continue;
            }            

            // For each page in the virtual address range...
            int i;
            for (i=0; i<num_pages; i++)
            {
                // physical page address
                unsigned long long pa;

                // Read a 64-bit word from each of the pagemap file
                ssize_t t = read(pm, &pa, sizeof(unsigned long long));
                if (t < 0)
                {
                    ERR("Error reading file \"%s\" (errno=%d). (11)\n", pm_name, errno);
                    goto continue_with_next_region;
                }

                if (i == 0) {
                    pa_first = pa;
                }
                if (i == num_pages-1)
                    pa_last = pa;
                //if (num_pages <50)
                //    printf("%016llX\n", pa);
                
            }
        }
        printf("%d: %08x - %08x -> %016llx - %016llx\n", num_pages, vm_start, vm_end, (pa_first & 0x7FFFFFFFFFFFFF)*PAGE_SIZE,(pa_last & 0x7FFFFFFFFFFFFF)*PAGE_SIZE);
        continue_with_next_region: ;
    }


    if (pm != -1) {
        close(pm);
    }
    if (m != NULL) {
        fclose(m);
    }
}



/*
* Initialize the SVM system on the host side
*/
bool init_svm() {
    bus_p_w = (uint32_t*)getvaddr(LOCK_SERVER_CSR+0x00);
    bus_p_r = (uint32_t*)getvaddr(LOCK_SERVER_CSR+0x10);

    if ((bus_p_w == NULL) || (bus_p_r == NULL)) {
        return false;
    }

    uint dummy;
    asm volatile (
            "mov r0, #0x00000000" "\n\t"
            "str r0, [%1]" "\n\t"
            : "=&r" (dummy)
            : "r" (bus_p_w)
            : "cc", "r0"
    );
    return true;
}


/*
* Clean up the SVM system on the host side
*/
void cleanup_svm() {
}


uint get_lock() {
    return *bus_p_r;
}

inline uint acquire_lock() {
    uint wait_cycles = 0;
    asm volatile (
            "mov r1, #0x00000001" "\n\t"
            "str r1, [%1]" "\n\t"
            "1:" "\n\t"
            "ldr r0, [%2,#0]" "\n\t"
            "add %0, %0, #01" "\n\t"
            "subs r0, r0, #0x00000002" "\n\t"
            "bne 1b" "\n\t"
            : "=&r" (wait_cycles)
            : "r" (bus_p_w), "r" (bus_p_r)
            : "cc", "r0", "r1"
    );
    return wait_cycles;
}

inline void release_lock() {
    uint dummy;
    asm volatile (
            "ldr r0, [%2,#0]" "\n\t"
            "subs r0, r0, #0x00000002" "\n\t"
            "bne 1f" "\n\t"
            "mov r0, #0x00000000" "\n\t"
            "str r0, [%1]" "\n\t"
            "1:" "\n\t"
            : "=&r" (dummy)
            : "r" (bus_p_w), "r" (bus_p_r)
            : "cc", "r0"
    );
}

template<class T>
void svm_atomic_store(T* addr, T data) {
    if (acquire_lock()) {
        *addr = data;
        release_lock();
    }
}

#endif


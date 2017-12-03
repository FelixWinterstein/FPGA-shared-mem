/**********************************************************************
* Felix Winterstein, Imperial College London, 2016
*
* File: svm_driver.c
*
* Revision 1.01
* Additional Comments: distributed under a Apache-2.0 license, see LICENSE
*
**********************************************************************/

#include <linux/module.h>    // included for all kernel modules
#include <linux/kernel.h>    // included for KERN_INFO
#include <linux/init.h>      // included for __init and __exit macros

#include <linux/device.h>
#include <linux/platform_device.h>
#include <linux/uaccess.h>
#include <linux/ioport.h>
#include <linux/io.h>

MODULE_AUTHOR  ("Felix Winterstein");
MODULE_LICENSE ("Dual BSD/GPL");
MODULE_DESCRIPTION ("Driver for Altera OpenCL SoC SVM");
MODULE_SUPPORTED_DEVICE ("Altera OpenCL SoC Devices");

typedef uint32_t address_t;

// declare and register a device_driver struct to get a driver entry in Sysfs
static struct device_driver svm_driver_s = {
	.name = "svm_driver",
	.bus = &platform_bus_type,
};
static uint foo;

// this function executes when a user program reads from /sys/bus/platform/drivers/svm_driver/svm_driver
ssize_t svm_driver_show(struct device_driver *drv, char *buf)
{    
    address_t res;
    uint i;
    uint j=0;

    // read TTBCR:
    // - bit 31: long/short-descriptor table format
    // - bits 2-0: N (if short-descriptor table format)
    res = 0;
    asm volatile (
        "mrc p15, 0, r0, c2, c0, 2" "\n\t"
        "mov %0, r0"    "\n\t"
        : "=r" (res)
    );    
    for (i=0; i<sizeof(address_t); i++) {
        buf[j] = res & 0xFF;
        res = res >> 8;
        j++;
    }

    // read TTBR0:
    // - bits 31-(14-N): translation table base 0 address
    res = 0;
    asm volatile (
        "mrc p15, 0, r0, c2, c0, 0" "\n\t"
        "mov %0, r0"    "\n\t"
        : "=r" (res)
    );    
    for (i=0; i<sizeof(address_t); i++) {
        buf[j] = res & 0xFF;
        res = res >> 8;
        j++;
    }

    // readout foo
    res = foo;
    for (i=0; i<sizeof(address_t); i++) {
        buf[j] = res & 0xFF;
        res = res >> 8;
        j++;
    }

	return j;//sprintf(buf, "%d", res);
}


// this function executes when a user program writes to /sys/bus/platform/drivers/svm_driver/svm_driver
ssize_t svm_driver_store(struct device_driver *drv, const char *buf, size_t count)
{
    if (buf[0] == 0x1) {

        address_t result;

        // enable smp
        asm volatile (
            "dsb" "\n\t"
            "isb" "\n\t"
            "mrc	p15, 0, r0, c1, c0, 1" "\n\t"
            "ldr	r1, =0x40" "\n\t"
            "orr	r0, r0, r1" "\n\t"
            "mcr	p15, 0, r0, c1, c0, 1" "\n\t"
            "dsb" "\n\t"
            "isb" "\n\t"
            "dsb" "\n\t"
            "isb" "\n\t"
            "mrc	p15, 0, r0, c1, c1, 2" "\n\t"
            "mov    %0, r0" "\n\t"
            "ldr	r1, =0x40000" "\n\t"
            "orr	r0, r0, r1" "\n\t"
            "mcr	p15, 0, r0, c1, c1, 2" "\n\t"
            "dsb" "\n\t"
            "isb" "\n\t"
            // flush TLB
            //"ldr	r1, =0x0" "\n\t"
            //"mrc	p15, 0, r1, c8, c7, 0" "\n\t"
            : "=r" (result)
        );  

        foo = result;

    } else if (buf[0] == 0x2 ) {

        address_t result;
        address_t value = 0;
        int i;
        for (i=sizeof(address_t)-1; i>=0; i--) {
            value = value << 8;
            address_t c = (address_t)buf[i+1] & 0xFF;
            value |= c;            
        }
        
        // FIXME: crashes the board, currently unused by API
        asm volatile (
            "ldr	r0, =0x0" "\n\t"
            "mcr	p15, 2, r0,  c0,  c0, 0" "\n\t"
            "mcr    p15, 0, %1,  c7, c14, 1" "\n\t"
            "dsb" "\n\t"
            : "=r" (result) : "r" (value)
        );  
        
        foo = result;

    } else if (buf[0] == 0x3) {

        address_t result=0x12;
        address_t value = 0;
        int i;
        for (i=sizeof(address_t)-1; i>=0; i--) {
            value = value << 8;
            address_t c = (address_t)buf[i+1] & 0xFF;
            value |= c;            
        }
        
        asm volatile (
            "ldr	r1, =0x0" "\n\t"
            "mcr p15, 0, r1, c8, c7, 0" "\n\t" // Invalidate entire unified TLB
            "dsb" "\n\t" 
            "isb" "\n\t" 
            "mcr p15, 0, r1, c8, c6, 0" "\n\t" // Invalidate entire data TLB
            "dsb" "\n\t" 
            "isb" "\n\t" 
            "mcr p15, 0, r1, c8, c5, 0" "\n\t" // Invalidate entire instruction TLB
            "dsb" "\n\t" 
            "isb" "\n\t" 
        );  

        foo = result;
    }

	return count;
}

// declare a driver_attribute struct with function pointers to the "show" and "store" functions (run when userspace reads from or writes to the sysfs file, respectively)
static DRIVER_ATTR(svm_driver, S_IWUSR | S_IRUGO, svm_driver_show, svm_driver_store);

// init function, called when driver is loaded
static int __init svm_driver_init(void)
{
	int retval;

    // register driver
	retval = driver_register(&svm_driver_s);
    if (retval < 0)
		return retval;

    // create the file /sys/bus/platform/drivers/svm_driver/svm_driver
	retval = driver_create_file(&svm_driver_s, &driver_attr_svm_driver);
	if (retval < 0) {
        driver_unregister(&svm_driver_s);
		return retval;
	}
    
    return 0;    // Non-zero return means that the module couldn't be loaded.
}

// exit function, called when module is unloaded
static void __exit svm_driver_cleanup(void)
{
    driver_remove_file(&svm_driver_s, &driver_attr_svm_driver);
	driver_unregister(&svm_driver_s);
    printk(KERN_INFO "Cleaning up module.\n");
}

module_init(svm_driver_init);
module_exit(svm_driver_cleanup);

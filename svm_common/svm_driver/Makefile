# This is a special makefile format for compiling kernel drivers.
# You may have to update KDIR to point to your configured Linux kernel for
# the ARM processor on the device.

# Configured Linux kernel source.
KDIR ?= path-to-linux-socfpga-sources


# CROSS_COMPILE := arm-linux-gnueabihf-
ARCH := arm

# Final module
obj-m := svm_driver.o

# List of object files to compile for the final module.
# svm_driver-y := svm_driver.o

all :
	CFLAGS=-DCONFIG_ALTERA_STAPL $(MAKE) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) -C $(KDIR) M=`pwd` modules

clean : clean-intermediates clean-module

clean-module :
	rm -f *.ko

clean-intermediates:
	rm -f $(obj-m)
	rm -f *.o
	rm -f *.mod.*
	rm -f *.symvers
	rm -f *.order
	rm -f .acl*cmd
	rm -rf .tmp_versions

.PHONY: all clean clean-intermediates clean-module

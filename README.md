FPGA-shared-mem
=============

Heterogeneous CPU-FPGA systems are gaining momentum in the embedded systems sector and in the data center market. While the programming abstractions for implementing the data transfer between CPU and FPGA (and _vice versa_) that are available in today's commercial programming tools are well-suited for certain types of applications, the CPU-FPGA communication for applications that share complex pointer-based data structures between the CPU and FPGA remains difficult to implement.

This repository provides the infrastructure and building blocks to enable the programming abstraction of a virtual address space that is shared between the host CPU and one (or potentially several) FPGA devices. One example of _shared virtual memory_ (SVM) is defined by the recent OpenCL 2.0 standard. SVM allows the software and hardware portion of a hybrid application to seamlessly (and concurrently) share complex data structures by simply passing a pointer, which can be dereferenced from both the CPU and the FPGA side and which greatly eases programming heterogeneous systems.

In order to provide researches a tool for experimenting with OpenCL SVM in the context of FPGAs, this repository contains a framework that automatically adds the physical infrastructure for SVM into a commercial OpenCL tool for FPGAs (targeting the Intel SDK for OpenCL and an Intel Cyclone V CPU-FPGA heterogeneous system). Please refer to the companion paper \[1\] for more information.

Among the three modes of OpenCL 2.0 SVM, _Coarse-grain buffer SVM_, _Fine-grained buffer SVM_ and _Fine-grained system SVM_, this repository provides code for supporting the third mode, which has the highest degree of hardware abstraction, where the entire CPU host address space is shared directly with the FPGA.

The companion paper to this repository explores the design space for these building blocks and studies the performance impact. It shows that, due to the ability of SVM-enabled implementations to avoid artificially sizing dynamic data structures and fetching data on-the-fly, up to 2x speed-up over an OpenCL design without SVM support can be achieved.


### Prerequisites:

1) The code in this repository has been developed for the Intel Cyclone V SoC Development Kit \[2\], other (including non-SoC such Intel's Xeon+FPGA multi-chip package) platforms are possible, but have not been tested and will likely require minor code modifications.

2) The code is compatible to and has been tested with the Intel FPGA SDK for OpenCL version 16.0 (pro not required).

3) The Cyclone V SoC Development Kit runs Linux (the OpenCL SDK for Cyclone V SoC comes with a Linux SD card image). 


### Setup instructions:

1) __Set up Cyclone V Development Kit__: Set up the OpenCL run-time environment on the Cyclone V SoC as described in \[3\]. After completion, the SoC runs Linux. The Intel FPGA SDK for OpenCL and the SoC Embedded Design Suite (required for cross-compiling the OpenCL host code for the SoC) have been installed on your workstation.

2) __Download linux-socfpga sources__: The SVM driver provided in this repository must be compiled against the Linux kernel on the board. Download the Linux kernel from [https://github.com/altera-opensource/linux-socfpga](https://github.com/altera-opensource/linux-socfpga) and save it on your workstation.

3) __Compile the SVM driver__: Set the cross compiler for the SoC platform: `export CROSS_COMPILE=<path-to-SoC-Embedded-Design-Suite-installation>/embedded/ds-5/sw/gcc/bin/arm-linux-gnueabihf-`. Open `svm_common/svm_driver/Makefile` and set `KDIR` to the path of the linux-socfpga sources. 

4) __Build the custom RTL library for SVM__: The SVM functionality at the hardware end is implemented in a custom RTL library, which is integrated into the OpenCL compilation flow. Ensure that `$ALTERAOCLSDKROOT` points to you Intel FPGA OpenCL installation and `source ./init_opencl_env.sh` to point to the correct board support package. Build the custom RTL library by running the scripts `svm_common/rtl_src/generate_aocl_interface.sh` and `svm_common/rtl_src/package_ip.sh` (in this order).


### Setup instructions:

1) 

### Questions:
Write to me: [http://cas.ee.ic.ac.uk/people/fw1811](http://cas.ee.ic.ac.uk/people/fw1811)


### References:

1) Felix Winterstein and George Constantinides: "Pass a Pointer: Exploring Shared Virtual Memory Abstractions in OpenCL Tools for FPGAs," [http://cas.ee.ic.ac.uk/people/fw1811/papers/Felix_ICFPT17.pdf](http://cas.ee.ic.ac.uk/people/fw1811/papers/Felix_ICFPT17.pdf)

2) Intel Corp, Cyclone® V SoC Development Kit, [https://www.altera.com/products/boards_and_kits/dev-kits/altera/kit-cyclone-v-soc.html](https://www.altera.com/products/boards_and_kits/dev-kits/altera/kit-cyclone-v-soc.html)

3) Intel Corp, Altera SDK for OpenCL - Cyclone V SoC Getting Started Guide, UG-OCL006, 2016.05.02, [https://www.altera.com/en_US/pdfs/literature/hb/opencl-sdk/aocl_c5soc_getting_started.pdf](https://www.altera.com/en_US/pdfs/literature/hb/opencl-sdk/aocl_c5soc_getting_started.pdf)

FPGA-shared-mem
=============

Heterogeneous CPU-FPGA systems are gaining momentum in the embedded systems sector and in the data center market. While the programming abstractions for implementing the data transfer between CPU and FPGA (and _vice versa_) that are available in today's commercial programming tools are well-suited for certain types of applications, the CPU-FPGA communication for applications that share complex pointer-based data structures between the CPU and FPGA remains difficult to implement.

This repository provides the infrastructure and building blocks to enable the programming abstraction of a virtual address space that is shared between the host CPU and one (or potentially several) FPGA devices. One example of _shared virtual memory_ (SVM) is defined by the recent OpenCL 2.0 standard. SVM allows the software and hardware portion of a hybrid application to seamlessly (and concurrently) share complex data structures by simply passing a pointer, which can be dereferenced from both the CPU and the FPGA side and which greatly eases programming heterogeneous systems.

In order to provide researches a tool for experimenting with OpenCL SVM in the context of FPGAs, this repository contains a framework that automatically adds the physical infrastructure for SVM into a commercial OpenCL tool for FPGAs (targeting the Intel SDK for OpenCL and an Intel Cyclone V CPU-FPGA heterogeneous system). Please refer to the companion paper \[1\] for more information.

Among the three modes of OpenCL 2.0 SVM, _Coarse-grain buffer SVM_, _Fine-grained buffer SVM_ and _Fine-grained system SVM_, this repository provides code for supporting the third mode, which has the highest degree of hardware abstraction, where the entire CPU host address space is shared directly with the FPGA.

The companion paper to this repository explores the design space for these building blocks and studies the performance impact. It shows that, due to the ability of SVM-enabled implementations to avoid artificially sizing dynamic data structures and fetching data on-the-fly, up to 2x speed-up over an OpenCL design without SVM support can be achieved.


### Prerequisites:

1) The code in this repository has been developed for the Intel Cyclone V SoC Development Kit \[2\], other (including non-SoC such Intel's Xeon+FPGA multi-chip package) platforms are possible, but have not been tested and will likely require minor code modifications.

2) The code is compatible to and has been tested with the Intel FPGA SDK for OpenCL version 16.0.0.211 (pro not required).

3) The Cyclone V SoC Development Kit runs Linux (the OpenCL SDK for Cyclone V SoC comes with a Linux SD card image). 


### Setup instructions:

1) __Set up Cyclone V Development Kit__: Set up the OpenCL run-time environment on the Cyclone V SoC as described in \[3\]. After completion, the SoC runs Linux. The Intel FPGA SDK for OpenCL and the SoC Embedded Design Suite (required for cross-compiling the OpenCL host code for the SoC) have been installed on your workstation.

2) __Download linux-socfpga sources__: The SVM driver provided in this repository must be compiled against the Linux kernel on the board. Download the Linux kernel from [https://github.com/altera-opensource/linux-socfpga](https://github.com/altera-opensource/linux-socfpga) and save it on your workstation.

3) __Compile the SVM driver__: Set the cross compiler for the SoC platform: `export CROSS_COMPILE=<path-to-SoC-Embedded-Design-Suite-installation>/ds-5/sw/gcc/bin/arm-linux-gnueabihf-`. Open `svm_common/svm_driver/Makefile` and set `KDIR` to the path of the linux-socfpga sources. 

4) __Build the custom RTL library for SVM__: The SVM functionality at the hardware end is implemented in a custom RTL library, which is integrated into the OpenCL compilation flow. Ensure that `$ALTERAOCLSDKROOT` points to your Intel FPGA OpenCL installation and `source ./init_opencl_env.sh` to point to the correct board support package. Build the custom RTL library by running the scripts `svm_common/rtl_src/generate_aocl_interface.sh` and `svm_common/rtl_src/package_ip.sh` (in this order).


### Using the framework:

Once the setup is complete, the code examples (`./examples`) provide information on how to use the framework. We provide three examples: 

* _filtering\_algorithm_ (an optimized SVM-enabled implementation of the filtering algorithm for K-means clustering \[4\])
* _filtering\_algorithm\_no\_svm_ (an implementation of the filtering algorithm without SVM)
* _atomicity\_test_ (a micro-benchmark to test the host-device lock service).

The two implementations of the filtering algorithm can be used to reproduce the results presented in the companion paper \[1\].

Build and run _filtering\_algorithm_:

1) __Build the hardware__: Change into `./examples/filtering_algorithm`. Ensure you have completed all setup steps from the previous section. Build the FPGA design by running the scripts `./generate_system_files.sh` and `./generate_hardware.sh` (in this order). The first script generates the RTL and QSYS design files, calls the SVM scripts in `../../svm_common/scripts` and the custom RTL library in `../../svm_common/rtl_src` and then stops the build flow. The second script continues the build flow with the manipulated RTL and QSYS sources.

2) __Build the host software__: Include the ARM cross compiler in the $PATH environment: `export PATH=<path-to-SoC-Embedded-Design-Suite-installation>/ds-5/sw/gcc/bin:$PATH`. Run `make`.

3) __Run the example__: Copy the files `bin/filter_stream_opt1.aocx` and `bin/host` to the Cyclone V SoC (e.g. via SSH). Set the OpenCL run-time environment on the SoC and run `./host`.


### Questions:
Write to me: [http://cas.ee.ic.ac.uk/people/fw1811](http://cas.ee.ic.ac.uk/people/fw1811)


### References:

1) Felix Winterstein and George Constantinides: "_Pass a Pointer: Exploring Shared Virtual Memory Abstractions in OpenCL Tools for FPGAs_," in Proc. ICFPT 2017 [http://cas.ee.ic.ac.uk/people/fw1811/papers/Felix_ICFPT17.pdf](http://cas.ee.ic.ac.uk/people/fw1811/papers/Felix_ICFPT17.pdf)

2) Intel Corp, Cyclone® V SoC Development Kit, [https://www.altera.com/products/boards_and_kits/dev-kits/altera/kit-cyclone-v-soc.html](https://www.altera.com/products/boards_and_kits/dev-kits/altera/kit-cyclone-v-soc.html)

3) Intel Corp, Altera SDK for OpenCL - Cyclone V SoC Getting Started Guide, UG-OCL006, 2016.05.02, [https://www.altera.com/en_US/pdfs/literature/hb/opencl-sdk/aocl_c5soc_getting_started.pdf](https://www.altera.com/en_US/pdfs/literature/hb/opencl-sdk/aocl_c5soc_getting_started.pdf)

4) F. Winterstein, S. Bayliss, and G. Constantinides, "_High-level synthesis of dynamic data structures: a case study using Vivado HLS_," in Proc. ICFPT 2013 [http://cas.ee.ic.ac.uk/people/fw1811/papers/FelixFPT13.pdf](http://cas.ee.ic.ac.uk/people/fw1811/papers/FelixFPT13.pdf) 


The source code is distributed under an Apache-2.0 license (see LICENSE). If you use it, please cite

Felix Winterstein and George Constantinides: "_Pass a Pointer: Exploring Shared Virtual Memory Abstractions in OpenCL Tools for FPGAs_," Proceedings of the International Conference on Field Programmable Technology (ICFPT), 2017.

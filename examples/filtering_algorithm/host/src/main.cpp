/**********************************************************************
* Felix Winterstein, Imperial College London, 2016
*
* File: main.cpp
*
* Revision 1.01
* Additional Comments: distributed under an Apache-2.0 license, see LICENSE
*
**********************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include "CL/opencl.h"
#include "AOCLUtils/aocl_utils.h"

#include <mutex>          // std::mutex, std::lock
#include <atomic>
#include <pthread.h>


#include "../../../../svm_common/svm_utils/svm_utils.hpp"

#include "my_util.hpp"
#include "build_kdTree.h"

#define N 1024*1024 // number of data points
#define K 128       // number of centres
#define S 0.08      // standard deviation (determines the clusteredness of the data set)

using namespace aocl_utils;

// OpenCL runtime configuration
cl_platform_id platform = NULL;
cl_device_id device; 
cl_context context = NULL;
cl_program program = NULL;
cl_command_queue queue0;
cl_command_queue queue1;
cl_kernel kernel0 = NULL; 
cl_kernel kernel1 = NULL; 

cl_mem initial_centers_buf;

cl_mem z0_buf; 

cl_mem visited_nodes_buf; 
cl_mem new_centers_buf; 
cl_mem distortion_buf; 

cl_mem profiling_data_buf; 


// Function prototypes
bool init_opencl();
void run();
void cleanup();

cl_int4 *initial_centers;
cl_uint *visited_nodes;
cl_int4 *new_centers;
cl_uint *distortion;

cl_uint16 *profiling_data;

address_t ttbr0_value;

data_type *data_points  = NULL;
uint *index_arr         = NULL;
uint *cntr_idx          = NULL;
kdTree_t* root          = NULL;



// Entry point.
int main(int argc, char **argv) {
    Options options(argc, argv);  


    const uint n = N;
    const uint k = K;
    const double std_dev = S;

    // input data points
    data_points = new data_type[N];

    // array of indices used by build_kdTree
    index_arr = new uint[N];

    // indices of initial centers
    cntr_idx = new uint[K]; 
    
    if (!read_data_points(n, k, std_dev, data_points,index_arr)) {
        printf("Reading data points failed\n");
        return -1;  
    }
    
    if (!read_initial_centres(n, k, std_dev, cntr_idx)) {
        printf("Reading initial centers failed\n");
        return -1;
    }

    // Initialize OpenCL.
    if(!init_opencl()) {
        printf("OpenCL initialization failed\n");
        return -1;
    }

    // Enable Cyclone V ACP
    enable_f2h_acp(true);

    // Read value of ARM TTBR0 system register to get the entry point of the Linux page table
    ttbr0_value = get_ttbr0();
    init_svm();

    // Run the kernel.
    run();

    // Free the resources allocated
    cleanup();

    return 0;
}

/////// HELPER FUNCTIONS ///////



// Initializes the OpenCL objects.
bool init_opencl() {
    cl_int status;

    printf("Initializing OpenCL\n");

    if(!setCwdToExeDir()) {
        return false;
    }

    // Get the OpenCL platform.
    platform = findPlatform("Altera");
    if(platform == NULL) {
        printf("ERROR: Unable to find Altera OpenCL platform.\n");
        return false;
    }

    unsigned num_devices = 0;
    scoped_array<cl_device_id> devices;

    devices.reset(getDevices(platform, CL_DEVICE_TYPE_ALL, &num_devices));

    // We'll just use the first device.
    printf("Platform: %s, %d device(s) available\n", getPlatformName(platform).c_str(),num_devices);
    printf("Using device 0: %s\n", getDeviceName(devices[0]).c_str());
    device = devices[0];


    // Create the context.
    context = clCreateContext(NULL, 1, &device, &oclContextCallback, NULL, &status);
    checkError(status, "Failed to create context");

    // Create the program for all device. Use the first device as the
    // representative device (assuming all device are of the same type).
    std::string binary_file = getBoardBinaryFile("filter_stream_opt1", device);
    printf("Using AOCX: %s\n", binary_file.c_str());
    program = createProgramFromBinary(context, binary_file.c_str(), &device, 1);

    // Build the program that was just created.
    status = clBuildProgram(program, 0, NULL, "", NULL, NULL);
    checkError(status, "Failed to build program");


    // Command queues
    queue0 = clCreateCommandQueue(context, device, CL_QUEUE_PROFILING_ENABLE, &status);
    checkError(status, "Failed to create command queue");

    queue1 = clCreateCommandQueue(context, device, CL_QUEUE_PROFILING_ENABLE, &status);
    checkError(status, "Failed to create command queue");

    // Kernels
    const char *kernel0_name = "filter0";
    kernel0 = clCreateKernel(program, kernel0_name, &status);
    checkError(status, "Failed to create kernel");    

    const char *kernel1_name = "filter1";
    kernel1 = clCreateKernel(program, kernel1_name, &status);
    checkError(status, "Failed to create kernel");   

    //display_device_info(device);

    return true;
}


void run() {

    const uint k = K;

    cl_int status;

    printf("Launching device\n");

    const double start_datasetup_time = getCurrentTimestamp();

    data_type bnd_lo, bnd_hi;   
    //compute axis-aligned hyper rectangle enclosing all data points
    compute_bounding_box(data_points, index_arr, N, &bnd_lo, &bnd_hi);
    
    // build up data structure
    root = buildkdTree(data_points,index_arr,N, &bnd_lo, &bnd_hi);

    cl_event kernel0_event;
    cl_event kernel1_event;
    cl_event finish_event;    

    // sample initial centers from data points 
    posix_memalign ((void**)(&initial_centers), 64, K*sizeof(cl_int4));
    for (uint i=0; i<k; i++) {
        initial_centers[i] = data_type_2_vector(data_points[cntr_idx[i]]);
    }    

    posix_memalign ((void**)(&visited_nodes), 64, 1*sizeof(cl_uint));
    posix_memalign ((void**)(&profiling_data), 64, 1*sizeof(cl_uint16));

    posix_memalign ((void**)(&new_centers), 64, K*sizeof(cl_int4));
    posix_memalign ((void**)(&distortion), 64, K*sizeof(cl_uint));

    

    // Input buffers.
    initial_centers_buf= clCreateBuffer(context, CL_MEM_READ_ONLY /*| CL_MEM_USE_HOST_PTR*/, K*sizeof(cl_int4), NULL, &status);
    checkError(status, "Failed to create buffer for input");

    // Output buffers (dummy).
    z0_buf = clCreateBuffer(context, CL_MEM_WRITE_ONLY /*| CL_MEM_USE_HOST_PTR*/, 1 * sizeof(int), NULL, &status);
    checkError(status, "Failed to create buffer for output");

    // Output buffers (real).
    visited_nodes_buf = clCreateBuffer(context, CL_MEM_WRITE_ONLY /*| CL_MEM_USE_HOST_PTR*/, 1 * sizeof(cl_uint), NULL, &status);
    checkError(status, "Failed to create buffer for output");

    profiling_data_buf = clCreateBuffer(context, CL_MEM_WRITE_ONLY /*| CL_MEM_USE_HOST_PTR*/, 1 * sizeof(cl_uint16), NULL, &status);
    checkError(status, "Failed to create buffer for output");

    new_centers_buf = clCreateBuffer(context, CL_MEM_WRITE_ONLY /*| CL_MEM_USE_HOST_PTR*/, K * sizeof(cl_int4), NULL, &status);
    checkError(status, "Failed to create buffer for output");

    distortion_buf = clCreateBuffer(context, CL_MEM_WRITE_ONLY /*| CL_MEM_USE_HOST_PTR*/, K * sizeof(cl_uint), NULL, &status);
    checkError(status, "Failed to create buffer for output");   


    const double start_buffer_time = getCurrentTimestamp();    

    cl_event write_event[1];

    status = clEnqueueWriteBuffer(queue0, initial_centers_buf, CL_FALSE, 0, K*sizeof(cl_int4), initial_centers, 0, NULL, &write_event[0]);
    checkError(status, "Failed to transfer input A");

    // Set kernel arguments.
    unsigned argi;


    // kernel 0
    argi = 0;
 
    status = clSetKernelArg(kernel0, argi++, sizeof(cl_mem), &z0_buf);
    checkError(status, "Failed to set argument %d", argi - 1);

    status = clSetKernelArg(kernel0, argi++, sizeof(cl_uint), (void*)&root);
    checkError(status, "Failed to set argument %d", argi - 1);

    status = clSetKernelArg(kernel0, argi++, sizeof(cl_uint), (void*)&ttbr0_value);
    checkError(status, "Failed to set argument %d", argi - 1);

    status = clSetKernelArg(kernel0, argi++, sizeof(cl_uint), (void*)&k);
    checkError(status, "Failed to set argument %d", argi - 1);

    status = clSetKernelArg(kernel0, argi++, sizeof(cl_mem), &initial_centers_buf);
    checkError(status, "Failed to set argument %d", argi - 1);

    status = clSetKernelArg(kernel0, argi++, sizeof(cl_mem), &visited_nodes_buf);
    checkError(status, "Failed to set argument %d", argi - 1);
    
    status = clSetKernelArg(kernel0, argi++, sizeof(cl_mem), &profiling_data_buf);
    checkError(status, "Failed to set argument %d", argi - 1);
    


    // kernel 1
    argi = 0;

    status = clSetKernelArg(kernel1, argi++, sizeof(cl_uint), (void*)&k);
    checkError(status, "Failed to set argument %d", argi - 1);

    status = clSetKernelArg(kernel1, argi++, sizeof(cl_mem), &new_centers_buf);
    checkError(status, "Failed to set argument %d", argi - 1);

    status = clSetKernelArg(kernel1, argi++, sizeof(cl_mem), &distortion_buf);
    checkError(status, "Failed to set argument %d", argi - 1);

    const double start_kernel_time = getCurrentTimestamp();

    // Enqueue kernels

    status = clEnqueueTask(queue1, kernel1, 0, NULL, &kernel1_event);
    checkError(status, "Failed to launch kernel 1");   

    status = clEnqueueTask(queue0, kernel0, 1, write_event, &kernel0_event);
    checkError(status, "Failed to launch kernel");     
    

    const double start_readout_time = getCurrentTimestamp();
  
    status = clEnqueueReadBuffer(queue0, visited_nodes_buf, CL_FALSE, 0, 1*sizeof(cl_uint), visited_nodes, 1, &kernel0_event, &finish_event);
    checkError(status, "Failed to transfer output"); 

    status = clEnqueueReadBuffer(queue0, profiling_data_buf, CL_FALSE, 0, 1*sizeof(cl_uint16), profiling_data, 1, &kernel0_event, &finish_event);
    checkError(status, "Failed to transfer output"); 

    status = clEnqueueReadBuffer(queue1, new_centers_buf, CL_FALSE, 0, K*sizeof(cl_int4), new_centers, 1, &kernel1_event, &finish_event);
    checkError(status, "Failed to transfer output"); 

    status = clEnqueueReadBuffer(queue1, distortion_buf, CL_FALSE, 0, K*sizeof(cl_uint), distortion, 1, &kernel1_event, &finish_event);
    checkError(status, "Failed to transfer output");  


    // Wait for all devices to finish.
    clWaitForEvents(1, &finish_event);
    clWaitForEvents(1, &kernel0_event);
    clWaitForEvents(1, &kernel1_event);

   
    const double end_time = getCurrentTimestamp();

    printf("visited nodes: %d\n",visited_nodes[0]);
   
    printf("new centers:\n");
    for (uint i=0; i<k; i++) {
        data_type c = vector_2_data_type(new_centers[i]);        
        printf("%3u: ", i); 
        for (uint d=0; d<D; d++) {
            printf("%8d ", c.value[d]);
        }
        printf(" (distortion: %12u)\n",distortion[i]);
    }

    // Wall-clock time taken.
    printf("\nData setup to end: %0.3f ms\n", (end_time - start_datasetup_time) * 1e3);
    printf("Buffer setup to end: %0.3f ms\n", (end_time - start_buffer_time) * 1e3);
    printf("Kernel enqueue to end: %0.3f ms\n", (end_time - start_kernel_time) * 1e3);
    printf("Buffer readout to end: %0.3f ms\n", (end_time - start_readout_time) * 1e3);

  
    // Print profiling information
    printf("rw: transferred data = %.2f MB\n",(double)profiling_data[0].s0 / (1024.0 * 1024.0));
    printf("rw: number of transferred 32bit words = %u\n",profiling_data[0].s1);
    printf("rw: average burst size = %.2f\n",(double)profiling_data[0].s2 / (double) profiling_data[0].s3);
    printf("rw: cache hit rate = %.2f\n",(double)profiling_data[0].s4 * 100.0 / profiling_data[0].s1);

    printf("read_pt_level1: transferred data = %.2f MB\n",(double)profiling_data[0].s5 / (1024.0 * 1024.0));
    printf("read_pt_level1: number of transferred 32bit words = %u\n",profiling_data[0].s6);
    printf("read_pt_level1: average burst size = %.2f\n",(double)profiling_data[0].s7 / (double) profiling_data[0].s8);
    printf("read_pt_level1: cache hit rate = %.5f\n",(double)profiling_data[0].s9 * 100.0 / profiling_data[0].s6);

    printf("read_pt_level0: transferred data = %.2f MB\n",(double)profiling_data[0].sa / (1024.0 * 1024.0));
    printf("read_pt_level0: number of transferred 32bit words = %u\n",profiling_data[0].sb);
    printf("read_pt_level0: average burst size = %.2f\n",(double)profiling_data[0].sc / (double) profiling_data[0].sd);
    printf("read_pt_level0: cache hit rate = %.5f\n",(double)profiling_data[0].se * 100.0 / profiling_data[0].sb);

    // Get kernel times using the OpenCL event profiling API.
    cl_ulong time_ns = getStartEndTime(kernel0_event);
    printf("Kernel time (device %d): %0.3f ms\n", 0, double(time_ns) * 1e-6);

    // Release all events.  
    clReleaseEvent(write_event[0]);
    clReleaseEvent(kernel1_event);
    clReleaseEvent(kernel0_event);
    clReleaseEvent(finish_event);
  
   
}


// Free the resources allocated during initialization
void cleanup() {

    if(kernel0) {
        clReleaseKernel(kernel0);
    }
    if(queue0) {
        clReleaseCommandQueue(queue0);
    }
    if(kernel1) {
        clReleaseKernel(kernel1);
    }
    if(queue1) {
        clReleaseCommandQueue(queue1);
    }
    if(initial_centers_buf) {
        clReleaseMemObject(initial_centers_buf);
    }
    if(visited_nodes_buf) {
        clReleaseMemObject(visited_nodes_buf);
    }
    if(profiling_data_buf) {
        clReleaseMemObject(profiling_data_buf);
    }
    if(new_centers_buf) {
        clReleaseMemObject(new_centers_buf);
    }
    if(distortion_buf) {
        clReleaseMemObject(distortion_buf);
    }

    if(z0_buf) {
        clReleaseMemObject(z0_buf);
    }

    if(program) {
        clReleaseProgram(program);
    }
    
    if(context) {
        clReleaseContext(context);
    }    

    if (root != NULL) {
        deletekdTree(root);
    }

    if (initial_centers != NULL) {
        free(initial_centers);
    }
    if (visited_nodes != NULL) {
        free(visited_nodes);
    }
    if (new_centers != NULL) {
        free(new_centers);
    }
    if (distortion != NULL) {
        free(distortion);
    }

    if (profiling_data != NULL) {
        free(profiling_data);
    }

    cleanup_svm();

}



// Helper functions to display parameters returned by OpenCL queries
static void device_info_ulong( cl_device_id device, cl_device_info param, const char* name) {
    cl_ulong a;
    clGetDeviceInfo(device, param, sizeof(cl_ulong), &a, NULL);
    printf("%-40s = %lu\n", name, a);
}
static void device_info_uint( cl_device_id device, cl_device_info param, const char* name) {
    cl_uint a;
    clGetDeviceInfo(device, param, sizeof(cl_uint), &a, NULL);
    printf("%-40s = %u\n", name, a);
}
static void device_info_bool( cl_device_id device, cl_device_info param, const char* name) {
    cl_bool a;
    clGetDeviceInfo(device, param, sizeof(cl_bool), &a, NULL);
    printf("%-40s = %s\n", name, (a?"true":"false"));
}
static void device_info_string( cl_device_id device, cl_device_info param, const char* name) {
    char a[1024]; 
    clGetDeviceInfo(device, param, 1024, &a, NULL);
    printf("%-40s = %s\n", name, a);
}

static void device_info_size_t( cl_device_id device, cl_device_info param, const char* name) {
    size_t a;
    clGetDeviceInfo(device, param, sizeof(size_t), &a, NULL);
    printf("%-40s = %u\n", name, a);
}

static void device_info_size_t_array( cl_device_id device, cl_device_info param, const char* name) {
    size_t a[3];
    clGetDeviceInfo(device, param, 3*sizeof(size_t), a, NULL);
    printf("%-40s = {%u, %u, %u}\n", name, a[0],a[1],a[2]);
}


// Query and display OpenCL information on device and runtime environment
static void display_device_info( cl_device_id device ) {

    printf("Device info:\n");
    //device_info_string(device, CL_DEVICE_NAME, "CL_DEVICE_NAME");
    device_info_string(device, CL_DEVICE_VENDOR, "CL_DEVICE_VENDOR");
    //device_info_uint(device, CL_DEVICE_VENDOR_ID, "CL_DEVICE_VENDOR_ID");
    device_info_string(device, CL_DEVICE_VERSION, "CL_DEVICE_VERSION");
    device_info_string(device, CL_DRIVER_VERSION, "CL_DRIVER_VERSION");
    device_info_uint(device, CL_DEVICE_ADDRESS_BITS, "CL_DEVICE_ADDRESS_BITS");
    //device_info_bool(device, CL_DEVICE_AVAILABLE, "CL_DEVICE_AVAILABLE");
    //device_info_bool(device, CL_DEVICE_ENDIAN_LITTLE, "CL_DEVICE_ENDIAN_LITTLE");
    device_info_ulong(device, CL_DEVICE_GLOBAL_MEM_CACHE_SIZE, "CL_DEVICE_GLOBAL_MEM_CACHE_SIZE");
    device_info_ulong(device, CL_DEVICE_GLOBAL_MEM_CACHELINE_SIZE, "CL_DEVICE_GLOBAL_MEM_CACHELINE_SIZE");
    device_info_ulong(device, CL_DEVICE_GLOBAL_MEM_SIZE, "CL_DEVICE_GLOBAL_MEM_SIZE");
    device_info_ulong(device, CL_DEVICE_MAX_MEM_ALLOC_SIZE, "CL_DEVICE_MAX_MEM_ALLOC_SIZE");
    device_info_bool(device, CL_DEVICE_IMAGE_SUPPORT, "CL_DEVICE_IMAGE_SUPPORT");
    device_info_ulong(device, CL_DEVICE_LOCAL_MEM_SIZE, "CL_DEVICE_LOCAL_MEM_SIZE");
    device_info_ulong(device, CL_DEVICE_MAX_CLOCK_FREQUENCY, "CL_DEVICE_MAX_CLOCK_FREQUENCY");
    device_info_size_t(device, CL_DEVICE_MAX_WORK_GROUP_SIZE, "CL_DEVICE_MAX_WORK_GROUP_SIZE"); 
    device_info_size_t_array(device, CL_DEVICE_MAX_WORK_ITEM_SIZES, "CL_DEVICE_MAX_WORK_ITEM_SIZES");
    device_info_size_t(device, CL_KERNEL_COMPILE_WORK_GROUP_SIZE, "CL_KERNEL_COMPILE_WORK_GROUP_SIZE");   
    device_info_ulong(device, CL_DEVICE_MAX_COMPUTE_UNITS, "CL_DEVICE_MAX_COMPUTE_UNITS");
    device_info_ulong(device, CL_DEVICE_MAX_CONSTANT_ARGS, "CL_DEVICE_MAX_CONSTANT_ARGS");
    device_info_ulong(device, CL_DEVICE_MAX_CONSTANT_BUFFER_SIZE, "CL_DEVICE_MAX_CONSTANT_BUFFER_SIZE");
    device_info_uint(device, CL_DEVICE_MAX_WORK_ITEM_DIMENSIONS, "CL_DEVICE_MAX_WORK_ITEM_DIMENSIONS");
    device_info_uint(device, CL_DEVICE_MEM_BASE_ADDR_ALIGN, "CL_DEVICE_MEM_BASE_ADDR_ALIGN");
    device_info_uint(device, CL_DEVICE_MIN_DATA_TYPE_ALIGN_SIZE, "CL_DEVICE_MIN_DATA_TYPE_ALIGN_SIZE");
    device_info_uint(device, CL_DEVICE_PREFERRED_VECTOR_WIDTH_CHAR, "CL_DEVICE_PREFERRED_VECTOR_WIDTH_CHAR");
    device_info_uint(device, CL_DEVICE_PREFERRED_VECTOR_WIDTH_SHORT, "CL_DEVICE_PREFERRED_VECTOR_WIDTH_SHORT");
    device_info_uint(device, CL_DEVICE_PREFERRED_VECTOR_WIDTH_INT, "CL_DEVICE_PREFERRED_VECTOR_WIDTH_INT");
    device_info_uint(device, CL_DEVICE_PREFERRED_VECTOR_WIDTH_LONG, "CL_DEVICE_PREFERRED_VECTOR_WIDTH_LONG");
    device_info_uint(device, CL_DEVICE_PREFERRED_VECTOR_WIDTH_FLOAT, "CL_DEVICE_PREFERRED_VECTOR_WIDTH_FLOAT");
    device_info_uint(device, CL_DEVICE_PREFERRED_VECTOR_WIDTH_DOUBLE, "CL_DEVICE_PREFERRED_VECTOR_WIDTH_DOUBLE");    
    {
        cl_command_queue_properties ccp;
        clGetDeviceInfo(device, CL_DEVICE_QUEUE_PROPERTIES, sizeof(cl_command_queue_properties), &ccp, NULL);
        printf("%-40s = %s\n", "Command queue out of order? ", ((ccp & CL_QUEUE_OUT_OF_ORDER_EXEC_MODE_ENABLE)?"true":"false"));
        printf("%-40s = %s\n", "Command queue profiling enabled? ", ((ccp & CL_QUEUE_PROFILING_ENABLE)?"true":"false"));
    }
    
}



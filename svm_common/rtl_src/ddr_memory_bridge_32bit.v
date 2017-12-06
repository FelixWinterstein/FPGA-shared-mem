//////////////////////////////////////////////////////////////////////////////
//
// Felix Winterstein, Imperial College London, 2016
// 
// Module Name: ddr_memory_bridge_32bit - Behavioral
// 
// Revision 1.01
// Additional Comments: distributed under an Apache-2.0 license, see LICENSE
//
//////////////////////////////////////////////////////////////////////////////

module ddr_memory_bridge_32bit_ld
	(
		input 		clock,
		input 		resetn,

        // Avalon ST
		output 		    oready,    
		input 		    ivalid,
		output 		    ovalid,
		input 		    iready,

        // Pass-by-value IO
		input [31:0] 	index,          // virtual memory address provided by the user kernel
		output [31:0] 	read_data,      // data read from memory

        // Mem pointers
		input [63:0] 		mem_pointer0,

        // Avalon MM
		output 		        avm_port0_enable,
		input [255:0] 		avm_port0_readdata,
		input 		        avm_port0_readdatavalid,
		input 		        avm_port0_waitrequest,
		output [27:0] 		avm_port0_address,
		output 		        avm_port0_read,
		output 		        avm_port0_write,
		input 		        avm_port0_writeack,
		output [255:0] 		avm_port0_writedata,
		output [31:0] 		avm_port0_byteenable,
		output [4:0] 		avm_port0_burstcount,

        // misc
		input 		clock2x
	);


    wire start;
    reg [3:0] r_start;
    wire stall_out;


    assign start = (r_start == 4'b0100 || r_start == 4'b0010);   

    always_ff@(posedge clock or negedge resetn)
        if ( !resetn)
            r_start <= 4'b0001;
        else if( ivalid && r_start != 4'b1000)
            r_start <= (r_start << 1);

    assign oready = (~stall_out);

    lsu_top lsu_top_inst (
	    .clock(clock),
	    .clock2x(clock2x),
	    .resetn(resetn),
	    .flush(start),
	    .stream_base_addr(),
	    .stream_size(),
	    .stream_reset(),
	    .o_stall(stall_out),
	    .i_valid(ivalid),
	    .i_address( (mem_pointer0 & 64'hFFFFFFFFFFFFFFFC) + ((index & 64'hFFFFFFFF) << 6'h2)),
	    .i_writedata(),
	    .i_cmpdata(),
	    .i_predicate(1'b0),
	    .i_bitwiseor(64'h0),
	    .i_byteenable(),
	    .i_stall(~(iready)),
	    .o_valid(ovalid),
	    .o_readdata(read_data),
	    .o_input_fifo_depth(),
	    .o_writeack(),
	    .i_atomic_op(3'h0),
	    .o_active(),
	    .avm_address(avm_port0_address),
	    .avm_read(avm_port0_read),
	    .avm_enable(avm_port0_enable),
	    .avm_readdata(avm_port0_readdata),
	    .avm_write(avm_port0_write),
	    .avm_writeack(avm_port0_writeack),
	    .avm_burstcount(avm_port0_burstcount),
	    .avm_writedata(avm_port0_writedata),
	    .avm_byteenable(avm_port0_byteenable),
	    .avm_waitrequest(avm_port0_waitrequest),
	    .avm_readdatavalid(avm_port0_readdatavalid),
	    .profile_bw(),
	    .profile_bw_incr(),
	    .profile_total_ivalid(),
	    .profile_total_req(),
	    .profile_i_stall_count(),
	    .profile_o_stall_count(),
	    .profile_avm_readwrite_count(),
	    .profile_avm_burstcount_total(),
	    .profile_avm_burstcount_total_incr(),
	    .profile_req_cache_hit_count(),
	    .profile_extra_unaligned_reqs(),
	    .profile_avm_stall()
    );

    defparam lsu_top_inst.AWIDTH = 28;
    defparam lsu_top_inst.WIDTH_BYTES = 4;
    defparam lsu_top_inst.MWIDTH_BYTES = 32;
    defparam lsu_top_inst.WRITEDATAWIDTH_BYTES = 32;
    defparam lsu_top_inst.ALIGNMENT_BYTES = 4;
    defparam lsu_top_inst.READ = 1;
    defparam lsu_top_inst.ATOMIC = 0;
    defparam lsu_top_inst.WIDTH = 32;
    defparam lsu_top_inst.MWIDTH = 256;
    defparam lsu_top_inst.ATOMIC_WIDTH = 3;
    defparam lsu_top_inst.BURSTCOUNT_WIDTH = 5;
    defparam lsu_top_inst.KERNEL_SIDE_MEM_LATENCY = 160;
    defparam lsu_top_inst.MEMORY_SIDE_MEM_LATENCY = 131;
    defparam lsu_top_inst.USE_WRITE_ACK = 0;
    defparam lsu_top_inst.ENABLE_BANKED_MEMORY = 0;
    defparam lsu_top_inst.ABITS_PER_LMEM_BANK = 0;
    defparam lsu_top_inst.NUMBER_BANKS = 1;
    defparam lsu_top_inst.LMEM_ADDR_PERMUTATION_STYLE = 0;
    defparam lsu_top_inst.INTENDED_DEVICE_FAMILY = "Stratix V";
    defparam lsu_top_inst.USEINPUTFIFO = 0;
    defparam lsu_top_inst.USECACHING = 0;
    defparam lsu_top_inst.USEOUTPUTFIFO = 1;
    defparam lsu_top_inst.FORCE_NOP_SUPPORT = 0;
    defparam lsu_top_inst.HIGH_FMAX = 1;
    defparam lsu_top_inst.ADDRSPACE = 1;
    defparam lsu_top_inst.STYLE = "BURST-COALESCED";




/*

    host_memory_bridge_a0b1c2d3_32bit_core host_memory_bridge_a0b1c2d3_32bit_core_inst (
            .clock (clock),
            .resetn (resetn),
            .ivalid (ivalid),
            .iready (iready),
            .ovalid (ovalid),
            .oready (oready),
            .ttbr0 (32'b0),
            .va ( ((va & 32'hFFFFFFFF) << 6'h2) ),
            .write (1'b0),
            .write_data (32'b0),
            .read_data (read_data),
            .mem_pointer0 ((mem_pointer0 & 64'hFFFFFFFFFFFFFFFC) ),
            .avm_port0_address(avm_port0_address),
            .avm_port0_read(avm_port0_read),
            //.avm_port0_enable(avm_port0_enable),
            .avm_port0_readdata(avm_port0_readdata),
            .avm_port0_write(avm_port0_write),
            .avm_port0_writeack(avm_port0_writeack),
            .avm_port0_burstcount(avm_port0_burstcount),
            .avm_port0_writedata(avm_port0_writedata),
            .avm_port0_byteenable(avm_port0_byteenable),
            .avm_port0_waitrequest(avm_port0_waitrequest),
            .avm_port0_readdatavalid(avm_port0_readdatavalid)
        );

    assign avm_port0_enable = 1'b1;

*/

endmodule

//////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////

module ddr_memory_bridge_32bit_st
	(
		input 		clock,
		input 		resetn,

        // Avalon ST
		output 		    oready,    
		input 		    ivalid,
		output 		    ovalid,
		input 		    iready,

        // Pass-by-value IO
		input [31:0] 	index,          // virtual memory address provided by the user kernel
        input [31:0]    write_data,     // data to be written into memory
		output [31:0] 	ret_val,        // return value

        // Mem pointers
		input [63:0] 		mem_pointer0,

        // Avalon MM
		output 		        avm_port0_enable,
		input [255:0] 		avm_port0_readdata,
		input 		        avm_port0_readdatavalid,
		input 		        avm_port0_waitrequest,
		output [27:0] 		avm_port0_address,
		output 		        avm_port0_read,
		output 		        avm_port0_write,
		input 		        avm_port0_writeack,
		output [255:0] 		avm_port0_writedata,
		output [31:0] 		avm_port0_byteenable,
		output [4:0] 		avm_port0_burstcount,

        // misc
		input 		clock2x
	);


    wire start;
    reg [3:0] r_start;
    wire stall_out;


    assign start = (r_start == 4'b0100 || r_start == 4'b0010);   

    always_ff@(posedge clock or negedge resetn)
        if ( !resetn)
            r_start <= 4'b0001;
        else if( ivalid && r_start != 4'b1000)
            r_start <= (r_start << 1);

    assign oready = (~stall_out);

    lsu_top lsu_top_inst (
	    .clock(clock),
	    .clock2x(clock2x),
	    .resetn(resetn),
	    .flush(start),
	    .stream_base_addr(),
	    .stream_size(),
	    .stream_reset(),
	    .o_stall(stall_out),
	    .i_valid(ivalid),
	    .i_address( (mem_pointer0 & 64'hFFFFFFFFFFFFFFFC) + ((index & 64'hFFFFFFFF) << 6'h2)),
	    .i_writedata(),
	    .i_cmpdata(),
	    .i_predicate(1'b0),
	    .i_bitwiseor(64'h0),
	    .i_byteenable(),
	    .i_stall(~(iready)),
	    .o_valid(ovalid),
	    .o_readdata(read_data),
	    .o_input_fifo_depth(),
	    .o_writeack(),
	    .i_atomic_op(3'h0),
	    .o_active(),
	    .avm_address(avm_port0_address),
	    .avm_read(avm_port0_read),
	    .avm_enable(avm_port0_enable),
	    .avm_readdata(avm_port0_readdata),
	    .avm_write(avm_port0_write),
	    .avm_writeack(avm_port0_writeack),
	    .avm_burstcount(avm_port0_burstcount),
	    .avm_writedata(avm_port0_writedata),
	    .avm_byteenable(avm_port0_byteenable),
	    .avm_waitrequest(avm_port0_waitrequest),
	    .avm_readdatavalid(avm_port0_readdatavalid),
	    .profile_bw(),
	    .profile_bw_incr(),
	    .profile_total_ivalid(),
	    .profile_total_req(),
	    .profile_i_stall_count(),
	    .profile_o_stall_count(),
	    .profile_avm_readwrite_count(),
	    .profile_avm_burstcount_total(),
	    .profile_avm_burstcount_total_incr(),
	    .profile_req_cache_hit_count(),
	    .profile_extra_unaligned_reqs(),
	    .profile_avm_stall()
    );

    defparam lsu_top_inst.AWIDTH = 28;
    defparam lsu_top_inst.WIDTH_BYTES = 4;
    defparam lsu_top_inst.MWIDTH_BYTES = 32;
    defparam lsu_top_inst.WRITEDATAWIDTH_BYTES = 32;
    defparam lsu_top_inst.ALIGNMENT_BYTES = 4;
    defparam lsu_top_inst.READ = 0;
    defparam lsu_top_inst.ATOMIC = 0;
    defparam lsu_top_inst.WIDTH = 32;
    defparam lsu_top_inst.MWIDTH = 256;
    defparam lsu_top_inst.ATOMIC_WIDTH = 3;
    defparam lsu_top_inst.BURSTCOUNT_WIDTH = 6;
    defparam lsu_top_inst.KERNEL_SIDE_MEM_LATENCY = 4;
    defparam lsu_top_inst.MEMORY_SIDE_MEM_LATENCY = 8;
    defparam lsu_top_inst.USE_WRITE_ACK = 0;
    defparam lsu_top_inst.ENABLE_BANKED_MEMORY = 0;
    defparam lsu_top_inst.ABITS_PER_LMEM_BANK = 0;
    defparam lsu_top_inst.NUMBER_BANKS = 1;
    defparam lsu_top_inst.LMEM_ADDR_PERMUTATION_STYLE = 0;
    defparam lsu_top_inst.INTENDED_DEVICE_FAMILY = "Stratix V";
    defparam lsu_top_inst.USEINPUTFIFO = 0;
    defparam lsu_top_inst.USECACHING = 0;
    defparam lsu_top_inst.USEOUTPUTFIFO = 1;
    defparam lsu_top_inst.FORCE_NOP_SUPPORT = 0;
    defparam lsu_top_inst.HIGH_FMAX = 1;
    defparam lsu_top_inst.ADDRSPACE = 1;
    defparam lsu_top_inst.STYLE = "BURST-COALESCED";
    defparam lsu_top_inst.USE_BYTE_EN = 0;



/*

    host_memory_bridge_a0b1c2d3_32bit_core host_memory_bridge_a0b1c2d3_32bit_core_inst (
            .clock (clock),
            .resetn (resetn),
            .ivalid (ivalid),
            .iready (iready),
            .ovalid (ovalid),
            .oready (oready),
            .ttbr0 (32'b0),
            .va ( ((va & 32'hFFFFFFFF) << 6'h2) ),
            .write (1'b0),
            .write_data (32'b0),
            .read_data (read_data),
            .mem_pointer0 ((mem_pointer0 & 64'hFFFFFFFFFFFFFFFC) ),
            .avm_port0_address(avm_port0_address),
            .avm_port0_read(avm_port0_read),
            //.avm_port0_enable(avm_port0_enable),
            .avm_port0_readdata(avm_port0_readdata),
            .avm_port0_write(avm_port0_write),
            .avm_port0_writeack(avm_port0_writeack),
            .avm_port0_burstcount(avm_port0_burstcount),
            .avm_port0_writedata(avm_port0_writedata),
            .avm_port0_byteenable(avm_port0_byteenable),
            .avm_port0_waitrequest(avm_port0_waitrequest),
            .avm_port0_readdatavalid(avm_port0_readdatavalid)
        );

    assign avm_port0_enable = 1'b1;

*/

endmodule




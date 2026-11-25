// sc_blocks.v: the structures that the memory-ordering options need, as small synthesisable models, for the NAND2 count of tools/gates/gates.sh
// (yosys synth, abc to NAND, count = NAND + half the inverters; a flip-flop is counted apart and as 6 in totals).  These are models of the
// structures in the papers named in why-not-sequential-consistency.md, not a design of a core: no timing, no protocol, no reset values.

// ---- (a)/(d): the store buffer of an in-order core.  D entries of 64-bit data, 8-bit byte mask, 45-bit word address (48-bit physical, 8-byte word).
// Entries are filled in order at the tail and leave in order at the head.  A load probes all entries for a match of the 8-byte word whose mask
// covers the load's bytes, and takes the data of the youngest matching entry (forwarding).  This is what TSO needs.
module sb_tso #(parameter D = 8, parameter AW = 45) (
	input clk, input push, input [AW-1:0] pa, input [63:0] pd, input [7:0] pm,
	input pop,
	input [AW-1:0] la, input [7:0] lm,
	output [63:0] fdata, output fhit, output fpartial,
	output [AW-1:0] head_a, output [63:0] head_d, output [7:0] head_m, output any);
	reg [AW-1:0] a [0:D-1]; reg [63:0] d [0:D-1]; reg [7:0] m [0:D-1]; reg [D-1:0] v;
	reg [$clog2(D)-1:0] tl, hd;
	integer i;
	always @(posedge clk) begin
		if (push) begin a[tl] <= pa; d[tl] <= pd; m[tl] <= pm; v[tl] <= 1'b1; tl <= tl + 1'b1; end
		if (pop) begin v[hd] <= 1'b0; hd <= hd + 1'b1; end
	end
	// match vector, youngest first: entry age = (tl - 1 - k) mod D, scanned as a priority chain
	reg [D-1:0] match, covd;
	always @* begin
		for (i = 0; i < D; i = i + 1) begin
			match[i] = v[i] & (a[i] == la) & ((m[i] & lm) != 8'b0);
			covd[i] = v[i] & (a[i] == la) & ((m[i] & lm) == lm);
		end
	end
	reg [63:0] fd; reg fh, fp; reg found; integer k, idx;
	always @* begin
		fd = 64'b0; fh = 1'b0; fp = 1'b0; found = 1'b0;
		for (k = 0; k < D; k = k + 1) begin
			idx = (tl - 1 - k) & (D - 1);
			if (!found && match[idx]) begin found = 1'b1; fd = d[idx]; fh = covd[idx]; fp = ~covd[idx]; end
		end
	end
	assign fdata = fd; assign fhit = fh; assign fpartial = fp;
	assign head_a = a[hd]; assign head_d = d[hd]; assign head_m = m[hd]; assign any = |v;
endmodule

// ---- what SC adds to the store buffer of an in-order core: a load that does not forward from the buffer stalls while the buffer holds a store
module sc_stall_term (input ld_valid, input fhit, input any_store_unperformed, output stall);
	assign stall = ld_valid & ~fhit & any_store_unperformed;
endmodule

// ---- ownership prefetch: a table of the lines requested for ownership (tag, valid, done), one lookup to avoid asking twice; the request goes out when a store is issued
module own_prefetch #(parameter E = 4, parameter LW = 42) (
	input clk, input req, input [LW-1:0] line, input fill_valid, input [LW-1:0] fill_line,
	output out_req, output [LW-1:0] out_line, output dup);
	reg [LW-1:0] t [0:E-1]; reg [E-1:0] v; reg [$clog2(E)-1:0] wp;
	integer i; reg hit;
	always @* begin hit = 1'b0; for (i = 0; i < E; i = i + 1) if (v[i] && t[i] == line) hit = 1'b1; end
	always @(posedge clk) begin
		if (req && !hit) begin t[wp] <= line; v[wp] <= 1'b1; wp <= wp + 1'b1; end
		for (i = 0; i < E; i = i + 1) if (fill_valid && v[i] && t[i] == fill_line) v[i] <= 1'b0;
	end
	assign dup = hit; assign out_req = req & ~hit; assign out_line = line;
endmodule

// ---- (b): the load queue of an out-of-order core with snoop replay (the R10000 method): N entries of a 64-byte line tag (42 bits), valid and completed.
// Every incoming invalidation or eviction compares its line against all N entries at once (a CAM); a completed load that matches is marked for replay.
// The oldest marked load is found by a priority encode (the pipeline restarts from it).
module lq_snoop #(parameter N = 32, parameter LW = 42) (
	input clk, input alloc, input [LW-1:0] alloc_line, input complete, input [$clog2(N)-1:0] complete_idx, input retire,
	input snoop_valid, input [LW-1:0] snoop_line,
	output replay_any, output [$clog2(N)-1:0] replay_idx);
	reg [LW-1:0] t [0:N-1]; reg [N-1:0] v, done, mark;
	reg [$clog2(N)-1:0] tl, hd;
	integer i, k;
	always @(posedge clk) begin
		if (alloc) begin t[tl] <= alloc_line; v[tl] <= 1'b1; done[tl] <= 1'b0; mark[tl] <= 1'b0; tl <= tl + 1'b1; end
		if (complete) done[complete_idx] <= 1'b1;
		if (retire) begin v[hd] <= 1'b0; hd <= hd + 1'b1; end
		for (i = 0; i < N; i = i + 1) if (snoop_valid && v[i] && done[i] && t[i] == snoop_line) mark[i] <= 1'b1;
	end
	reg any; reg [$clog2(N)-1:0] idx; reg found;
	always @* begin
		any = 1'b0; idx = 0; found = 1'b0;
		for (k = 0; k < N; k = k + 1) begin
			// oldest first: starting at the head of the queue
			if (!found && v[(hd + k) & (N - 1)] && mark[(hd + k) & (N - 1)]) begin found = 1'b1; any = 1'b1; idx = (hd + k) & (N - 1); end
		end
	end
	assign replay_any = any; assign replay_idx = idx;
endmodule

// ---- (c): InvisiFence-style post-retirement speculation, the parts that are new: a register checkpoint (32 x 64-bit registers, flags and pc),
// a speculatively-read and a speculatively-written bit for each line of the L1 data cache (LINES lines), a flash clear of both arrays at commit
// and at abort, and the violation check on a snoop (the snoop already reads the tag; here it also reads the two bits of the matched line).
module invisifence #(parameter LINES = 512) (
	input clk, input spec_begin, input spec_commit, input spec_abort,
	input [63:0] rf_in, input [4:0] rf_idx, input rf_wr,
	input rd_hit, input [$clog2(LINES)-1:0] rd_line,
	input wr_hit, input [$clog2(LINES)-1:0] wr_line,
	input snoop_hit, input [$clog2(LINES)-1:0] snoop_line, input snoop_is_inval,
	input [4:0] restore_idx,
	output [63:0] restore_data, output violation, output specmode);
	reg [63:0] ck [0:31]; reg [63:0] ckpc; reg [3:0] ckfl;
	reg [LINES-1:0] sr, sw; reg spec;
	always @(posedge clk) begin
		if (spec_begin) begin spec <= 1'b1; end
		if (rf_wr && !spec) ck[rf_idx] <= rf_in;            // the checkpoint tracks the architectural file until speculation starts (a shadow copy)
		if (spec_commit || spec_abort) begin sr <= {LINES{1'b0}}; sw <= {LINES{1'b0}}; spec <= 1'b0; end
		else begin
			if (spec && rd_hit) sr[rd_line] <= 1'b1;
			if (spec && wr_hit) sw[wr_line] <= 1'b1;
		end
	end
	assign violation = spec & snoop_hit & ((snoop_is_inval & (sr[snoop_line] | sw[snoop_line])) | (~snoop_is_inval & sw[snoop_line]));
	assign restore_data = ck[restore_idx]; assign specmode = spec;
endmodule

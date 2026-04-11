`timescale 1ns/1ps

module tb_xor_permute;
    parameter int WORDS = 16;
    parameter int BITS_PER_WORD = 64;
    localparam int D = WORDS * BITS_PER_WORD;
    localparam int WORD_W = BITS_PER_WORD;
    localparam int WORDS_W = WORDS;

    logic clk, rst_n;
    logic in_valid, in_ready;
    logic [D-1:0] in_vec_flat;
    logic [D-1:0] bind_vec_flat;
    logic [1:0] perm_mode;
    logic [$clog2(D)-1:0] perm_param;
    logic out_valid, out_ready;
    logic [D-1:0] out_vec_flat;

    int test_count = 0;
    int pass_count = 0;

    // DUT
    xor_permute_top #(WORDS, BITS_PER_WORD) dut (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(in_valid),
        .in_ready(in_ready),
        .in_vec_flat(in_vec_flat),
        .bind_vec_flat(bind_vec_flat),
        .perm_mode(perm_mode),
        .perm_param(perm_param),
        .out_valid(out_valid),
        .out_ready(out_ready),
        .out_vec_flat(out_vec_flat)
    );

    // -------------------------
    // Clock
    // -------------------------
    initial clk = 0;
    always #5 clk = ~clk; // 100 MHz

    // -------------------------
    // Helper: full-vector rotate right
    // Matches:
    // rotated[b] = vec[(b + r) % D]
    // -------------------------
    function automatic logic [D-1:0] rotate_right_vec(
        input logic [D-1:0] vec,
        input int unsigned r
    );
        logic [D-1:0] tmp;
        int i;
        int rr;
        begin
            rr = r % D;
            for (i = 0; i < D; i++) begin
                tmp[i] = vec[(i + rr) % D];
            end
            return tmp;
        end
    endfunction

    // -------------------------
    // Helper: per-word rotate right
    // -------------------------
    function automatic logic [D-1:0] rotate_right_each_word(
        input logic [D-1:0] vec,
        input int unsigned r
    );
        logic [D-1:0] tmp;
        logic [BITS_PER_WORD-1:0] w;
        logic [BITS_PER_WORD-1:0] wr;
        int wi, bi;
        int rr;
        begin
            rr = r % BITS_PER_WORD;
            tmp = '0;
            for (wi = 0; wi < WORDS; wi++) begin
                w = vec[wi*BITS_PER_WORD +: BITS_PER_WORD];
                for (bi = 0; bi < BITS_PER_WORD; bi++) begin
                    wr[bi] = w[(bi + rr) % BITS_PER_WORD];
                end
                tmp[wi*BITS_PER_WORD +: BITS_PER_WORD] = wr;
            end
            return tmp;
        end
    endfunction

    // -------------------------
    // Helper: fixed word reverse
    // mode 00 in your permute_stage
    // -------------------------
    function automatic logic [D-1:0] reverse_words(
        input logic [D-1:0] vec
    );
        logic [D-1:0] tmp;
        int wi;
        begin
            tmp = '0;
            for (wi = 0; wi < WORDS; wi++) begin
                tmp[wi*BITS_PER_WORD +: BITS_PER_WORD] =
                    vec[(WORDS-1-wi)*BITS_PER_WORD +: BITS_PER_WORD];
            end
            return tmp;
        end
    endfunction

    // -------------------------
    // Golden model
    // IMPORTANT:
    // This assumes permute_stage behavior is:
    // 00 = fixed word reverse
    // 01 = per-word rotate right
    // 10 = full-vector rotate right
    // 11 = passthrough
    // -------------------------
    function automatic logic [D-1:0] golden_model(
        input logic [D-1:0] in_v,
        input logic [D-1:0] bind_v,
        input logic [1:0] mode,
        input logic [$clog2(D)-1:0] param
    );
        logic [D-1:0] bound;
        begin
            bound = in_v ^ bind_v;

            case (mode)
                2'b00: golden_model = reverse_words(bound);
                2'b01: golden_model = rotate_right_each_word(bound, param);
                2'b10: golden_model = rotate_right_vec(bound, param);
                default: golden_model = bound;
            endcase
        end
    endfunction

    // -------------------------
    // Pretty print test result
    // -------------------------
    task automatic report_result(
        input string testname,
        input logic [D-1:0] expected,
        input logic [D-1:0] actual
    );
        begin
            test_count++;
            if (actual !== expected) begin
                $display("--------------------------------------------------");
                $display("FAIL: %s", testname);
                $display("Expected = %h", expected);
                $display("Actual   = %h", actual);
                $display("Time     = %0t", $time);
                $display("--------------------------------------------------");
                $fatal(1, "Test failed");
            end
            else begin
                pass_count++;
                $display("PASS: %s", testname);
            end
        end
    endtask

    // -------------------------
    // Drive one transaction and check output
    // stall_cycles lets you test out_ready backpressure
    // -------------------------
    task automatic run_test(
        input string testname,
        input logic [D-1:0] in_v,
        input logic [D-1:0] bind_v,
        input logic [1:0] mode,
        input logic [$clog2(D)-1:0] param,
        input int stall_cycles = 0
    );
        logic [D-1:0] expected;
        logic [D-1:0] held_out;
        int k;
        begin
            expected = golden_model(in_v, bind_v, mode, param);

            // Apply inputs
            @(posedge clk);
            while (!in_ready) @(posedge clk);

            in_vec_flat   <= in_v;
            bind_vec_flat <= bind_v;
            perm_mode     <= mode;
            perm_param    <= param;
            in_valid      <= 1'b1;

            @(posedge clk);
            while (!in_ready) @(posedge clk);
            in_valid <= 1'b0;

            // Wait for output valid
            wait (out_valid == 1'b1);

            // Optional backpressure test
            if (stall_cycles > 0) begin
                out_ready <= 1'b0;
                held_out  = out_vec_flat;

                for (k = 0; k < stall_cycles; k++) begin
                    @(posedge clk);
                    if (out_vec_flat !== held_out) begin
                        $display("FAIL: %s -- output changed while stalled", testname);
                        $display("Held    = %h", held_out);
                        $display("Current = %h", out_vec_flat);
                        $fatal(1, "Output stability under stall failed");
                    end
                    if (out_valid !== 1'b1) begin
                        $display("FAIL: %s -- out_valid deasserted during stall", testname);
                        $fatal(1, "out_valid stability under stall failed");
                    end
                end

                out_ready <= 1'b1;
                @(posedge clk);
            end
            else begin
                @(posedge clk);
            end

            report_result(testname, expected, out_vec_flat);
        end
    endtask

    // -------------------------
    // Reset task
    // -------------------------
    task automatic apply_reset;
        begin
            rst_n         <= 1'b0;
            in_valid      <= 1'b0;
            out_ready     <= 1'b1;
            in_vec_flat   <= '0;
            bind_vec_flat <= '0;
            perm_mode     <= 2'b00;
            perm_param    <= '0;

            repeat (5) @(posedge clk);
            rst_n <= 1'b1;
            repeat (2) @(posedge clk);
        end
    endtask

    // -------------------------
    // Main stimulus
    // -------------------------
    initial begin
        apply_reset();

        // Test 1: full rotate, same as your original example
        run_test(
            "full_rotate_73_basic",
            {16{64'h0123_4567_89AB_CDEF}},
            {16{64'hFFFF_0000_FFFF_0000}},
            2'b10,
            11'd73,
            0
        );

        // Test 2: fixed word reverse
        run_test(
            "mode00_word_reverse",
            {
                64'h000F, 64'h000E, 64'h000D, 64'h000C,
                64'h000B, 64'h000A, 64'h0009, 64'h0008,
                64'h0007, 64'h0006, 64'h0005, 64'h0004,
                64'h0003, 64'h0002, 64'h0001, 64'h0000
            },
            {16{64'h0000_0000_0000_0000}},
            2'b00,
            '0,
            0
        );

        // Test 3: per-word rotate by 1
        run_test(
            "mode01_per_word_rotate_1",
            {16{64'h8000_0000_0000_0001}},
            {16{64'h0000_0000_0000_0000}},
            2'b01,
            11'd1,
            0
        );

        // Test 4: full-vector rotate by 0
        run_test(
            "mode10_full_rotate_0",
            {16{64'hDEAD_BEEF_CAFE_F00D}},
            {16{64'h1111_2222_3333_4444}},
            2'b10,
            11'd0,
            0
        );

        // Test 5: full-vector rotate by 64
        run_test(
            "mode10_full_rotate_64",
            {
                64'h0011, 64'h2233, 64'h4455, 64'h6677,
                64'h8899, 64'hAABB, 64'hCCDD, 64'hEEFF,
                64'h1111, 64'h3333, 64'h5555, 64'h7777,
                64'h9999, 64'hBBBB, 64'hDDDD, 64'hFFFF
            },
            {16{64'h0}},
            2'b10,
            11'd64,
            0
        );

        // Test 6: full-vector rotate by 1023
        run_test(
            "mode10_full_rotate_1023",
            {16{64'h0123_4567_89AB_CDEF}},
            {16{64'hFFFF_FFFF_0000_0000}},
            2'b10,
            11'd1023,
            0
        );

        // Test 7: output stall behavior
        run_test(
            "stall_output_while_valid",
            {16{64'h1357_9BDF_2468_ACE0}},
            {16{64'hFFFF_0000_AAAA_5555}},
            2'b10,
            11'd17,
            3
        );

        $display("==================================================");
        $display("ALL TESTS PASSED");
        $display("Passed %0d / %0d tests", pass_count, test_count);
        $display("==================================================");

        #20;
        $finish;
    end

endmodule

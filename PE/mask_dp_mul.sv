// Duplex Multiplier using Masked Booth Multiplier
// This multiplier can operate in two modes:
// - dp_mode = 0: Normal single multiplication (a * b)
// - dp_mode = 1: Dual parallel multiplication (a_high * b_high || a_low * b_low)

module mask_dp_mul #(
    parameter WIDTH = 8  // Width of input operands (must be even for duplex mode)
)(
    input  logic [WIDTH-1:0] a,           // First operand
    input  logic [WIDTH-1:0] b,           // Second operand
    input  logic [2*WIDTH-1:0] mask,      // Mask for protection
    input  logic dp_mode,                 // Duplex mode: 0=normal, 1=duplex
    input  logic is_signed,               // 1 for signed, 0 for unsigned
    output logic [2*WIDTH-1:0] result     // Result
);

    localparam int HALF_WIDTH = WIDTH / 2;
    
    // Split inputs into high and low parts
    logic [HALF_WIDTH-1:0] a_high, a_low;
    logic [HALF_WIDTH-1:0] b_high, b_low;
    
    assign a_high = a[WIDTH-1:HALF_WIDTH];
    assign a_low = a[HALF_WIDTH-1:0];
    assign b_high = b[WIDTH-1:HALF_WIDTH];
    assign b_low = b[HALF_WIDTH-1:0];
    
    // Results from multipliers
    logic [2*WIDTH-1:0] full_result;              // Result from full-width multiplier
    logic [2*HALF_WIDTH-1:0] high_result;         // Result from high-half multiplier (HALF_WIDTH × HALF_WIDTH)
    logic [2*HALF_WIDTH-1:0] low_result;          // Result from low-half multiplier (HALF_WIDTH × HALF_WIDTH)
    
    // Masks for duplex mode
    logic [2*HALF_WIDTH-1:0] mask_high, mask_low;
    assign mask_high = mask[2*WIDTH-1:WIDTH];     // Upper half of mask for high multiplier
    assign mask_low = mask[WIDTH-1:0];            // Lower half of mask for low multiplier
    
    // Full-width masked multiplier (for dp_mode = 0)
    mask_mul #(.WIDTH(WIDTH)) full_multiplier (
        .a(a),
        .b(b),
        .mask(mask),
        .is_signed(is_signed),
        .result(full_result)
    );
    
    // High-half masked multiplier (for dp_mode = 1)
    mask_mul #(.WIDTH(HALF_WIDTH)) high_multiplier (
        .a(a_high),
        .b(b_high), 
        .mask(mask_high),
        .is_signed(is_signed),
        .result(high_result)
    );
    
    // Low-half masked multiplier (for dp_mode = 1)
    mask_mul #(.WIDTH(HALF_WIDTH)) low_multiplier (
        .a(a_low),
        .b(b_low),
        .mask(mask_low),
        .is_signed(is_signed), 
        .result(low_result)
    );
    
    // Output multiplexer
    always_comb begin
        case (dp_mode)
            1'b0: result = full_result;                    // Normal mode: single full-width multiplication
            1'b1: result = {high_result, low_result};      // Duplex mode: concatenate two half-width multiplications
            default: result = full_result;
        endcase
    end

endmodule

// Testbench for duplex masked multiplier
module mask_dp_mul_tb;
    parameter WIDTH = 8;
    
    logic [WIDTH-1:0] a, b;
    logic [2*WIDTH-1:0] mask;
    logic dp_mode;
    logic is_signed;
    logic [2*WIDTH-1:0] result;
    
    // Expected results
    logic [2*WIDTH-1:0] expected_normal;
    logic [2*(WIDTH/2)-1:0] expected_high, expected_low;  // Each is HALF_WIDTH × HALF_WIDTH
    logic [2*WIDTH-1:0] expected_duplex;
    
    // Test statistics
    int passed_tests = 0;
    int failed_tests = 0;
    int total_tests = 0;
    
    // Variables for comparison tests
    logic [WIDTH-1:0] comp_a, comp_b;
    logic [2*WIDTH-1:0] comp_mask;
    
    // Variables for random tests
    logic [WIDTH-1:0] rand_a, rand_b;
    logic [2*WIDTH-1:0] rand_mask;
    int i;
    
    // DUT instantiation
    mask_dp_mul #(.WIDTH(WIDTH)) dut (
        .a(a),
        .b(b),
        .mask(mask),
        .dp_mode(dp_mode),
        .is_signed(is_signed),
        .result(result)
    );
    
    // Task to run a single test
    task automatic run_test(
        input [WIDTH-1:0] test_a,
        input [WIDTH-1:0] test_b,
        input [2*WIDTH-1:0] test_mask,
        input test_dp_mode,
        input test_is_signed,
        input string test_name
    );
        a = test_a;
        b = test_b;
        mask = test_mask;
        dp_mode = test_dp_mode;
        is_signed = test_is_signed;
        
        // Calculate expected results based on signed/unsigned mode
        if (test_is_signed) begin
            expected_normal = $signed(a) * $signed(b);
            expected_high = $signed(a[WIDTH-1:WIDTH/2]) * $signed(b[WIDTH-1:WIDTH/2]);
            expected_low = $signed(a[WIDTH/2-1:0]) * $signed(b[WIDTH/2-1:0]);
        end else begin
            expected_normal = a * b;
            expected_high = a[WIDTH-1:WIDTH/2] * b[WIDTH-1:WIDTH/2];
            expected_low = a[WIDTH/2-1:0] * b[WIDTH/2-1:0];
        end
        // For duplex mode: concatenate the full multiplication results
        expected_duplex = {expected_high, expected_low};
        
        #1;  // Small delay for combinational logic
        
        total_tests++;
        
        if (dp_mode == 0) begin
            // Normal mode test
            if (result == expected_normal) begin
                passed_tests++;
                $display("PASS: %s (Normal %s) - %0d * %0d = %0d", 
                         test_name, test_is_signed ? "signed" : "unsigned",
                         test_is_signed ? $signed(a) : a, 
                         test_is_signed ? $signed(b) : b, 
                         test_is_signed ? $signed(result) : result);
            end else begin
                failed_tests++;
                $display("FAIL: %s (Normal %s) - %0d * %0d = %0d, Expected: %0d", 
                         test_name, test_is_signed ? "signed" : "unsigned",
                         test_is_signed ? $signed(a) : a, 
                         test_is_signed ? $signed(b) : b, 
                         test_is_signed ? $signed(result) : result, 
                         test_is_signed ? $signed(expected_normal) : expected_normal);
            end
        end else begin
            // Duplex mode test
            if (result == expected_duplex) begin
                passed_tests++;
                $display("PASS: %s (Duplex %s) - High:%0d*%0d=%0d, Low:%0d*%0d=%0d", 
                         test_name, test_is_signed ? "signed" : "unsigned",
                         test_is_signed ? $signed(a[WIDTH-1:WIDTH/2]) : a[WIDTH-1:WIDTH/2], 
                         test_is_signed ? $signed(b[WIDTH-1:WIDTH/2]) : b[WIDTH-1:WIDTH/2], 
                         test_is_signed ? $signed(result[2*WIDTH-1:WIDTH]) : result[2*WIDTH-1:WIDTH],
                         test_is_signed ? $signed(a[WIDTH/2-1:0]) : a[WIDTH/2-1:0], 
                         test_is_signed ? $signed(b[WIDTH/2-1:0]) : b[WIDTH/2-1:0], 
                         test_is_signed ? $signed(result[WIDTH-1:0]) : result[WIDTH-1:0]);
            end else begin
                failed_tests++;
                $display("FAIL: %s (Duplex %s) - Result: 0x%h, Expected: 0x%h", 
                         test_name, test_is_signed ? "signed" : "unsigned", result, expected_duplex);
                $display("      High: Got %0d, Expected %0d", 
                         test_is_signed ? $signed(result[2*WIDTH-1:WIDTH]) : result[2*WIDTH-1:WIDTH], 
                         test_is_signed ? $signed(expected_high) : expected_high);
                $display("      Low:  Got %0d, Expected %0d", 
                         test_is_signed ? $signed(result[WIDTH-1:0]) : result[WIDTH-1:0], 
                         test_is_signed ? $signed(expected_low) : expected_low);
            end
        end
    endtask
    
    // Test sequence
    initial begin
        $display("=================================================================");
        $display("Duplex Masked Multiplier Testbench (Using New mask_mul)");
        $display("Width = %0d bits, Half-width = %0d bits", WIDTH, WIDTH/2);
        $display("Testing both SIGNED and UNSIGNED modes");
        $display("=================================================================");
        
        // ========== NORMAL MODE TESTS ==========
        $display("\n--- NORMAL MODE TESTS ---");
        
        // Basic normal mode tests - unsigned
        run_test(8'd15, 8'd17, 16'h1234, 1'b0, 1'b0, "Basic Normal Unsigned");
        run_test(8'hFF, 8'hFF, 16'hABCD, 1'b0, 1'b0, "MaxUns * MaxUns Normal");
        run_test(8'd0, 8'd100, 16'hDEF0, 1'b0, 1'b0, "Zero multiplication Normal Unsigned");
        
        // Basic normal mode tests - signed  
        run_test(8'sd15, 8'sd17, 16'h1234, 1'b0, 1'b1, "Basic Normal Signed");
        run_test(8'sd127, 8'sd127, 16'hABCD, 1'b0, 1'b1, "MaxPos * MaxPos Normal");
        run_test(-8'sd128, -8'sd128, 16'h5678, 1'b0, 1'b1, "MinNeg * MinNeg Normal");
        run_test(8'sd127, -8'sd128, 16'h9ABC, 1'b0, 1'b1, "MaxPos * MinNeg Normal");
        run_test(8'sd0, 8'sd100, 16'hDEF0, 1'b0, 1'b1, "Zero multiplication Normal Signed");
        
        // ========== DUPLEX MODE TESTS ==========
        $display("\n--- DUPLEX MODE TESTS ---");
        
        // Basic duplex mode tests - unsigned
        // Example: a=0x12, b=0x34 -> a_high=1, a_low=2, b_high=3, b_low=4
        // Expected: high_result = 1*3=3 (00003), low_result = 2*4=8 (0008) -> result = 0x00030008
        run_test(8'h12, 8'h34, 16'h1234, 1'b1, 1'b0, "Basic Duplex Unsigned 0x12*0x34");
        run_test(8'hFF, 8'hFF, 16'h5555, 1'b1, 1'b0, "Max Duplex Unsigned 0xFF*0xFF");
        
        // Basic duplex mode tests - signed
        run_test(8'h12, 8'h34, 16'h1234, 1'b1, 1'b1, "Basic Duplex Signed 0x12*0x34");  
        run_test(8'h77, 8'h77, 16'hFFFF, 1'b1, 1'b1, "Positive Duplex Signed");
        
        // Zero tests in duplex mode
        run_test(8'h00, 8'h12, 16'h7777, 1'b1, 1'b0, "Zero High in Duplex Unsigned");
        run_test(8'h10, 8'h00, 16'h8888, 1'b1, 1'b0, "Zero Low in Duplex Unsigned");
        run_test(8'h00, 8'h12, 16'h7777, 1'b1, 1'b1, "Zero High in Duplex Signed");
        run_test(8'h10, 8'h00, 16'h8888, 1'b1, 1'b1, "Zero Low in Duplex Signed");
        
        // ========== COMPARISON TESTS ==========
        $display("\n--- MODE COMPARISON TESTS ---");
        
        // Same inputs, different modes - to verify mode switching
        comp_a = 8'h23;
        comp_b = 8'h45;
        comp_mask = 16'hBEEF;
        
        run_test(comp_a, comp_b, comp_mask, 1'b0, 1'b0, "Comparison Normal Unsigned");
        run_test(comp_a, comp_b, comp_mask, 1'b1, 1'b0, "Comparison Duplex Unsigned");
        run_test(comp_a, comp_b, comp_mask, 1'b0, 1'b1, "Comparison Normal Signed");
        run_test(comp_a, comp_b, comp_mask, 1'b1, 1'b1, "Comparison Duplex Signed");
        
        // ========== RANDOM TESTS ==========
        $display("\n--- RANDOM TESTS ---");
        
        // Random tests for both modes and both sign types
        for (i = 0; i < 25; i++) begin
            rand_a = $random;
            rand_b = $random;
            rand_mask = $random;
            
            // Test all combinations: normal/duplex × unsigned/signed
            run_test(rand_a, rand_b, rand_mask, 1'b0, 1'b0, $sformatf("Random Normal Unsigned[%0d]", i));
            run_test(rand_a, rand_b, rand_mask, 1'b1, 1'b0, $sformatf("Random Duplex Unsigned[%0d]", i));
            run_test(rand_a, rand_b, rand_mask, 1'b0, 1'b1, $sformatf("Random Normal Signed[%0d]", i));
            run_test(rand_a, rand_b, rand_mask, 1'b1, 1'b1, $sformatf("Random Duplex Signed[%0d]", i));
        end
        
        // ========== TEST SUMMARY ==========
        $display("\n=================================================================");
        $display("TEST SUMMARY:");
        $display("Total tests run: %0d", total_tests);
        $display("Passed: %0d", passed_tests);
        $display("Failed: %0d", failed_tests);
        $display("Pass rate: %0.2f%%", (real'(passed_tests) / real'(total_tests)) * 100.0);
        
        if (failed_tests == 0) begin
            $display("🎉 ALL TESTS PASSED! 🎉");
        end else begin
            $display("❌ %0d TESTS FAILED!", failed_tests);
        end
        
        $display("=================================================================");
        $finish;
    end
    
endmodule

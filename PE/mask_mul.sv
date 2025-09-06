// Masked Radix-4 Booth Multiplier using Carry Save Adder Tree
// This multiplier performs a*b with masking protection during computation using Booth encoding
// Uses radix-4 Booth algorithm to reduce the number of partial products
// The mask is added at the beginning and subtracted at the end of CSA tree
// All computation is done combinationally in a single cycle
// Supports both signed and unsigned multiplication

module mask_mul #(
    parameter WIDTH = 8  // Width of input operands
)(
    input  logic [WIDTH-1:0] a,      // First operand
    input  logic [WIDTH-1:0] b,      // Second operand
    input  logic [2*WIDTH-1:0] mask, // Mask for protection
    input  logic is_signed,          // 1 for signed, 0 for unsigned
    output logic [2*WIDTH-1:0] result // Final result
);

    // For unsigned multiplication, we extend operands to ensure proper Booth encoding
    // For radix-4 Booth, we need to handle the bit width properly
    // Unsigned: zero-extend to make it a positive signed number
    // Signed: may need padding to ensure proper Booth stages
    
    // Calculate proper extension for radix-4 Booth
    // We need WIDTH to be even for clean radix-4 implementation, so extend as needed
    localparam int PADDED_WIDTH = ((WIDTH % 2) == 0) ? WIDTH + 2 : WIDTH + 1;  
    localparam int BOOTH_STAGES = PADDED_WIDTH / 2;  // Number of Booth stages for radix-4
    
    // Extended operands
    logic [PADDED_WIDTH-1:0] a_ext, b_ext;
    
    // Extension logic: zero-extend for unsigned, sign-extend for signed
    always_comb begin
        if (is_signed) begin
            // For signed: sign extend to padded width
            a_ext = {{(PADDED_WIDTH-WIDTH){a[WIDTH-1]}}, a};
            b_ext = {{(PADDED_WIDTH-WIDTH){b[WIDTH-1]}}, b};
        end else begin
            // For unsigned: zero extend to make it positive signed number
            a_ext = {{(PADDED_WIDTH-WIDTH){1'b0}}, a};
            b_ext = {{(PADDED_WIDTH-WIDTH){1'b0}}, b};
        end
    end
    
    // Extended mask for the wider multiplication
    logic [2*PADDED_WIDTH-1:0] mask_ext;
    assign mask_ext = {{(2*PADDED_WIDTH-2*WIDTH){is_signed ? mask[2*WIDTH-1] : 1'b0}}, mask};
    
    // Booth encoded partial products (using extended width)
    logic [2*PADDED_WIDTH-1:0] booth_pp [BOOTH_STAGES-1:0];
    
    // Extended multiplier for Booth encoding (add leading zero for radix-4)
    logic [PADDED_WIDTH:0] b_extended;
    assign b_extended = {b_ext, 1'b0};
    
    // Generate Booth encoded partial products
    genvar i;
    generate
        for (i = 0; i < BOOTH_STAGES; i++) begin : gen_booth_pp
            logic [2:0] booth_bits;
            logic [2*PADDED_WIDTH-1:0] booth_operand;
            
            // Extract 3 bits for Booth encoding (overlapping)
            assign booth_bits = b_extended[2*i+2:2*i];
            
            // Booth lookup table for radix-4 (always use signed extension since we handle unsigned by pre-extension)
            always_comb begin
                case (booth_bits)
                    3'b000: booth_operand = {2*PADDED_WIDTH{1'b0}};        // 0 * a
                    3'b001: booth_operand = {{PADDED_WIDTH{a_ext[PADDED_WIDTH-1]}}, a_ext};     // +1 * a
                    3'b010: booth_operand = {{PADDED_WIDTH{a_ext[PADDED_WIDTH-1]}}, a_ext};     // +1 * a  
                    3'b011: booth_operand = {{PADDED_WIDTH{a_ext[PADDED_WIDTH-1]}}, a_ext} << 1; // +2 * a
                    3'b100: booth_operand = -({{PADDED_WIDTH{a_ext[PADDED_WIDTH-1]}}, a_ext} << 1); // -2 * a
                    3'b101: booth_operand = -{{PADDED_WIDTH{a_ext[PADDED_WIDTH-1]}}, a_ext};    // -1 * a
                    3'b110: booth_operand = -{{PADDED_WIDTH{a_ext[PADDED_WIDTH-1]}}, a_ext};    // -1 * a
                    3'b111: booth_operand = {2*PADDED_WIDTH{1'b0}};        // 0 * a
                    default: booth_operand = {2*PADDED_WIDTH{1'b0}};
                endcase
            end
            
            // Shift the partial product to correct position
            assign booth_pp[i] = booth_operand << (2*i);
        end
    endgenerate

    // CSA Tree for Booth Multiplier - Sequential addition
    // Start with mask + booth_pp[0] + booth_pp[1] (if exists)
    // Then sequentially add remaining Booth partial products
    // Finally add -mask at the end
    
    logic [2*PADDED_WIDTH-1:0] neg_mask_ext;
    logic [2*PADDED_WIDTH-1:0] csa_sum [BOOTH_STAGES:0];    // Sum outputs from each CSA level
    logic [2*PADDED_WIDTH-1:0] csa_carry [BOOTH_STAGES:0];  // Carry outputs from each CSA level
    logic [2*PADDED_WIDTH-1:0] ext_result;  // Extended result before truncation
    
    // Create negative mask
    assign neg_mask_ext = -mask_ext;
    
    // Handle different cases based on number of Booth stages
    generate
        if (BOOTH_STAGES == 1) begin : single_booth_stage
            // Only one Booth partial product
            // CSA: mask + booth_pp[0] + (-mask)
            csa_3to2 #(.W(2*PADDED_WIDTH)) csa_single (
                .x(mask_ext),
                .y(booth_pp[0]),
                .z(neg_mask_ext),
                .sum(csa_sum[0]),
                .carry(csa_carry[0])
            );
        end else begin : multiple_booth_stages
            // First CSA: mask + booth_pp[0] + booth_pp[1]
            csa_3to2 #(.W(2*PADDED_WIDTH)) csa_first (
                .x(mask_ext),
                .y(booth_pp[0]),
                .z(booth_pp[1]),
                .sum(csa_sum[0]),
                .carry(csa_carry[0])
            );
            
            // Generate remaining CSA levels for booth_pp[2] to booth_pp[BOOTH_STAGES-1]
            genvar j;
            for (j = 2; j < BOOTH_STAGES; j++) begin : gen_booth_csa
                csa_3to2 #(.W(2*PADDED_WIDTH)) csa_level (
                    .x(csa_sum[j-2]),
                    .y(csa_carry[j-2]),
                    .z(booth_pp[j]),
                    .sum(csa_sum[j-1]),
                    .carry(csa_carry[j-1])
                );
            end
            
            // Final CSA: add negative mask to cancel out the original mask
            csa_3to2 #(.W(2*PADDED_WIDTH)) csa_final (
                .x(csa_sum[BOOTH_STAGES-2]),
                .y(csa_carry[BOOTH_STAGES-2]),
                .z(neg_mask_ext),
                .sum(csa_sum[BOOTH_STAGES-1]),
                .carry(csa_carry[BOOTH_STAGES-1])
            );
        end
    endgenerate
    
    // Final addition and result truncation
    assign ext_result = csa_sum[BOOTH_STAGES-1] + csa_carry[BOOTH_STAGES-1];
    
    // Truncate result back to original width
    // For unsigned: take lower 2*WIDTH bits
    // For signed: take lower 2*WIDTH bits (sign extension was handled correctly)
    assign result = ext_result[2*WIDTH-1:0];

endmodule

// Carry Save Adder module
module csa_3to2 #(parameter W = 16) (
    input  logic [W-1:0] x,
    input  logic [W-1:0] y, 
    input  logic [W-1:0] z,
    output logic [W-1:0] sum,
    output logic [W-1:0] carry
);
    assign sum = x ^ y ^ z;
    assign carry = ((x & y) | (x & z) | (y & z))<<1;
endmodule

// Comprehensive Testbench for masked Booth multiplier with extensive testing
module mask_mul_tb;
    parameter WIDTH = 8;
    parameter NUM_RANDOM_TESTS = 1000;  // Number of random tests
    
    logic [WIDTH-1:0] a, b;
    logic [2*WIDTH-1:0] mask;
    logic is_signed;
    logic [2*WIDTH-1:0] result;
    logic [2*WIDTH-1:0] expected;
    
    // Test statistics
    int passed_tests = 0;
    int failed_tests = 0;
    int total_tests = 0;
    
    // Variables for Booth pattern tests
    logic [2:0] booth_patterns[8] = '{3'b000, 3'b001, 3'b010, 3'b011, 
                                      3'b100, 3'b101, 3'b110, 3'b111};
    
    // Variables for mask pattern tests
    logic [2*WIDTH-1:0] mask_patterns[16] = '{
        16'h0000, 16'hFFFF, 16'h5555, 16'hAAAA,
        16'h3333, 16'hCCCC, 16'h0F0F, 16'hF0F0,
        16'h00FF, 16'hFF00, 16'h1234, 16'hABCD,
        16'hDEAD, 16'hBEEF, 16'hCAFE, 16'hFEED
    };
    
    // Variables for fixed tests
    logic [WIDTH-1:0] fixed_a, fixed_b;
    
    // Variables for booth tests
    logic [WIDTH-1:0] booth_a, booth_b;
    
    // Variables for powers of 2 tests
    logic [WIDTH-1:0] pow2_a, pow2_b;
    logic [2*WIDTH-1:0] rand_mask_pow2;
    
    // Variables for random tests
    logic [WIDTH-1:0] rand_a, rand_b;
    logic [2*WIDTH-1:0] rand_mask;
    
    // DUT instantiation
    mask_mul #(.WIDTH(WIDTH)) dut (
        .a(a),
        .b(b), 
        .mask(mask),
        .is_signed(is_signed),
        .result(result)
    );
    
    // Task to run a single test and check result
    task automatic run_test(
        input [WIDTH-1:0] test_a,
        input [WIDTH-1:0] test_b, 
        input [2*WIDTH-1:0] test_mask,
        input test_is_signed,
        input string test_name
    );
        a = test_a;
        b = test_b;
        mask = test_mask;
        is_signed = test_is_signed;
        
        // Calculate expected result based on signed/unsigned mode
        if (test_is_signed) begin
            expected = $signed(a) * $signed(b);
        end else begin
            expected = a * b;  // Unsigned multiplication
        end
        
        #1;  // Small delay for combinational logic
        
        total_tests++;
        if (result == expected) begin
            passed_tests++;
            $display("PASS: %s (%s) - %0d * %0d = %0d (mask=0x%h)", 
                     test_name, test_is_signed ? "signed" : "unsigned", 
                     test_is_signed ? $signed(a) : a, 
                     test_is_signed ? $signed(b) : b, 
                     test_is_signed ? $signed(result) : result, mask);
        end else begin
            failed_tests++;
            $display("FAIL: %s (%s) - %0d * %0d = %0d, Expected: %0d (mask=0x%h)", 
                     test_name, test_is_signed ? "signed" : "unsigned",
                     test_is_signed ? $signed(a) : a, 
                     test_is_signed ? $signed(b) : b, 
                     test_is_signed ? $signed(result) : result, 
                     test_is_signed ? $signed(expected) : expected, mask);
        end
    endtask
    
    // Test sequence
    initial begin
        $display("=================================================================");
        $display("Comprehensive Masked Radix-4 Booth Multiplier Testbench");
        $display("Width = %0d bits, Max unsigned value = %0d", WIDTH, (1 << WIDTH) - 1);
        $display("Number of Booth stages = %0d", (WIDTH + 1) / 2);
        $display("Testing both SIGNED and UNSIGNED modes");
        $display("=================================================================");
        
        // ========== UNSIGNED MODE TESTS ==========
        $display("\n--- UNSIGNED MODE TESTS ---");
        
        // Maximum values unsigned
        run_test({WIDTH{1'b1}}, {WIDTH{1'b1}}, 16'hABCD, 1'b0, "Max * Max");
        run_test({WIDTH{1'b1}}, {WIDTH{1'b0}}, 16'h1234, 1'b0, "Max * 0");
        run_test({WIDTH{1'b0}}, {WIDTH{1'b1}}, 16'h5678, 1'b0, "0 * Max");
        
        // ========== SIGNED MODE TESTS ==========
        $display("\n--- SIGNED MODE TESTS ---");
        
        // Signed extreme values
        run_test(8'sd127, 8'sd127, 16'hABCD, 1'b1, "MaxPos * MaxPos");
        run_test(-8'sd128, -8'sd128, 16'h5678, 1'b1, "MinNeg * MinNeg");
        run_test(8'sd127, -8'sd128, 16'h9ABC, 1'b1, "MaxPos * MinNeg");
        run_test(-8'sd128, 8'sd127, 16'hBCDE, 1'b1, "MinNeg * MaxPos");
        run_test(8'sd0, 8'sd100, 16'hDEF0, 1'b1, "Zero * Positive");
        run_test(8'sd0, -8'sd50, 16'hEF01, 1'b1, "Zero * Negative");
        
        // ========== POWERS OF 2 TESTS ==========
        $display("\n--- POWERS OF 2 TESTS (Both modes) ---");
        
        // Single bit set (powers of 2) - test both unsigned and signed
        for (int i = 0; i < WIDTH-1; i++) begin  // Avoid MSB for signed to prevent negative
            for (int j = 0; j < WIDTH-1; j++) begin
                pow2_a = 1 << i;
                pow2_b = 1 << j;
                rand_mask_pow2 = $random;
                
                // Test unsigned
                run_test(pow2_a, pow2_b, rand_mask_pow2, 1'b0, $sformatf("Unsigned 2^%0d * 2^%0d", i, j));
                // Test signed  
                run_test(pow2_a, pow2_b, rand_mask_pow2, 1'b1, $sformatf("Signed 2^%0d * 2^%0d", i, j));
            end
        end
        
        // ========== BOUNDARY TESTS ==========
        $display("\n--- BOUNDARY TESTS ---");
        
        // Unsigned boundary tests
        run_test({WIDTH{1'b1}}, {WIDTH{1'b1}} - 1, 16'hDEAD, 1'b0, "Unsigned Max * (Max-1)");
        run_test({WIDTH{1'b1}} - 1, {WIDTH{1'b1}}, 16'hBEEF, 1'b0, "Unsigned (Max-1) * Max");
        run_test({WIDTH{1'b1}} - 1, {WIDTH{1'b1}} - 1, 16'hCAFE, 1'b0, "Unsigned (Max-1) * (Max-1)");
        run_test(1, {WIDTH{1'b1}}, 16'hFEED, 1'b0, "Unsigned 1 * Max");
        run_test({WIDTH{1'b1}}, 1, 16'hFACE, 1'b0, "Unsigned Max * 1");
        
        // Signed boundary tests
        run_test(8'sd127, 8'sd126, 16'hDEAD, 1'b1, "Signed MaxPos * (MaxPos-1)");
        run_test(8'sd126, 8'sd127, 16'hBEEF, 1'b1, "Signed (MaxPos-1) * MaxPos");
        run_test(-8'sd128, -8'sd127, 16'hCAFE, 1'b1, "Signed MinNeg * (MinNeg+1)");
        run_test(8'sd1, 8'sd127, 16'hFEED, 1'b1, "Signed 1 * MaxPos");
        run_test(8'sd127, 8'sd1, 16'hFACE, 1'b1, "Signed MaxPos * 1");
        
        // ========== PATTERN TESTS ==========
        $display("\n--- PATTERN TESTS ---");
        
        // Alternating bit patterns - unsigned
        run_test(8'b10101010, 8'b01010101, 16'h5A5A, 1'b0, "Unsigned 0xAA * 0x55");
        run_test(8'b01010101, 8'b10101010, 16'hA5A5, 1'b0, "Unsigned 0x55 * 0xAA");
        run_test(8'b11001100, 8'b00110011, 16'h3C3C, 1'b0, "Unsigned 0xCC * 0x33");
        
        // Same patterns - signed
        run_test(8'b01010101, 8'b01010101, 16'h5A5A, 1'b1, "Signed 0x55 * 0x55");
        run_test(8'b01010101, 8'b00110011, 16'hA5A5, 1'b1, "Signed 0x55 * 0x33");
        run_test(8'b01001100, 8'b00110011, 16'h3C3C, 1'b1, "Signed 0x4C * 0x33");
        
        // All same bits
        run_test(8'b11111111, 8'b00000000, 16'hFFFF, 1'b0, "Unsigned 0xFF * 0x00");
        run_test(8'b00000000, 8'b11111111, 16'h0000, 1'b0, "Unsigned 0x00 * 0xFF");
        run_test(8'b01111111, 8'b00000000, 16'hFFFF, 1'b1, "Signed 0x7F * 0x00");
        run_test(8'b00000000, 8'b01111111, 16'h0000, 1'b1, "Signed 0x00 * 0x7F");
        
        // ========== BOOTH ENCODING STRESS TESTS ==========
        $display("\n--- BOOTH ENCODING STRESS TESTS ---");
        
        // Test patterns that stress different Booth encodings
        for (int i = 0; i < 8; i++) begin
            for (int j = 0; j < 8; j++) begin
                // Create test values that will generate specific Booth patterns
                booth_a = $random & ((1 << (WIDTH/2)) - 1);
                
                // Construct b to have specific pattern in lower bits
                booth_b = ($random & ~((1 << 3) - 1)) | booth_patterns[i];
                
                run_test(booth_a, booth_b, $random, 1'b0, 
                         $sformatf("Unsigned Booth[%0d,%0d]=0b%b", i, j, booth_patterns[i]));
                run_test(booth_a, booth_b, $random, 1'b1, 
                         $sformatf("Signed Booth[%0d,%0d]=0b%b", i, j, booth_patterns[i]));
            end
        end
        
        // ========== MASK VARIATION TESTS ==========
        $display("\n--- MASK VARIATION TESTS ---");
        
        // Fixed multiplication with varying masks
        fixed_a = 8'd123;
        fixed_b = 8'd45;
        
        for (int i = 0; i < 16; i++) begin
            run_test(fixed_a, fixed_b, mask_patterns[i], 1'b0, 
                     $sformatf("Unsigned Mask Pattern 0x%h", mask_patterns[i]));
            run_test(fixed_a, fixed_b, mask_patterns[i], 1'b1, 
                     $sformatf("Signed Mask Pattern 0x%h", mask_patterns[i]));
        end
        
        // ========== RANDOM COMPREHENSIVE TESTS ==========
        $display("\n--- RANDOM COMPREHENSIVE TESTS (%0d tests each mode) ---", NUM_RANDOM_TESTS/2);
        
        for (int i = 0; i < NUM_RANDOM_TESTS/2; i++) begin
            rand_a = $random;
            rand_b = $random; 
            rand_mask = $random;
            
            // Test both unsigned and signed with same values
            run_test(rand_a, rand_b, rand_mask, 1'b0, $sformatf("Random Unsigned[%0d]", i));
            run_test(rand_a, rand_b, rand_mask, 1'b1, $sformatf("Random Signed[%0d]", i));
            
            // Progress indicator every 50 tests
            if ((i + 1) % 50 == 0) begin
                $display("  Progress: %0d/%0d random test pairs completed", i+1, NUM_RANDOM_TESTS/2);
            end
        end
        
        // ========== CORNER CASE TESTS ==========
        $display("\n--- CORNER CASE TESTS ---");
        
        // Test cases that might cause overflow in intermediate calculations
        run_test({WIDTH{1'b1}}, {WIDTH{1'b1}}, {2*WIDTH{1'b1}}, 1'b0, "Unsigned max values with max mask");
        run_test({WIDTH{1'b1}}, {WIDTH{1'b1}}, 0, 1'b0, "Unsigned max values with zero mask");
        run_test(8'sd127, 8'sd127, {2*WIDTH{1'b1}}, 1'b1, "Signed max values with max mask");
        run_test(8'sd127, 8'sd127, 0, 1'b1, "Signed max values with zero mask");
        
        // Sequential patterns
        for (int i = 0; i < WIDTH/2; i++) begin  // Limit to avoid overflow in signed
            run_test(i, (WIDTH/2-1-i), (i << 8) | (WIDTH/2-1-i), 1'b0, 
                     $sformatf("Unsigned Sequential[%0d]", i));
            run_test(i, (WIDTH/2-1-i), (i << 8) | (WIDTH/2-1-i), 1'b1, 
                     $sformatf("Signed Sequential[%0d]", i));
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

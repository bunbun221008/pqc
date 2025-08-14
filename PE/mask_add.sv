
module mask_add 
#(
    parameter int N = 32
)(
    input logic [N-1:0] a,
    input logic [N-1:0] b,
    input logic [N-1:0] mask,
    output logic [N-1:0] sum
);
    // carry save adder that do mask + a + b - mask
    logic [1:0][N-1:0] carry, sum_temp;

    assign carry[0] = ((mask & a) | (a & b) | (b & mask))<<1;
    assign sum_temp[0] = mask ^ a ^ b;
 
    assign carry[1] = ((carry[0] & sum_temp[0]) | (carry[0] & (-mask)) | (sum_temp[0] & (-mask)))<<1;
    assign sum_temp[1] = carry[0] ^ sum_temp[0] ^ (-mask);

    assign sum = carry[1] + sum_temp[1];

endmodule

// Testbench for masked adder
module mask_add_tb;
    parameter N = 32;
    
    logic [N-1:0] a, b, mask;
    logic [N-1:0] sum;
    logic [N-1:0] expected;
    
    // DUT instantiation
    mask_add #(.N(N)) dut (
        .a(a),
        .b(b),
        .mask(mask),
        .sum(sum)
    );
    
    // Test sequence
    initial begin
        $display("Starting mask_add testbench...");
        $display("Testing N=%0d bit masked adder", N);
        $display("Operation: mask + a + b - mask = a + b");
        $display("===========================================");
        
        // Test case 1: Simple addition
        a = 32'd15;
        b = 32'd25;
        mask = 32'h12345678;
        expected = a + b;
        #10;
        $display("Test 1: %0d + %0d = %0d (Expected: %0d) %s", 
                 a, b, sum, expected, (sum == expected) ? "PASS" : "FAIL");
        
        // Test case 2: Zero addition
        a = 32'd0;
        b = 32'd0;
        mask = 32'hFFFFFFFF;
        expected = a + b;
        #10;
        $display("Test 2: %0d + %0d = %0d (Expected: %0d) %s", 
                 a, b, sum, expected, (sum == expected) ? "PASS" : "FAIL");
        
        // Test case 3: One operand is zero
        a = 32'd100;
        b = 32'd0;
        mask = 32'hAAAAAAAA;
        expected = a + b;
        #10;
        $display("Test 3: %0d + %0d = %0d (Expected: %0d) %s", 
                 a, b, sum, expected, (sum == expected) ? "PASS" : "FAIL");
        
        // Test case 4: Large numbers
        a = 32'hFFFFFFFF;
        b = 32'd1;
        mask = 32'h55555555;
        expected = a + b;  // This will overflow to 0
        #10;
        $display("Test 4: 0x%h + %0d = 0x%h (Expected: 0x%h) %s", 
                 a, b, sum, expected, (sum == expected) ? "PASS" : "FAIL");
        
        // Test case 5: Random values
        a = 32'h12345678;
        b = 32'h87654321;
        mask = 32'hDEADBEEF;
        expected = a + b;
        #10;
        $display("Test 5: 0x%h + 0x%h = 0x%h (Expected: 0x%h) %s", 
                 a, b, sum, expected, (sum == expected) ? "PASS" : "FAIL");
        
        // Test case 6: Mask = 0 (should still work)
        a = 32'd123;
        b = 32'd456;
        mask = 32'd0;
        expected = a + b;
        #10;
        $display("Test 6: %0d + %0d = %0d (Expected: %0d, mask=0) %s", 
                 a, b, sum, expected, (sum == expected) ? "PASS" : "FAIL");
        
        // Test case 7: Maximum values
        a = 32'hFFFFFFFF;
        b = 32'hFFFFFFFF;
        mask = 32'h80000000;
        expected = a + b;  // This will overflow
        #10;
        $display("Test 7: 0x%h + 0x%h = 0x%h (Expected: 0x%h) %s", 
                 a, b, sum, expected, (sum == expected) ? "PASS" : "FAIL");
        
        $display("===========================================");
        $display("Testbench completed!");
        $finish;
    end

    initial begin
        // fsdb dump
        $fsdbDumpfile("mask_add.fsdb");
        $fsdbDumpvars(0, dut, "+mda");
    end
    
endmodule
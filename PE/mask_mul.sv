// Masked Multiplier using Carry Save Adder Tree
// This multiplier performs a*b with masking protection during computation
// The mask is added to the first partial product and subtracted from the final result
// All computation is done combinationally in a single cycle

module mask_mul #(
    parameter WIDTH = 8  // Width of input operands
)(
    input  logic [WIDTH-1:0] a,      // First operand
    input  logic [WIDTH-1:0] b,      // Second operand
    input  logic [2*WIDTH-1:0] mask, // Mask for protection
    output logic [2*WIDTH-1:0] result // Final result
);

    

    // Generate partial products
    logic [2*WIDTH-1:0] partial_products [WIDTH-1:0];
    logic [2*WIDTH-1:0] masked_pp [WIDTH-1:0];
    
    // Generate all partial products
    genvar i;
    generate
        for (i = 0; i < WIDTH; i++) begin : gen_pp
            assign partial_products[i] = b[i] ? ({{WIDTH{1'b0}}, a} << i) : {2*WIDTH{1'b0}};
        end
    endgenerate
    
    // Keep all partial products as original (no modification)
    always_comb begin
        for (int j = 0; j < WIDTH; j++) begin
            masked_pp[j] = partial_products[j];      // Keep all partial products as is
        end
    end

    // Simple CSA Tree - Sequential addition of partial products
    // Start with mask + partial_products[0] + partial_products[1]
    // Then sequentially add remaining partial products using CSA
    // Finally add -mask at the end
    
    logic [2*WIDTH-1:0] neg_mask;
    logic [2*WIDTH-1:0] csa_sum [WIDTH:0];    // Sum outputs from each CSA level
    logic [2*WIDTH-1:0] csa_carry [WIDTH:0];  // Carry outputs from each CSA level
    
    // Create negative mask
    assign neg_mask = -mask;
    
    // First CSA: mask + partial_products[0] + partial_products[1]
    csa_3to2 #(.W(2*WIDTH)) csa_first (
        .x(mask),
        .y(masked_pp[0]),
        .z(masked_pp[1]),
        .sum(csa_sum[0]),
        .carry(csa_carry[0])
    );
    
    // Generate remaining CSA levels for partial_products[2] to partial_products[WIDTH-1]
    genvar i;
    generate
        for (i = 2; i < WIDTH; i++) begin : gen_csa
            csa_3to2 #(.W(2*WIDTH)) csa_level (
                .x(csa_sum[i-2]),
                .y(csa_carry[i-2]),
                .z(masked_pp[i]),
                .sum(csa_sum[i-1]),
                .carry(csa_carry[i-1])
            );
        end
    endgenerate
    
    // Final CSA: add negative mask to cancel out the original mask
    csa_3to2 #(.W(2*WIDTH)) csa_final (
        .x(csa_sum[WIDTH-2]),
        .y(csa_carry[WIDTH-2]),
        .z(neg_mask),
        .sum(csa_sum[WIDTH-1]),
        .carry(csa_carry[WIDTH-1])
    );
    
    // Final addition
    assign result = csa_sum[WIDTH-1] + csa_carry[WIDTH-1];

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

// Testbench for masked multiplier
module mask_mul_tb;
    parameter WIDTH = 8;
    
    logic [WIDTH-1:0] a, b;
    logic [2*WIDTH-1:0] mask;
    logic [2*WIDTH-1:0] result;
    
    // DUT instantiation
    mask_mul #(.WIDTH(WIDTH)) dut (
        .a(a),
        .b(b), 
        .mask(mask),
        .result(result)
    );
    
    // Test sequence
    initial begin
        // Test case 1: Simple multiplication
        a = 8'd15;
        b = 8'd17; 
        mask = 16'h1234;
        #10;
        $display("Test 1: %d * %d = %d (Expected: %d)", a, b, result, a*b);
        
        // Test case 2: Another multiplication
        a = 8'd255;
        b = 8'd255;
        mask = 16'hABCD;
        #10;
        $display("Test 2: %d * %d = %d (Expected: %d)", a, b, result, a*b);
        
        // Test case 3: Zero multiplication
        a = 8'd0;
        b = 8'd100;
        mask = 16'h5555;
        #10;
        $display("Test 3: %d * %d = %d (Expected: %d)", a, b, result, a*b);
        
        // Test case 4: One operand is 1
        a = 8'd1;
        b = 8'd123;
        mask = 16'hFFFF;
        #10;
        $display("Test 4: %d * %d = %d (Expected: %d)", a, b, result, a*b);
        
        $finish;
    end
    
endmodule

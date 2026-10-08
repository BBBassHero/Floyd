`include "parameters.vh"

module reset_sync (
    input  wire clk,
    input  wire rst_n_in,   // 异步复位输入，低有效
    output wire rst_n_out   // 同步复位输出，低有效
);

    reg rst_n_meta;
    reg rst_n_sync;

    always @(posedge clk or negedge rst_n_in) begin
        if (!rst_n_in) begin
            rst_n_meta <= 1'b0;
            rst_n_sync <= 1'b0;
        end else begin
            rst_n_meta <= 1'b1;
            rst_n_sync <= rst_n_meta;
        end
    end

    assign rst_n_out = rst_n_sync;

endmodule
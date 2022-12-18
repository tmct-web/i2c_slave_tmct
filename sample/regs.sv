//=============================================================================
//	i2c_slave_tmct
//-----------------------------------------------------------------------------
//  regs.sv
//  Asynchronous sram-like register module
//-----------------------------------------------------------------------------
//  © 2022 tmct-web  https://ss1.xrea.com/tmct.s1009.xrea.com/
//
//  Redistribution and use in source and binary forms, with or without modification, 
//  are permitted provided that the following conditions are met:
//
//  1.  Redistributions of source code must retain the above copyright notice, 
//      this list of conditions and the following disclaimer.
//
//  2.  Redistributions in binary form must reproduce the above copyright notice, 
//      this list of conditions and the following disclaimer in the documentation and/or 
//      other materials provided with the distribution.
//
//  3.  Neither the name of the copyright holder nor the names of 
//      its contributors may be used to endorse or promote products derived from 
//      this software without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
//  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, 
//  THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE 
//  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR 
//  ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) 
//  HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, 
//  OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF 
//  THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//=============================================================================
module regs
(
    input   logic           i_clk,
    input   logic           i_reset,
    //input   logic           i_bus_cs,
    input   logic           i_bus_wr,
    input   logic   [7:0]   i_bus_addr,
    input   logic   [7:0]   i_bus_mosi,
    output  logic   [7:0]   o_bus_miso
);

    logic   [7:0]   reg0;
    logic   [7:0]   reg1;
    logic   [7:0]   reg2;


    //-------------------------------------------------------------------------
    //  Read operation
    //-------------------------------------------------------------------------
    always_comb
    begin
        if (i_reset)
        begin
            o_bus_miso = 8'h0;
        end
        else
        begin
            //if (i_bus_cs)
            //begin
                case (i_bus_addr)
                    8'h00:      o_bus_miso = reg0;
                    8'h01:      o_bus_miso = reg1;
                    8'h02:      o_bus_miso = reg2;
                    8'h03:      o_bus_miso = 8'h3c;
                    default:    o_bus_miso = 8'h0;
                endcase
            //end
            //else
            //begin
            //    o_bus_miso = 8'h0;
            //end
        end
    end


    //-------------------------------------------------------------------------
    //  Write operation
    //-------------------------------------------------------------------------
    always_ff @(posedge i_clk, posedge i_reset)
    begin
        if (i_reset)
        begin
            reg0 <= 8'h0;
            reg1 <= 8'h55;
            reg2 <= 8'haa;
        end
        else
        begin
            //if (i_bus_wr & i_bus_cs)
            if (i_bus_wr)
            begin
                case (i_bus_addr)
                    8'h00:      reg0 <= i_bus_mosi;
                    8'h01:      reg1 <= i_bus_mosi;
                    8'h02:      reg2 <= i_bus_mosi;
                    default:    ;
                endcase
            end
        end
    end

endmodule
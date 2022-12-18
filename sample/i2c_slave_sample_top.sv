//=============================================================================
//	I2C slave sample implementation
//-----------------------------------------------------------------------------
//  i2c_slave_sample_top.sv
//  I2C slave sample implementation
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
module i2c_slave_sample
(
    input   logic       I_CLK,
    input   logic       I_RESET_N,
    input   logic       I_SCL,
    inout   wire        B_SDA

);

    logic           i_reset;
    logic           i_clk;

    logic           bus_cs;
    logic           bus_wr;
    logic   [7:0]   bus_addr;
    logic   [7:0]   bus_odata;
    logic   [7:0]   bus_idata;

    always_comb i_clk = I_CLK;
    always_comb i_reset = ~I_RESET_N;


    //-------------------------------------------------------------------------
    //  I2C Slave
    //-------------------------------------------------------------------------
    i2c_slave_tmct #
    (
        // Set the slave address
        .DEVICE_ID  (7'h09)
    )
    m_i2c_slave_tmct
    (
        .i_clk      (i_clk),
        .i_reset    (i_reset),
        .i_scl      (I_SCL),
        .b_sda      (B_SDA),
        .o_bus_cs   (bus_cs),
        .o_bus_wr   (bus_wr),
        .o_bus_addr (bus_addr),
        .i_bus_data (bus_odata),
        .o_bus_data (bus_idata)
    );


    //-------------------------------------------------------------------------
    //  Register
    //-------------------------------------------------------------------------
    regs m_regs
    (
        .i_clk      (i_clk),
        .i_reset    (i_reset),
        //.i_bus_cs   (bus_cs),
        .i_bus_wr   (bus_wr),
        .i_bus_addr (bus_addr),
        .i_bus_mosi (bus_idata),
        .o_bus_miso (bus_odata)
    );


endmodule
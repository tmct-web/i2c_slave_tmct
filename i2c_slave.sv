//=============================================================================
//	i2c_slave_tmct
//-----------------------------------------------------------------------------
//  i2c_slave.sv
//  I2C to Slave local-bus
//
//  This module converts accesses from an I2C bus master device to 
//  an internal bus system (asynchronous sram-like).
//  This module functions as a slave device for i2c devices and 
//  as a bus master for the internal bus.
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
//-----------------------------------------------------------------------------
//  This module is a port of 'huhuikevin/i2c_slave' to SystemVeriog with 
//  some signal specification changes.
//  Thank you for making such a useful core module available free of charge.
//  https://github.com/huhuikevin/i2c_slave
//=============================================================================
module i2c_slave_tmct
#(
    parameter DEVICE_ID = 7'b0001_000   // Default value of slave device address
)
(
    input   logic       i_scl,          // SCL to I2C bus
    inout   logic       b_sda,          // SDA to I2C bus
    input   logic       i_reset,        // Reset input (Active high)
    input   logic       i_clk,          // Master clock
    output  logic       o_bus_cs,       // Chip select output to internal bus
    output  logic       o_bus_wr,       // Write valid pulse to internal bus (1 i_clk cycle)
    output  logic [7:0] o_bus_addr,     // Address output to internal bus
    input   logic [7:0] i_bus_data,     // Data input from internal bus (So called Master-In-Slave-Out)
    output  logic [7:0] o_bus_data      // Data output to internal bus (So caled Master-Out-Slave-In)
);

    localparam BITS_NR  = 4'h8;
    localparam NACK     = 1'b1;
    localparam ACK      = 1'b0;

    typedef enum logic [3:0]
    {
        IDLE            = 4'h0,
        START           = 4'h1,
        DEVICE_ADDR     = 4'h2,
        ACK_ADDRESS     = 4'h3,
        REG_ADDR        = 4'h4,
        ACK_REGADDR     = 4'h5,
        REG_DATA        = 4'h6,
        REG_WR_DATA     = 4'h7,
        REG_RD_DATA     = 4'h8,
        ACK_REG_WRITE   = 4'h9,
        MASTER_ACK      = 4'ha,
        RESET_IDLE      = 4'hf
    } i2c_state_enum;

    i2c_state_enum i2c_state;

    typedef enum logic [1:0]
    {
        RECVING     = 2'h0,
        SENDING     = 2'h1,
        SENDDATA    = 2'h2,
        SENDWAIT    = 2'h3
    } sda_state_enum;

    sda_state_enum sda_state;

    logic   [7:0]   scl_reg;
    logic   [7:0]   sda_reg;

    logic           i2c_start;
    logic           i2c_stop;

    logic           indat_done;
    logic   [3:0]   bits_cnt;
    logic   [7:0]   in_data;

    logic           device_addr_match;
    logic           device_write;
    logic           device_read;

    logic           sda_out_en;
    logic           sda_out;
    logic           send_done;
    logic           sram_cs_doing;
    logic   [2:0]   out_bit;

    logic   [7:0]   reg_address;    // Register address which is to be read or write

    always_comb o_bus_addr = reg_address[7:0];
    always_comb b_sda = sda_out_en ? (sda_out ? 1'bz : 1'b0) : 1'bz;


    //-------------------------------------------------------------------------
    //  Latch scl and sda to detect the start and stop condition
    //-------------------------------------------------------------------------
    always_ff @(posedge i_clk, posedge i_reset)
    begin
        if (i_reset)
        begin
            scl_reg <= 8'b00000000;
            sda_reg <= 8'b00000000;
        end
        else
        begin
            scl_reg <= {scl_reg[6:0], i_scl};
            sda_reg <= {sda_reg[6:0], b_sda};
        end
    end

    //-------------------------------------------------------------------------
    //  Detect start condition
    //-------------------------------------------------------------------------
    always_ff @(posedge i_clk, posedge i_reset)
    begin
        if (i_reset)
        begin
            i2c_start <= 1'b0;
        end
        else
        begin
            if (sda_reg == 8'b11110000 && scl_reg == 8'b11111111)
            begin
                i2c_start <= 1'b1;
            end
            else
            begin
                i2c_start <= 1'b0;
            end
        end
    end


    //-------------------------------------------------------------------------
    //  Detect stop condition
    //-------------------------------------------------------------------------
    always_ff @(posedge i_clk, posedge i_reset)
    begin
        if (i_reset)
        begin
            i2c_stop <= 1'b0;
        end
        else
        begin
            if (sda_reg == 8'b00001111 && scl_reg == 8'b11111111)
            begin
                i2c_stop <= 1'b1;
            end
            else
            begin
                i2c_stop <= 1'b0;
            end
        end
    end


    //-------------------------------------------------------------------------
    //  Main state machine
    //-------------------------------------------------------------------------
    always_ff @(posedge i_clk, posedge i_reset)
    begin
        if (i_reset)
        begin
            i2c_state <= IDLE;
        end
        else
        begin			
            case (i2c_state)
            IDLE:
            begin
                if (i2c_start) i2c_state <= START; else i2c_state <= IDLE;
            end
            
            START:
            begin
                i2c_state <= DEVICE_ADDR;
            end
            
            DEVICE_ADDR:
            begin
                if (indat_done) i2c_state <= ACK_ADDRESS; else i2c_state <= DEVICE_ADDR;
            end
            
            ACK_ADDRESS:
            begin
                if (send_done)
                begin
                    if (device_addr_match)
                    begin
                        if      (device_write) i2c_state <= REG_ADDR;
                        else if (device_read)  i2c_state <= REG_RD_DATA;
                    end
                    else
                    begin
                        //nack return to idle
                        i2c_state <= IDLE;
                    end
                end
                else
                begin
                    i2c_state <= ACK_ADDRESS;
                end
            end
            
            REG_ADDR:
            begin
                if (indat_done) i2c_state <= ACK_REGADDR; else i2c_state <= REG_ADDR;
            end
            
            ACK_REGADDR:
            begin
                if (send_done)
                begin
                    if      (device_write)  i2c_state <= REG_WR_DATA;
                    else if (device_read)   i2c_state <= REG_RD_DATA;
                    else                    i2c_state <= IDLE;
                end
                else
                begin
                    i2c_state <= ACK_REGADDR;
                end
            end
            
            REG_WR_DATA:
            begin
                if (indat_done) i2c_state <= ACK_REG_WRITE; else i2c_state <= REG_WR_DATA;
                if      (i2c_stop)      i2c_state <= IDLE;
                else if (i2c_start)     i2c_state <= START;
            end
            
            REG_RD_DATA:
            begin
                if (send_done)
                begin
                    i2c_state <= MASTER_ACK;
                end
                else
                begin
                    i2c_state <= REG_RD_DATA;
                end			
            end
            
            ACK_REG_WRITE:
            begin
                if (send_done) i2c_state <= REG_WR_DATA; else i2c_state <= ACK_REG_WRITE;
                if      (i2c_stop)  i2c_state <= IDLE;
                else if (i2c_start) i2c_state <= START;
            end
            
            MASTER_ACK:
            begin
                if (indat_done)
                begin
                    if (!in_data[0])
                    begin
                        //ack
                        i2c_state <= REG_RD_DATA;
                    end
                    else
                    begin
                        i2c_state <= IDLE;
                    end
                end
                else i2c_state <= MASTER_ACK;
            end

            default:
            begin
                i2c_state <= IDLE;
            end
            
            endcase		
        end
    end

    always_ff @(posedge i_clk, posedge i_reset)
    begin
        if (i_reset)
        begin
            indat_done <= 1'b0;
            bits_cnt <= 4'b0000;
            in_data <= 8'h0;
        end
        else
        begin
            if (scl_reg == 8'b01111111)
            begin
                if (i2c_state == DEVICE_ADDR || i2c_state == REG_ADDR || i2c_state == REG_WR_DATA)
                begin			
                    in_data <= {in_data[6:0], b_sda};
                    bits_cnt = bits_cnt + 1'b1;
                
                    if (bits_cnt == 4'h8)
                    begin
                        indat_done <= 1'b1;
                        bits_cnt <= 4'h0;
                    end
                    else indat_done <= 1'b0;
                end
                else if (i2c_state == MASTER_ACK)
                begin
                    in_data[0] <= b_sda;
                    indat_done <= 1'b1;
                    bits_cnt <= 4'h0;
                end
            end
            if (i2c_state == IDLE || i2c_state == START || i2c_state == REG_RD_DATA 
                    || i2c_state == ACK_ADDRESS || i2c_state == ACK_REGADDR || i2c_state == ACK_REG_WRITE)
            begin 
                bits_cnt <= 4'h0;
                indat_done <= 1'b0;		
            end
        end
    end


    //-------------------------------------------------------------------------
    //  Process read/write address
    //-------------------------------------------------------------------------
    always_ff @(posedge i_clk, posedge i_reset)
    begin
        if (i_reset)
        begin
            reg_address <= 8'h0;
        end
        else
        begin
            if      (i2c_state == REG_WR_DATA && indat_done)    o_bus_data <= in_data;
            else if (i2c_state == REG_ADDR && indat_done)       reg_address <= in_data;
            else if (i2c_state == ACK_REG_WRITE && send_done)   reg_address <= reg_address + 1'h1;
            else if (i2c_state == MASTER_ACK && indat_done)     reg_address <= reg_address + 1'h1;
        end
    end


    //-------------------------------------------------------------------------
    //  Process Bus cs, wr
    //-------------------------------------------------------------------------
    always_ff @(posedge i_clk, posedge i_reset)
    begin
        if (i_reset)
        begin
            o_bus_cs <= 1'b0;
            o_bus_wr <= 1'b0;
            sram_cs_doing <= 1'b0;
        end
        else
        begin
            if((i2c_state == ACK_REG_WRITE))
            begin
                if (!sram_cs_doing) 
                begin
                    o_bus_cs <= 1'b1;   // Bus enable
                    o_bus_wr <= 1'b1;   // Bus write
                    sram_cs_doing <= 1'b1;
                end
                else
                begin
                    o_bus_cs <= 1'b0;
                    o_bus_wr <= 1'b0;
                end
            end
            else if((i2c_state == REG_RD_DATA))
            begin
                o_bus_cs <= 1'b1;   // Bus enable
                o_bus_wr <= 1'b0;   // Bus read
            end
            else
            begin
                o_bus_cs <= 1'b0;   // Bus disable
                o_bus_wr <= 1'b0;
                sram_cs_doing <= 1'b0;
            end
        end
    end


    //-------------------------------------------------------------------------
    //  Check the device id and write or read
    //-------------------------------------------------------------------------
    always_ff @(posedge i_clk, posedge i_reset)
    begin
        if (i_reset)
        begin
            device_addr_match <= 1'b0;
            device_write <= 1'b0;
            device_read  <= 1'b0;
        end
        else
        begin
            if (i2c_state == DEVICE_ADDR && indat_done)
            begin
                if (in_data[7:1] == DEVICE_ID)
                begin
                    device_addr_match <= 1'b1;
                    device_write <= ~in_data[0];
                    device_read  <= in_data[0];				
                end
            end
            else if (i2c_state == IDLE || i2c_state == START)
            begin
                device_addr_match <= 1'b0;
                device_write <= 1'b0;
                device_read  <= 1'b0;			
            end
        end
    end


    //-------------------------------------------------------------------------
    //  Sda line state machine
    //  data out include ack, nack read data
    //-------------------------------------------------------------------------
    always_ff @(posedge i_clk, posedge i_reset)
    begin
        if (i_reset)
        begin
            sda_out_en <= 1'b0;
            sda_out <= 1'b0;
            out_bit <= 3'h7;
            send_done <= 1'b0;
            sda_state <= RECVING;
        end
        else
        begin
            case (sda_state)
            RECVING:
            begin
                if (!send_done &&(i2c_state == ACK_ADDRESS || i2c_state == ACK_REGADDR 
                        || i2c_state == ACK_REG_WRITE || i2c_state == REG_RD_DATA)) sda_state <= SENDING; else sda_state <= RECVING;
                send_done <= 1'b0;
                out_bit <= 3'h7;
            end
            
            SENDING:
            begin
                if (i2c_state == ACK_ADDRESS && scl_reg == 8'b11111110)
                begin
                    if(device_addr_match) sda_out <= ACK; else sda_out <= NACK;
                    sda_out_en <= 1'b1;
                    sda_state <= SENDWAIT;
                end
                else if (i2c_state == REG_RD_DATA && scl_reg == 8'b11000000)
                begin
                    sda_out <= i_bus_data[out_bit];
                    out_bit <= out_bit - 1'h1;
                    sda_out_en <= 1'b1;			
                    sda_state<=SENDDATA;
                end
                else if ((i2c_state == ACK_REGADDR || i2c_state == ACK_REG_WRITE) && (scl_reg == 8'b11111110))
                begin
                    sda_out <= ACK;
                    sda_out_en <= 1'b1;
                    sda_state <= SENDWAIT;
                end else sda_state<=SENDING;
                send_done <= 1'b0;
            end

            SENDWAIT:
            begin
                if (scl_reg == 8'b11111110)
                begin
                    sda_out_en <= 1'b0;
                    send_done <= 1'b1;
                    sda_state<= RECVING;
                end
                else
                begin
                    sda_out_en <= 1'b1;
                    sda_state <= SENDWAIT;
                    send_done <= 1'b0;
                end
            end
            
            SENDDATA:
            begin
                sda_out_en <= 1'b1;
                send_done <= 1'b0;
                if (scl_reg == 8'b11111110)
                begin
                    sda_out <= i_bus_data[out_bit];
                    if (out_bit == 3'h0)
                    begin
                        // Wait last bit to send
                        sda_state <= SENDWAIT;
                    end
                    else
                    begin
                        out_bit <= out_bit - 1'h1;	
                        sda_state<=SENDDATA;	
                    end
                end else sda_state<=SENDDATA;
            end
            default: sda_state <= RECVING;
            endcase
        end
    end

endmodule
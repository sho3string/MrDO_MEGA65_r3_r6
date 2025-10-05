// -----------------------------------------------------------------------------
// MiSTer2MEGA65 Framework
//
// Wrapper for the MiSTer core that runs exclusively in the core's clock domain
//
// Converted from VHDL to Verilog
//
// ----------------------------------------------------------------------------- 

module main #(
    parameter G_VDNUM = 1
)(
    input  wire        clk_main_i,
    input  wire        reset_soft_i,
    input  wire        reset_hard_i,
    input  wire        rom_download, 
    input  wire        pause_i,
    output wire        dim_video_o,

    input  wire [31:0] clk_main_speed_i,

    // Video
    input  wire        clk_sys_i,
    output reg         video_ce_o,
    output wire        video_ce_ovl_o,
    output wire [3:0]  video_red_o,
    output wire [3:0]  video_green_o,
    output wire [3:0]  video_blue_o,
    output reg         video_vs_o,
    output reg         video_hs_o,
    output reg         video_hblank_o,
    output reg         video_vblank_o,

    // Audio (signed PCM)
    output [15:0] audio_left_o,
    output [15:0] audio_right_o,

    // Keyboard
    input  wire [6:0]  kb_key_num_i,
    input  wire        kb_key_pressed_n_i,

    // Joysticks
    input  wire joy_1_up_n_i,
    input  wire joy_1_down_n_i,
    input  wire joy_1_left_n_i,
    input  wire joy_1_right_n_i,
    input  wire joy_1_fire_n_i,

    input  wire joy_2_up_n_i,
    input  wire joy_2_down_n_i,
    input  wire joy_2_left_n_i,
    input  wire joy_2_right_n_i,
    input  wire joy_2_fire_n_i,

    input  wire [7:0]  pot1_x_i,
    input  wire [7:0]  pot1_y_i,
    input  wire [7:0]  pot2_x_i,
    input  wire [7:0]  pot2_y_i,

    // Dips
    input  wire [7:0]  dsw_a_i,
    input  wire [7:0]  dsw_b_i,

    // Downloader
    input  wire        dn_clk_i,
    input  wire [24:0] dn_addr_i,
    input  wire [7:0]  dn_data_i,
    input  wire        dn_wr_i,

    input  wire [255:0] osm_control_i
);

    // Menu constants
    localparam C_MENU_OSMPAUSE = 2;
    localparam C_MENU_OSMDIM   = 3;
    localparam C_MENU_FLIP     = 9;

    // Keyboard mappings
    localparam m65_1        = 56;
    localparam m65_2        = 59;
    localparam m65_5        = 16;
    localparam m65_6        = 19;
    localparam m65_a        = 10;
    localparam m65_d        = 18;
    localparam m65_up_crsr  = 73;
    localparam m65_p        = 41;
    localparam m65_s        = 13;
    localparam m65_capslock = 72;
    localparam m65_help     = 67;

    // Internal signals
    wire [79:0] keyboard_n;
    wire        pause_cpu;
    reg  [31:0] status;
    wire        flip_screen;
    wire        video_rotated;
    wire        rotate_ccw;
    wire        direct_video;
    wire        forced_scandoubler;
    wire [21:0] gamma_bus;
    
    wire [7:0] sound1_out;
    wire [7:0] sound2_out;
    wire [8:0] sound_mix = sound1_out + sound2_out;
    
    wire [7:0] sound_avg = sound_mix[8:1];  // Divide by 2
    wire signed [8:0] sound_signed = {1'b0, sound_avg} - 9'd128;

    reg sound1_wr;
    reg sound1_en ;

    reg sound2_wr;
    reg sound2_en ;

    // Mr. Do is not stereo.  Sound should be added together and /2. 
    assign audio_left_o  = {sound_signed[7:0], sound_signed[7:0]};
    assign audio_right_o = {sound_signed[7:0], sound_signed[7:0]};
    
    wire [1:0]  buttons;
    wire        reset = reset_hard_i | reset_soft_i | rom_download;

    wire [15:0] hs_address;
    wire [7:0]  hs_data_in;
    wire [7:0]  hs_data_out;
    wire        hs_write_enable;

    wire        hs_pause;
    wire [1:0]  options;
    reg         self_test;
    
      // OSM controls
    assign options[0] = osm_control_i[C_MENU_OSMPAUSE];
    assign options[1] = osm_control_i[C_MENU_OSMDIM];
    assign flip_screen = osm_control_i[C_MENU_FLIP];
    
    
    reg  clk_5M,clk_10M,clk_4M,clk_8M;
    
    reg [5:0] clk10_count;
    reg [5:0] clk5_count;
    reg [5:0] clk8_count;
    reg [5:0] clk4_count;

    always @ (posedge clk_main_i) begin
    if ( reset == 1 ) begin
            clk10_count <= 0;
            clk5_count <= 0;
            clk4_count <= 0;
            
        end else begin
            if ( clk10_count == 4 ) begin
                clk10_count <= 0;
                clk_10M <= ~ clk_10M ;
            end else begin
                clk10_count <= clk10_count + 1;
            end
    
            if ( clk8_count == 5 ) begin
                clk8_count <= 0;
                clk_8M <= ~ clk_8M ;
            end else begin
                clk8_count <= clk8_count + 1;
            end
    
            if ( clk5_count == 9 ) begin
                clk5_count <= 0;
                clk_5M <= ~ clk_5M ;
            end else begin
                clk5_count <= clk5_count + 1;
            end
    
            if ( clk4_count == 11 ) begin
                clk4_count <= 0;
                clk_4M <= ~ clk_4M ;
            end else begin
                clk4_count <= clk4_count + 1;
            end
        end
    end

    wire b_up      = ~joy_1_up_n_i;
    wire b_down    = ~joy_1_down_n_i;
    wire b_left    = ~joy_1_left_n_i;
    wire b_right   = ~joy_1_right_n_i;
    wire b_fire    = ~joy_1_fire_n_i;
   
    wire b_up_2    = ~joy_2_up_n_i;
    wire b_down_2  = ~joy_2_down_n_i;
    wire b_left_2  = ~joy_2_left_n_i;
    wire b_right_2 = ~joy_2_right_n_i;
    wire b_fire_2  = ~joy_2_fire_n_i;
    
    wire b_start1  = ~keyboard_n[m65_1];
    wire b_start2  = ~keyboard_n[m65_2];
    wire b_coin    = ~keyboard_n[m65_5];
    
    // PAUSE SYSTEM
    wire		    pause_cpu;
    wire [11:0]		rgb_out;
    
    pause #(4,4,4,48) pause (
        .clk_sys(clk_sys_i),
        .reset(reset),
        .r(rgb_comp[11:8]),
        .g(rgb_comp[7:4]),
        .b(rgb_comp[3:0]),
        .user_button(~keyboard_n[m65_p]),
        .pause_request(hs_pause),
        .pause_cpu(pause_cpu),
        .dim_video(dim_video_o),
        .options(options),
        .OSD_STATUS(0),
        .rgb_out({video_red_o,video_green_o,video_blue_o})
    );

    reg [7:0] p1 ;
    reg [7:0] p2;
    reg [7:0] dsw1 ;
    reg [7:0] dsw2 ;
    reg user_flip;
    
    always @ (posedge clk_4M ) begin
        p1 <= ~{ 1'b0, b_start2, b_start1, b_fire, b_up, b_right, b_down, b_left };
        p2 <= ~{ b_coin, 1'b0, 1'b0, b_fire_2, b_up_2, b_right_2, b_down_2, b_left_2 };
        
        dsw1 <= ~dsw_a_i;
        dsw2 <= ~dsw_b_i;
       
        user_flip <= flip_screen;
    end
    
    reg [11:0] rgb_comp;
    
    wire hbl;
    wire vbl;
    wire hx;
    wire hff;
    
    wire hbl_hx;
    assign hbl_hx = hbl | hx;
    
    wire [7:0] h;
    wire [7:0] v;
    
    wire rotate_ccw = 1;
    wire flip = 0;
    wire video_rotated;
    
    video_timing video_timing (
    .clk(~clk_5M),   // pixel clock
    .reset(reset),     // reset

    .hs_offset(hs_offset),

    .h(h),  // { hd', hc', hb', ha', hd, hc, hb, ha }  
    .v(v),  // { vd', vc', vb', va', vd, vc, vb, va }  

    .hbl(hbl),
//    output      hbl_n,    
    .hff(hff),
    .hx(hx),
//    output      hx_n,
    .vbl(vbl),
//    output reg  vbl_n,
//    output reg  vbls,
//    output reg  vbls_n,
    
    .hsync(hsync),     
    .vsync(vsync)   
    );
    
    reg clk_5M_d;
    always @(posedge clk_sys_i) begin
        clk_5M_d <= clk_5M;
        video_ce_o <= clk_5M & ~clk_5M_d;  // rising edge pulse
        
        video_vs_o     <= vsync;
        video_hs_o     <= hsync;
        video_hblank_o <= hbl_hx;
        video_vblank_o <= vbl;
    end
    
    
    wire [7:0] s8_data;
    wire [7:0] u8_data;
    
    wire [7:0] r8_data;
    wire [7:0] n8_data;
    
    wire [7:0] f10_data;
    reg [5:0] f10_addr;    
    
    reg [9:0]  fg_char_index ; 
    reg [9:0]  bg_char_index ; 
    
    wire [15:0] cpu_addr;
    reg  [7:0] cpu_din;
    wire [7:0] cpu_dout;
    
    wire [7:0] gfx_fg_tile_data ; 
    wire [7:0] gfx_fg_attr_data ; 
    
    wire [7:0] gfx_bg_tile_data ; 
    wire [7:0] gfx_bg_attr_data ; 
    
    reg [7:0]  wr_data;
    reg [11:0] wr_addr;
    
    reg cpu_ram_w ;
    
    reg gfx_fg_ram0_wr ;
    reg gfx_fg_ram1_wr ;
    reg gfx_bg_ram0_wr ;
    reg gfx_bg_ram1_wr ;
    
    wire [7:0] fg_ram0_data;
    wire [7:0] fg_ram1_data;
    wire [7:0] bg_ram0_data;
    wire [7:0] bg_ram1_data;
    
    wire [7:0] cpu01rom_data;
    wire [7:0] cpu02rom_data;
    wire [7:0] cpu03rom_data;
    wire [7:0] cpu04rom_data;
    wire [7:0] cpu_ram_data;
    
    // used to shift out the bitmap
    reg [7:0] fg_shift_0;
    reg [7:0] fg_shift_1;
    reg [7:0] bg_shift_0;
    reg [7:0] bg_shift_1;
    
    reg [7:0] fg_attr;
    reg [7:0] bg_attr;
    
    reg [11:0] fg_bitmap_addr;
    reg [11:0] bg_bitmap_addr;
    
    // fg ----------
    //
    wire [1:0] fg = { fg_shift_1[0], fg_shift_0[0] };
    //
    reg [1:0] fg_reg;
    
    reg [7:0] fg_attr_reg;
    
    reg [7:0] fg_red ;
    reg [7:0] fg_green ;
    reg [7:0] fg_blue ;
    
    // values the same for each channel. put this into a module
    always @ ( posedge clk_10M ) begin
        case ({ fg_pal_data_high[1:0] , fg_pal_data_low[1:0] })
            0  : fg_red <= 0;
            1  : fg_red <= 0;
            2  : fg_red <= 0;
            3  : fg_red <= 88;
            4  : fg_red <= 0;
            5  : fg_red <= 112;
            6  : fg_red <= 133;
            7  : fg_red <= 192;
            8  : fg_red <= 60;
            9  : fg_red <= 150;
            10 : fg_red <= 166;
            11 : fg_red <= 212;
            12 : fg_red <= 180;
            13 : fg_red <= 221;
            14 : fg_red <= 229;
            15 : fg_red <= 255;
        endcase
        case ({ fg_pal_data_high[3:2] , fg_pal_data_low[3:2] })
            0  : fg_green <= 0;
            1  : fg_green <= 0;
            2  : fg_green <= 0;
            3  : fg_green <= 88;
            4  : fg_green <= 0;
            5  : fg_green <= 112;
            6  : fg_green <= 133;
            7  : fg_green <= 192;
            8  : fg_green <= 60;
            9  : fg_green <= 150;
            10 : fg_green <= 166;
            11 : fg_green <= 212;
            12 : fg_green <= 180;
            13 : fg_green <= 221;
            14 : fg_green <= 229;
            15 : fg_green <= 255;
        endcase
        case ({ fg_pal_data_high[5:4] , fg_pal_data_low[5:4] })
            0  : fg_blue <= 0;
            1  : fg_blue <= 0;
            2  : fg_blue <= 0;
            3  : fg_blue <= 88;
            4  : fg_blue <= 0;
            5  : fg_blue <= 112;
            6  : fg_blue <= 133;
            7  : fg_blue <= 192;
            8  : fg_blue <= 60;
            9  : fg_blue <= 150;
            10 : fg_blue <= 166;
            11 : fg_blue <= 212;
            12 : fg_blue <= 180;
            13 : fg_blue <= 221;
            14 : fg_blue <= 229;
            15 : fg_blue <= 255;
        endcase
    end
    
    //
    //// bg ----------
    //
    wire [1:0] bg = { bg_shift_1[0], bg_shift_0[0] };
    //
    reg [1:0] bg_reg;
    reg [7:0] bg_attr_reg;
    
    reg [4:0] fg_pal_ofs_hi ;
    reg [4:0] fg_pal_ofs_low ;
    
    reg [4:0] sp_pal_ofs_hi ;
    reg [4:0] sp_pal_ofs_low ;
    
    reg [7:0] bg_scroll_y;
    reg [7:0] bg_scroll_x;
    
    wire [7:0] bg_scroll;
    assign bg_scroll = user_flip ? (v + ~bg_scroll_y) : v + bg_scroll_y;
    
    //// ---------- sprites ----------
    reg spr_ram_wr;   
    reg [7:0] spr_addr;
    wire [7:0] spr_ram_data;
    
    reg [7:0] spr_shift_data;
    
    reg [7:0] sprite_tile;
    reg [7:0] sprite_x;
    reg [7:0] sprite_y;
    reg [7:0] sprite_color;
    //reg [7:0] sprite_x;
    reg sprite_valid;
    
    wire [7:0] h5_data;
    wire [7:0] k5_data;
    reg [11:0] spr_bitmap_addr;
    
    //reg [7:0] spr_data_latch;

    // [0] tile #
    // [1] y
    // [2] color
    // [3] x
    
    // --------------- fg / bg ------------
    
    reg [5:0] sp_addr_cache[15:0];  
    reg [5:0] a7;
    reg [3:0] a9;
    
    reg [3:0] f8_buf[0:255];
    reg [7:0] f8_count;
    
    reg [3:0] g8_buf[0:255];
    reg [7:0] g8_count;
    
    reg [1:0] pad ;
    reg [1:0] pic ;
    reg [7:0] h10 ; // counter h10 LS393 drives timing prom J10
    reg [3:0] k6;
    reg [3:0] j6;
    reg load_shift;
    reg dec_a9;
    
    wire sp_bank = ( sprite_tile[6] == 1 );
    wire flip_x  = ( sprite_color[4] == 1 );
    wire flip_y  = ( sprite_color[5] == 1 );
    reg cocktail_flip;
    
    
    // hbl is made 64 clocks
    always @ (posedge clk_10M) begin
        if ( hbl_hx ) begin
            // clocked on the rising edge of HA. ie h[0]
            if ( clk_5M == 1 && h[0] == 1 ) begin
                // if tile is visible and still room in address stack
                if ( j7[7:4] == 0 && a9 < 15 ) begin
                    sp_addr_cache[a9][5:0] <= a7;
                    a9 <= a9 + 1;
                end 
                a7 <= a7 + 1;
            end
            h10 <= 0;
        end else begin
            // reset a9 on last pixel of playfield
            // should be zero anyways if a9 counted down correctly
            if ( hff == 1 ) begin
                a9 <= 0;
            end else if ( dec_a9 == 1 ) begin
                // a9 counts down on falling edge of pic1 when a9 > 0 and ~hbl 
                if ( a9 > 0 ) begin
                     a9 <= a9 - 1;
                end
            end
    
            h10 <= h10 + 1;
            a7 <= 0;
        end
    end
    
    always @ ( posedge clk_10M ) begin // neg
        // load new nibbles into the shifters
        // if not loading then shifting out
        if ( load_shift == 1 ) begin
            // select rom bank
            if ( sp_bank == 0 ) begin
                // cheat and swizzle the nibble before shifting
                if ( flip_x == 0 ) begin
                    k6 <= h5_data[3:0];
                    j6 <= h5_data[7:4];
                    f10_addr <= {sprite_color[2:0], h5_data[0], h5_data[4]};
                end else begin
                    k6 <= { h5_data[0], h5_data[1], h5_data[2], h5_data[3] };
                    j6 <= { h5_data[4], h5_data[5], h5_data[6], h5_data[7] };
                    f10_addr <= {sprite_color[2:0], h5_data[3], h5_data[7]};
                end
            end else begin
                if ( flip_x == 0 ) begin
                    k6 <= k5_data[3:0];
                    j6 <= k5_data[7:4];
                    f10_addr <= {sprite_color[2:0], k5_data[0], k5_data[4]};
                end else begin
                    k6 <= { k5_data[0], k5_data[1], k5_data[2], k5_data[3] };
                    j6 <= { k5_data[4], k5_data[5], k5_data[6], k5_data[7] };
                    f10_addr <= {sprite_color[2:0], k5_data[3], k5_data[7]};
                end
            end
        end else begin
            // the flip_x bit doesn't matter since the bits were re-ordered at load.
            k6 <= { 1'b0, k6[3:1]  };
            j6 <= { 1'b0, j6[3:1]  };
            // get one clock early.  not sure this works.
            f10_addr <= {sprite_color[2:0], k6[1], j6[1]};
        end
        
        // counters are always cleared during hbl
        // one will free count and the other will count the x offset in the current blitter
        // v[0] (schematic VADLAY) determines which buffer is blitting and which is streaming
        if ( hbl ) begin
            f8_count <= 0;
            g8_count <= 0;
        end else if ( pad[1:0] == 2'b11 ) begin
            // mux G9 gives LA4 ( L9 nand pad 1+0 ) to F8 or G8 load line
            // load one from sprite x pos, increment the other
            if ( v[0] == 1 ) begin
                f8_count <= spr_ram_data ;
                if ( clk_5M == 1 ) begin
                    g8_count <= g8_count + 1;
                end
            end else begin
                g8_count <= spr_ram_data ;
                if ( clk_5M == 1 ) begin
                    f8_count <= f8_count + 1;
                end
            end
        end else begin 
            // increment both
            if ( v[0] == 1 ) begin
                if ( sprite_valid ) begin
                    f8_count <= f8_count + 1;
                end
                if ( clk_5M == 1 ) begin
                    g8_count <= g8_count + 1;
                end
            end else begin
                if ( sprite_valid ) begin
                    g8_count <= g8_count + 1;
                end
                if ( clk_5M == 1 ) begin
                    f8_count <= f8_count + 1;
                end
            end
        end
    end
    
    always @ ( posedge clk_10M ) begin
        // odd / even lines each have their own sprite line buffer
        if ( v[0] == 1 ) begin
            // if the pixel color is 0 then the ram cs is not asserted and no write happens
            if ( k6[0] | j6[0] ) begin
                if ( sprite_valid ) begin
                    // sprite_color[3] selects high or low nibble of sprite color lookup
                    if ( sprite_color[3] == 0 ) begin
                        f8_buf[f8_count][3:0] <= f10_data[3:0];
                    end else begin
                        f8_buf[f8_count][3:0] <= f10_data[7:4];
                    end
                end
            end
            
            // buffer on pcb is cleared by pull-downs on the output bus
            // the ram we is asserted after the output is latched then the zero value is written on the opposite 10MHz edge.
            // address clock on the streaming buffer is at 5M.  It writes when the clock is high because clock gets inverted by L9
            
            if ( clk_5M == 1 && ~hbl_hx ) begin
                g8_buf[g8_count_flip][3:0] <= 0;
            end
        end else begin
            if ( k6[0] | j6[0] ) begin
                if ( sprite_valid ) begin
                    // sprite_color[3] selects high or low nibble of sprite color lookup
                    if ( sprite_color[3] == 0 ) begin
                        g8_buf[g8_count][3:0] <= f10_data[3:0];
                    end else begin
                        g8_buf[g8_count][3:0] <= f10_data[7:4];
                    end
                end
            end
            if ( clk_5M == 1 && ~hbl_hx ) begin
                f8_buf[f8_count_flip][3:0] <= 0;
            end
            
        end
    end
    
    
    reg [4:0] spr_pal_ofs_hi;
    reg [4:0] spr_pal_ofs_low;
    
    wire [7:0] g8_count_flip;
    assign g8_count_flip = user_flip ? ~g8_count : g8_count;
    
    wire [7:0] f8_count_flip;
    assign f8_count_flip = user_flip ? ~f8_count : f8_count;
    
    
    // sprite buffer handling
    always @ (posedge clk_10M) begin   
        if ( clk_5M == 0 ) begin
            // default to clear
            spr_pal_ofs_hi <= 0;
            spr_pal_ofs_low <= 0;
            
            if ( v[0] == 1 && g8_buf[g8_count_flip] > 0 ) begin
                spr_pal_ofs_hi  <= { 1'b0, g8_buf[g8_count_flip] };
                spr_pal_ofs_low <= { 1'b0, g8_buf[g8_count_flip][3:2], g8_buf[g8_count_flip][1:0] };
            end 
            if ( v[0] == 0 && f8_buf[f8_count_flip] > 0 ) begin
                spr_pal_ofs_hi  <= { 1'b0, f8_buf[f8_count_flip] };
                spr_pal_ofs_low <= { 1'b0, f8_buf[f8_count_flip][3:2], f8_buf[f8_count_flip][1:0] };
            end
        end 
    end
    
    always @ (posedge clk_10M) begin     // neg   
        // data in spr_ram_data
        // { pad[7:2], pad[1:0] } on the schematic.  pad counter
        // is h counter really reset and the same time as pad counter (A7)?
        if ( hbl_hx ) begin
            // 64 cycles of checking if y active and storing a7 if it is
            spr_addr <= { a7[5:0], 2'b01 };  // only y
        end else begin
            spr_addr <= { sp_addr_cache[a9], pad[1:0] };  // only y 63-0
        end
        
        if ( ~hbl_hx ) begin
        
            // set the current position into the bitmap rom based on the tile, 
            // y offset and bitmap byte offset
             // last 2 bits are from timing prom pad[0] & pad[1] 
             // if ( sprite_color[5] == 0 ) begin
             if ( flip_y == 0 ) begin
                if ( flip_x == 0 ) begin
                    spr_bitmap_addr <= { sprite_tile[5:0], sprite_y[3:0], pic[1:0] } ; 
                end else begin
                    spr_bitmap_addr <= { sprite_tile[5:0], sprite_y[3:0], ~pic[1:0] } ; 
                end
             end else begin
                if (  flip_x == 0 ) begin
                    spr_bitmap_addr <= { sprite_tile[5:0], ~sprite_y[3:0], pic[1:0] } ; 
                end else begin
                    spr_bitmap_addr <= { sprite_tile[5:0], ~sprite_y[3:0], ~pic[1:0] } ; 
                end
             end
             
         end
    end
    
    // sprites are added to a visible list during the hblank of the previous line
    wire [7:0]j7 = user_flip ? (spr_ram_data + ~(v+1)) : spr_ram_data + (v+1);
    
    always @ (posedge clk_10M) begin

        // J10 logic
        // 8 clocks per sprite
        // even is falling 5M clk
        // timing altered from prom to deal with async/sync differences 
        case ( h10[4:0] )
            0:  begin
                    pad <= 2'b00;
                    pic <= 2'b00;
                    load_shift <= 0;
                end
            2:  begin
                    sprite_tile <= spr_ram_data;
                    //sprite_tile <= 8'h06;
                    pad <= 2'b01;
                end
            4:  begin
                    sprite_y <= j7; // spr_ram_data + v ; 
    
                    if ( spr_ram_data !== 0 && j7 < 16 ) begin
                        sprite_valid <= 1;
                    end else begin
                        sprite_valid <= 0;
                    end
                    pad <= 2'b10;
                end
            6:  begin
                    sprite_color <= spr_ram_data ;
                    pad <= 2'b11;
                end
            8:  begin
                    sprite_x <= spr_ram_data ;
    //                    pad <= 2'b00; // different than prom value
                end
            9:  begin
                    load_shift <= 1; 
                end
            10: begin
                            load_shift <= 0;
                    // this should be at 8
                    pad <= 2'b00;            
                end
            11: begin
                    pic <= 2'b01;
                end
            13: begin
                    load_shift <= 1; 
                end
            14: begin
                    load_shift <= 0; 
                end
            15: begin
                    pic <= 2'b10;
                end
            17: begin
                    load_shift <= 1; 
                end
            18: begin
                    load_shift <= 0; 
                end
            19: begin
                    pic <= 2'b11;
                end
            21: begin
                    load_shift <= 1;
                end
            22: begin
                      load_shift <= 0;
                end
            26: begin
                    dec_a9 <= 1;
                end
            27: begin
                    dec_a9 <= 0;
                    pic <= 2'b00;
                end
        endcase
    
    end
    
    reg draw;
    
    always @ (posedge clk_10M) begin   
        if ( clk_5M == 1 ) begin
            // load palette - calculate rom offsets
            // check if bg or fg asserted priority
    
            if ( spr_pal_ofs_hi > 0 && ( h > 16 || ~user_flip ) ) begin
                // the h > 16 condition is a screen flip hack.  not in original hardware
                fg_pal_ofs_hi  <= spr_pal_ofs_hi;
                fg_pal_ofs_low <= spr_pal_ofs_low;
                draw <= 1;
            end else if ( fg !== 0 || fg_attr[6] == 1 ) begin
                // fg
                fg_pal_ofs_hi  <= { fg_attr[2:0] , fg_shift_1[0], fg_shift_0[0] };
                fg_pal_ofs_low <= { fg_attr[5:3] , fg_shift_1[0], fg_shift_0[0] };
                draw <= 1;
                
            end else if ( bg != 0 || bg_attr[6] == 1 ) begin
                // bg
                fg_pal_ofs_hi  <= { bg_attr[2:0] , bg_shift_1[0], bg_shift_0[0] };
                fg_pal_ofs_low <= { bg_attr[5:3] , bg_shift_1[0], bg_shift_0[0] };
                draw <= 1;
            end else begin
                draw <= 0;
            end
    
            if ( h[2:0] !== 7 ) begin
                // unless we are loading the shift register then shift it.
                fg_shift_0 <= { fg_shift_0[0], fg_shift_0[7:1] };
                fg_shift_1 <= { fg_shift_1[0], fg_shift_1[7:1] };
    
                bg_shift_0 <= { bg_shift_0[0], bg_shift_0[7:1] };
                bg_shift_1 <= { bg_shift_1[0], bg_shift_1[7:1] };
                
            end
        
            // load / shift tiles
            case ( { cocktail_flip ^ user_flip, h[2:0] } )
                5:  begin
                        fg_char_index <= { v[7:3] , h[7:3] }  ; // 32*32 characters
                        bg_char_index <= { bg_scroll[7:3] , h[7:3] }  ; // 32*32 characters
                    end
                6:  begin
                        fg_bitmap_addr <= { gfx_fg_attr_data[7], gfx_fg_tile_data, v[2:0] };
                        bg_bitmap_addr <= { gfx_bg_attr_data[7], gfx_bg_tile_data, bg_scroll[2:0] };
                    end
                7:  begin 
                        // latched by N9/P9 & U9 & S9 on h[2:0] == 111 R6 creates latch clock
                        fg_shift_0 <= u8_data;
                        fg_shift_1 <= s8_data;
                
                        bg_shift_0 <= n8_data ;
                        bg_shift_1 <= r8_data ;
                        
                        fg_attr <= gfx_fg_attr_data;
                        bg_attr <= gfx_bg_attr_data; 
                    end
                13:  begin
                        fg_char_index <= ~{ v[7:3] , h[7:3] }  ; // 32*32 characters
                        bg_char_index <= ~{ bg_scroll[7:3] , h[7:3] }  ; // 32*32 characters
                    end
                14:  begin
                        fg_bitmap_addr <= { gfx_fg_attr_data[7], gfx_fg_tile_data, ~v[2:0] };
                        bg_bitmap_addr <= { gfx_bg_attr_data[7], gfx_bg_tile_data, ~bg_scroll[2:0] };
                    end
                15: begin
                        fg_shift_0 <= { u8_data[0], u8_data[1], u8_data[2], u8_data[3], u8_data[4], u8_data[5], u8_data[6], u8_data[7]} ;
                        fg_shift_1 <= { s8_data[0], s8_data[1], s8_data[2], s8_data[3], s8_data[4], s8_data[5], s8_data[6], s8_data[7]} ;
                
                        bg_shift_0 <= { n8_data[0], n8_data[1], n8_data[2], n8_data[3], n8_data[4], n8_data[5], n8_data[6], n8_data[7]} ;
                        bg_shift_1 <= { r8_data[0], r8_data[1], r8_data[2], r8_data[3], r8_data[4], r8_data[5], r8_data[6], r8_data[7]} ;
    
                        fg_attr <= gfx_fg_attr_data;
                        bg_attr <= gfx_bg_attr_data; 
                    end
                 
            endcase
        end
    end

    wire [7:0] fg_pal_data_high;  // read from palette prom
    wire [7:0] fg_pal_data_low;
    
    wire [7:0] bg_pal_data_high;
    wire [7:0] bg_pal_data_low;
    
    always @ (posedge clk_5M ) begin
        if ( ~hbl_hx & ~vbl ) begin // LS32 R2
            if ( draw ) begin
                rgb_comp <= { fg_red[7:4], fg_green[7:4], fg_blue[7:4] };
            end else begin
                rgb_comp <=  0;
            end
        end else begin
            // vblank / hblank
            rgb_comp <= 0;
        end
    end
    
    reg [15:0] unhandled_addr;
    
    always @ (posedge clk_4M ) begin
    
    if ( rd_n == 0 ) begin
        // read program rom
        if ( cpu_addr >= 16'h0000 && cpu_addr < 16'h2000 ) begin
            cpu_din <= cpu01rom_data ; // 0x0000
            
        end else if ( cpu_addr >= 16'h2000 && cpu_addr < 16'h4000 ) begin    
            cpu_din <= cpu02rom_data ; // 0x2000
            
        end else if ( cpu_addr >= 16'h4000 && cpu_addr < 16'h6000 ) begin               
            cpu_din <= cpu03rom_data ; // 0x4000
            
        end else if ( cpu_addr >= 16'h6000 && cpu_addr < 16'h8000 ) begin                   
            cpu_din <= cpu04rom_data ; // 0x6000
            
        end else if ( cpu_addr >= 16'h8000 && cpu_addr < 16'h8400 ) begin   
            cpu_din <= bg_ram0_data;
            
        end else if ( cpu_addr >= 16'h8400 && cpu_addr < 16'h8800 ) begin    
            cpu_din <= bg_ram1_data;
            
        end else if ( cpu_addr >= 16'h8800 && cpu_addr < 16'h8c00 ) begin   
            cpu_din <= fg_ram0_data;
            
        end else if ( cpu_addr >= 16'h8c00 && cpu_addr < 16'h9000 ) begin   
            cpu_din <= fg_ram1_data;

        end else if ( cpu_addr == 16'h9803 ) begin   
            cpu_din <= u001_dout;
            
        end else if ( cpu_addr == 16'ha000 ) begin   
            cpu_din <= p1;
            
        end else if ( cpu_addr == 16'ha001 ) begin
            cpu_din <= p2;
            
        end else if ( cpu_addr == 16'ha002 ) begin   
            cpu_din <= dsw1;
            
        end else if ( cpu_addr == 16'ha003 ) begin           
            cpu_din <= dsw2;
            
        end else if ( cpu_addr >= 16'he000 && cpu_addr < 16'hf000 ) begin   
            cpu_din <= cpu_ram_data;
            
        end else begin
            unhandled_addr <= cpu_addr;
        end
    end else begin
    
        if ( cpu_addr[15:12] == 4'he ) begin
            // 0xe000-0xefff z80 ram
            cpu_ram_w <= ~wr_n ;
        end else if ( cpu_addr[15:12] == 4'h8 ) begin
                case ( cpu_addr[11:10] )
                    6'b00 :  gfx_bg_ram0_wr <= ~wr_n;
                    6'b01 :  gfx_bg_ram1_wr <= ~wr_n;
                    6'b10 :  gfx_fg_ram0_wr <= ~wr_n;
                    6'b11 :  gfx_fg_ram1_wr <= ~wr_n;
                endcase 
        end else if (cpu_addr >= 16'h9000 && cpu_addr < 16'h9800 ) begin 
            // 0x9000-0x90ff sprite ram
            if ( ~vbl ) begin
                spr_ram_wr <=  ~wr_n ;
            end
        end else if (cpu_addr[15:11] == 5'b11111 ) begin 
            // 0xF800-0xffff horz scroll latch
            if ( wr_n == 0 ) begin
                bg_scroll_y <= cpu_dout;
            end
        end else if (cpu_addr == 16'h9800 ) begin         
            if ( wr_n == 0 ) begin
                cocktail_flip <= cpu_dout[0];
            end
        end else if (cpu_addr == 16'h9801 ) begin 
            sound1_wr <= ~wr_n;
            sound1_en <= 1;
        end else if (cpu_addr == 16'h9802 ) begin 
            sound2_wr <= ~wr_n;
            sound2_en <= 1;        
        end else begin
            // no valid write address
            cpu_ram_w <= 0 ;
            
            gfx_fg_ram0_wr <= 0 ;
            gfx_fg_ram1_wr <= 0 ;
            
            gfx_bg_ram0_wr <= 0 ;
            gfx_bg_ram1_wr <= 0 ;
            
            sound1_wr <= 0;
            sound1_en <= 0;    

            sound2_wr <= 0;
            sound2_en <= 0;    
        end
    end
end

    // u001 "secret" pal protection
    // cpu tries to read val from 0x9803 which is state machine pal
    // written to on all tile ram access. 
    
    wire [7:0] u001_dout ;
    
    secret_pal u001
    (
        .clk( gfx_fg_ram0_wr | gfx_fg_ram1_wr),
        .i( cpu_dout ),
        .o( u001_dout )
    );


    // first 256 bytes are attribute data
    // bit 7 of attr == MSB of tile 
    // bit 6 tile flip
    // bit 5-0 == 64 colors from palette
    // bytes 256-511 are tile index
    
        
    wire wr_n;
    wire rd_n;
    
    // interupt control 
    // the irq should be clocked by the risign vbl and cleared by
    // IORQ_n and M1_n both low for Z80 IRQ ack, 
    // by the interrupt request clear signal from the video gen, 
    // or by a 555 watchdog.  This should be fixed.
    
    wire IORQ_n;
    wire M1_n;
    
    reg prev_vbl = 0;
    reg vert_int_n;
    
    //always @ (posedge clk_4M ) begin
    //    prev_vbl <= vbl;
    //    if ( prev_vbl == 0 && vbl == 1 ) begin
    //        vert_int_n <= 0;
    //    end else if ( ( IORQ_n == 0 && M1_n == 0 ) || ( vbl == 0 && v == 32 ) ) begin
    //        // 
    //        vert_int_n <= 1;
    //    end
    //end
    
    always @ (posedge clk_4M ) begin
        prev_vbl <= vbl;
        vert_int_n <= ( v !== 208 ) ;
    end
    
    T80pa u_cpu(
        .RESET_n    ( ~reset ),
        .CLK        ( clk_8M ),
        .CEN_p      ( clk_4M ),     
        .CEN_n      ( 1'b1 ),
        .WAIT_n     ( ~pause_cpu ),
        .INT_n      ( vert_int_n ),  
        .NMI_n      ( 1'b1     ),
        .BUSRQ_n    ( 1'b1     ),
        .RD_n       ( rd_n     ),
        .WR_n       ( wr_n     ),
        .A          ( cpu_addr ),
        .DI         ( cpu_din  ),
        .DO         ( cpu_dout ),
        // unused
        .DIRSET     ( 1'b0     ),
        .DIR        ( 212'b0   ),
        .OUT0       ( 1'b0     ),
        .RFSH_n     (),
        .IORQ_n     (IORQ_n),
        .M1_n       (M1_n),
        .BUSAK_n    (),
        .HALT_n     (),
        .MREQ_n     (),
        //.Stop       (), -- Doesn;t exist in T80pa.vhd
        .REG        ()
    );
    
    wire [3:0] sound_mask = pause_cpu ? 4'b0000 : 4'b1111;

    // sound clock, cpu clock, chip select, write enable, data, mask, output )
    SN76496 sound1( clk_4M, clk_4M, reset, sound1_en, sound1_wr, cpu_dout, sound_mask, sound1_out );
    SN76496 sound2( clk_4M, clk_4M, reset, sound2_en, sound2_wr, cpu_dout, sound_mask, sound2_out );

    // cpu rom a4 - 8kb
    wire a4_cs = (dn_addr_i[15:13] == 3'b000);
    dualport_2clk_ram #(.FALLING_A(1),.ADDR_WIDTH(13),.DATA_WIDTH(8)
    ) cpu01rom_a4 (
        .clock_a(dn_clk_i),
        .address_a(dn_addr_i[12:0]),
        .wren_a(dn_wr_i & a4_cs & rom_download),
        .data_a(dn_data_i),
        
        .clock_b(~clk_4M),
        .address_b(cpu_addr[12:0]),
        .q_b(cpu01rom_data)
    );
    
    // cpu rom c4 - 8kb
    wire c4_cs = (dn_addr_i[15:13] == 3'b001);
    dualport_2clk_ram #(.FALLING_A(1),.ADDR_WIDTH(13),.DATA_WIDTH(8)
    ) cpu02rom_c4 (
        .clock_a(dn_clk_i),
        .address_a(dn_addr_i[12:0]),
        .wren_a(dn_wr_i & c4_cs & rom_download),
        .data_a(dn_data_i),
        
        .clock_b(~clk_4M),
        .address_b(cpu_addr[12:0]),
        .q_b(cpu02rom_data)
    );
    
    // cpu rom E4 - 8kb
    wire e4_cs = (dn_addr_i[15:13] == 3'b010);
    dualport_2clk_ram #(.FALLING_A(1),.ADDR_WIDTH(13),.DATA_WIDTH(8)
    ) pu01rom_e4 (
        .clock_a(dn_clk_i),
        .address_a(dn_addr_i[12:0]),
        .wren_a(dn_wr_i & e4_cs & rom_download),
        .data_a(dn_data_i),
    
        .clock_b(~clk_4M),
        .address_b(cpu_addr[12:0]),
        .q_b(cpu03rom_data)
    );
    
    // cpu rom F4
    wire f4_cs = (dn_addr_i[15:13] == 3'b011);
    dualport_2clk_ram #(.FALLING_A(1),.ADDR_WIDTH(13),.DATA_WIDTH(8)
    ) cpu01rom_f4 (
        .clock_a(dn_clk_i),
        .address_a(dn_addr_i[12:0]),
        .wren_a(dn_wr_i & f4_cs & rom_download),
        .data_a(dn_data_i),
    
        .clock_b(~clk_4M),
        .address_b(cpu_addr[12:0]),
        .q_b(cpu04rom_data)
    );
    
    // cpu work ram
    dualport_2clk_ram #(.ADDR_WIDTH(12),.DATA_WIDTH(8)
    ) cpu_ram_inst (    
        .address_a(cpu_addr[11:0]),
        .clock_a(~clk_4M),
        .data_a(cpu_dout),
        .wren_a(cpu_ram_w),
        .q_a(cpu_ram_data),
    
        .address_b(hs_address),
        .clock_b(clk_sys_i),
        .data_b(hs_data_in),
        .wren_b(hs_write_enable),
        .q_b(hs_data_out)
    );
    
    // foreground tile attributes
    dualport_2clk_ram #(.ADDR_WIDTH(10),.DATA_WIDTH(8)
    ) gfx_fg_ram0_inst (
        .clock_a(~clk_5M),
        .address_a(cpu_addr[9:0]),
        .data_a(cpu_dout),
        .wren_a(gfx_fg_ram0_wr),
        .q_a(fg_ram0_data),
    
        .clock_b(~clk_10M),
        .address_b(fg_char_index),
        .data_b(0),
        .wren_b(0),
        .q_b(gfx_fg_attr_data)
	);
	
    // foreground tile index
    dualport_2clk_ram #(.ADDR_WIDTH(10),.DATA_WIDTH(8)
    ) gfx_fg_ram1_inst (
        .clock_a(~clk_4M ),
        .address_a(cpu_addr[9:0]),
        .data_a(cpu_dout),
        .wren_a(gfx_fg_ram1_wr),
        .q_a(fg_ram1_data),
    
        .clock_b(~clk_10M),
        .address_b(fg_char_index),
        .data_b(0),
        .wren_b(0),
        .q_b(gfx_fg_tile_data )
        );
        
    // background tile attributes
    dualport_2clk_ram #(.ADDR_WIDTH(10),.DATA_WIDTH(8)
    ) gfx_bg_ram0_inst (
        .clock_a(~clk_4M),
        .address_a(cpu_addr[9:0]),
        .data_a(cpu_dout),
        .wren_a(gfx_bg_ram0_wr),
        .q_a(bg_ram0_data),
    
        .clock_b(~clk_10M ),
        .address_b(bg_char_index),
        .data_b(0),
        .wren_b(0),
        .q_b(gfx_bg_attr_data)
    );
        
    // background tile index
    dualport_2clk_ram #(.ADDR_WIDTH(10),.DATA_WIDTH(8)   
    ) gfx_bg_ram1_inst (
        .clock_a(~clk_4M),
        .address_a(cpu_addr[9:0]),
        .data_a(cpu_dout),
        .wren_a(gfx_bg_ram1_wr),
        .q_a(bg_ram1_data),
    
        .clock_b(~clk_10M ),
        .address_b(bg_char_index),
        .data_b(0),
        .wren_b(0),
        .q_b(gfx_bg_tile_data )
    );
        
    // sprite ram - hardware uses 2x6148 = 1k, only 256 bytes can be addressed
    dualport_2clk_ram #(.ADDR_WIDTH(10),.DATA_WIDTH(8)
    ) spr_ram (
        .clock_a(~clk_4M ),
        .address_a({2'b00, cpu_addr[7:0]}),
        .data_a(cpu_dout),
        .wren_a(spr_ram_wr),
        //.q_a (), // cpu can't read sprite ram
    
        .clock_b(~clk_10M),
        .address_b(spr_addr),
        .data_b(0),
        .wren_b(0),
        .q_b(spr_ram_data)
     );
        
    // foreground tile bitmap S8   
    wire s8_cs = (dn_addr_i[15:12] == 4'b1000);
    dualport_2clk_ram #(.FALLING_A(1),.ADDR_WIDTH(12),.DATA_WIDTH(8)
    ) gfx_s8 (
        .clock_a(dn_clk_i),
        .address_a(dn_addr_i[11:0]),
        .wren_a(dn_wr_i & s8_cs & rom_download),
        .data_a(dn_data_i),
    
        .clock_b(~clk_10M),
        .address_b(fg_bitmap_addr),
        .q_b(s8_data)
    );
    
    // foreground tile bitmap u8  
    wire u8_cs = (dn_addr_i[15:12] == 4'b1001);
    dualport_2clk_ram #(.FALLING_A(1),.ADDR_WIDTH(12),.DATA_WIDTH(8)
    ) gfx_u8 (
        .clock_a(dn_clk_i),
        .address_a(dn_addr_i[11:0] ),
        .wren_a(dn_wr_i & u8_cs & rom_download),
        .data_a(dn_data_i),
    
        .clock_b(~clk_10M ),
        .address_b(fg_bitmap_addr ),
        .q_b(u8_data )
    );
    
    // background tile bitmap r8
    wire r8_cs = (dn_addr_i[15:12] == 4'b1010);
    dualport_2clk_ram #(.FALLING_A(1),.ADDR_WIDTH(12),.DATA_WIDTH(8)
    ) gfx_r8 (
        .clock_a(dn_clk_i),
        .address_a(dn_addr_i[11:0]),
        .wren_a(dn_wr_i & r8_cs & rom_download),
        .data_a(dn_data_i),
    
        .clock_b(~clk_10M),
        .address_b(bg_bitmap_addr),
        .q_b(r8_data)
    );
    
    // background tile bitmap n8
    wire n8_cs = (dn_addr_i[15:12] == 4'b1011);
    dualport_2clk_ram #(.FALLING_A(1),.ADDR_WIDTH(12),.DATA_WIDTH(8)
    ) gfx_n8 (
        .clock_a(dn_clk_i),
        .address_a(dn_addr_i[11:0]),
        .wren_a(dn_wr_i & n8_cs & rom_download),
        .data_a(dn_data_i),
    
        .clock_b(~clk_10M),
        .address_b(bg_bitmap_addr),
        .q_b(n8_data)
    );
    
    
    // sprite bitmap h5
    wire h5_cs = (dn_addr_i[15:12] == 4'b1100);
    dualport_2clk_ram #(.FALLING_A(1),.ADDR_WIDTH(12),.DATA_WIDTH(8)
    ) gfx_h5 (
        .clock_a(dn_clk_i),
        .address_a(dn_addr_i[11:0]),
        .wren_a(dn_wr_i & h5_cs & rom_download),
        .data_a(dn_data_i),
    
        .clock_b(~clk_10M),
        .address_b(spr_bitmap_addr),
        .q_b(h5_data)
    );
    
    // sprite bitmap k5
    wire k5_cs = (dn_addr_i[15:12] == 4'b1101);
    dualport_2clk_ram #(.FALLING_A(1),.ADDR_WIDTH(12),.DATA_WIDTH(8)
    ) gfx_k5 (
        .clock_a(dn_clk_i),
        .address_a(dn_addr_i[11:0]),
        .wren_a(dn_wr_i & k5_cs & rom_download),
        .data_a(dn_data_i),
    
        .clock_b(~clk_10M ),
        .address_b(spr_bitmap_addr),
        .q_b(k5_data )
        );
    
    // palette high bits
    wire u02_cs = (dn_addr_i[15:5] == 11'b11100000000 );
    dualport_2clk_ram #(.FALLING_A(1),.ADDR_WIDTH(5),.DATA_WIDTH(8)
    ) pal_rom_u2 (
        .clock_a(dn_clk_i),
        .wren_a(dn_wr_i & u02_cs & rom_download),
        .address_a(dn_addr_i[4:0]),
        .data_a(dn_data_i),
        
        .clock_b(~clk_10M),
        .address_b(fg_pal_ofs_hi),
        .q_b(fg_pal_data_high)
    );
    
    // palette low bits
    wire t02_cs = (dn_addr_i[15:5] == 11'b11100000001 );
    dualport_2clk_ram #(.FALLING_A(1),.ADDR_WIDTH(5),.DATA_WIDTH(8)
    ) pal_rom_t2 (
        .clock_a(dn_clk_i),
        .wren_a(dn_wr_i & t02_cs & rom_download),
        .address_a(dn_addr_i[4:0]),
        .data_a(dn_data_i),
        
        .clock_b(~clk_10M),
        .address_b(fg_pal_ofs_low),
        .q_b(fg_pal_data_low)
    );
    
    // sprite palette lookup F10
    wire f10_cs = (dn_addr_i[15:5] == 11'b11100000010 );
    dualport_2clk_ram #(.FALLING_A(1),.ADDR_WIDTH(5),.DATA_WIDTH(8)
    ) pal_rom_f10 (
        .clock_a(dn_clk_i),
        .wren_a(dn_wr_i & f10_cs & rom_download ),
        .address_a(dn_addr_i[4:0] ),
        .data_a(dn_data_i),
        
        .clock_b(~clk_10M ),
        .address_b(f10_addr ),
        .q_b(f10_data )
    );
    
    
    // Keyboard adapter
    keyboard i_keyboard (
        .clk_main_i      (clk_sys_i),
        .key_num_i       (kb_key_num_i),
        .key_pressed_n_i (kb_key_pressed_n_i),
        .keyboard_n_o    (keyboard_n)
    );

endmodule

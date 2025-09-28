// -----------------------------------------------------------------------------
// MiSTer2MEGA65 Framework
//
// Wrapper for the MiSTer core that runs exclusively in the core's clock domain
//
// Converted from VHDL to Verilog
// ----------------------------------------------------------------------------- 

module main #(
    parameter G_VDNUM = 1
)(
    input  wire        clk_sys_i,
    input  wire        clk_98M_i,
    input  wire        reset_soft_i,
    input  wire        reset_hard_i,
    input  wire        pause_i,
    output wire        dim_video_o,

    input  wire [31:0] clk_main_speed_i,

    // Video
    output wire        video_ce_o,
    output wire        video_ce_ovl_o,
    output wire [2:0]  video_red_o,
    output wire [2:0]  video_green_o,
    output wire [1:0]  video_blue_o,
    output wire        video_vs_o,
    output wire        video_hs_o,
    output wire        video_hblank_o,
    output wire        video_vblank_o,

    // Audio (signed PCM)
    output [15:0] audio_left_o,
    output [15:0] audio_right_o,

    // Keyboard
    input  wire [6:0]  kb_key_num_i,
    input  wire        kb_key_pressed_n_i,

    // Joysticks
    input  wire        joy_1_up_n_i,
    input  wire        joy_1_down_n_i,
    input  wire        joy_1_left_n_i,
    input  wire        joy_1_right_n_i,
    input  wire        joy_1_fire_n_i,

    input  wire        joy_2_up_n_i,
    input  wire        joy_2_down_n_i,
    input  wire        joy_2_left_n_i,
    input  wire        joy_2_right_n_i,
    input  wire        joy_2_fire_n_i,

    input  wire [7:0]  pot1_x_i,
    input  wire [7:0]  pot1_y_i,
    input  wire [7:0]  pot2_x_i,
    input  wire [7:0]  pot2_y_i,

    // Dips
    input  wire [7:0]  dsw_a_i,
    input  wire [7:0]  dsw_b_i,

    // Downloader
    input  wire        dn_clk_i,
    input  wire [15:0] dn_addr_i,
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
    
    reg [7:0] sound1_out;
    reg [7:0] sound2_out;
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
    wire        reset = reset_hard_i | reset_soft_i;

    wire [15:0] hs_address;
    wire [7:0]  hs_data_in;
    wire [7:0]  hs_data_out;
    wire        hs_write_enable;

    wire        hs_pause;
    wire [1:0]  options;
    reg         self_test;
    
    reg  clk_5M,clk_10M,clk_4M,clk_8M;
    
    reg [5:0] clk10_count;
    reg [5:0] clk5_count;
    reg [5:0] clk8_count;
    reg [5:0] clk4_count;

    always @ (posedge clk_98M_i) begin
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
    
    assign video_ce_o = clk_5M;
    
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
    wire b_pause   = ~keyboard_n[m65_p];

    reg [7:0] p1 ;
    reg [7:0] p2;
    reg [7:0] dsw1 ;
    reg [7:0] dsw2 ;
    reg user_flip;
    
    always @ (posedge clk_4M ) begin
        p1 <= ~{ 1'b0, b_start2, b_start1, b_fire, b_up, b_right, b_down, b_left };
        p2 <= ~{ b_coin, 1'b0, 1'b0, b_fire_2, b_up_2, b_right_2, b_down_2, b_left_2 };
        
        dsw1 <= dsw_a_i[0];
        dsw2 <= dsw_b_i[1];
        
        user_flip <= 0; //sw[2][0]; // not in original hardware - hookup to OSM
    end
    
    wire [11:0] rgb_comp;
    
    wire hbl;
    //wire vbl;
    wire hx;
    wire hff;
    
    //wire hbl_hx;
    assign video_hblank_o = hbl | hx;
    
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
    .vbl(video_vblank_o),
//    output reg  vbl_n,
//    output reg  vbls,
//    output reg  vbls_n,
    
    .hsync(video_hs_o),     
    .vsync(video_vs_o)   
    );
    
    wire [7:0] s8_data;
    wire [7:0] u8_data;
    
    wire [7:0] r8_data;
    wire [7:0] n8_data;
    
    wire [7:0] f10_data;
    reg [5:0] f10_addr;    
    
    reg [9:0]  fg_char_index ; 
    reg [9:0]  bg_char_index ; 
    
    reg [15:0] cpu_addr;
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
    


    wire [7:0] fg_pal_data_high;  // read from palette prom
    wire [7:0] fg_pal_data_low;
    
    wire [7:0] bg_pal_data_high;
    wire [7:0] bg_pal_data_low;

    assign options[0] = osm_control_i[C_MENU_OSMPAUSE];
    assign options[1] = osm_control_i[C_MENU_OSMDIM];
    assign flip_screen = osm_control_i[C_MENU_FLIP];

   

    // Keyboard adapter
    keyboard i_keyboard (
        .clk_main_i      (clk_main_i),
        .key_num_i       (kb_key_num_i),
        .key_pressed_n_i (kb_key_pressed_n_i),
        .keyboard_n_o    (keyboard_n)
    );

endmodule

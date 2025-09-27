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
    input  wire        clk_main_i,
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
    output reg  [15:0] audio_left_o,
    output reg  [15:0] audio_right_o,

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
    wire [15:0] audio;

    wire [1:0]  buttons;
    wire        reset = reset_hard_i | reset_soft_i;

    wire [15:0] hs_address;
    wire [7:0]  hs_data_in;
    wire [7:0]  hs_data_out;
    wire        hs_write_enable;

    wire        hs_pause;
    wire [1:0]  options;
    reg         self_test;

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

    // Audio polarity adjustment
    always @(*) begin
        audio_left_o  = {~audio[15], audio[14:0]};
        audio_right_o = {~audio[15], audio[14:0]};
    end

    assign options[0] = osm_control_i[C_MENU_OSMPAUSE];
    assign options[1] = osm_control_i[C_MENU_OSMDIM];
    assign flip_screen = osm_control_i[C_MENU_FLIP];

    // Handle self_test
    always @(posedge clk_main_i) begin
        if (!pause_cpu)
            self_test <= ~keyboard_n[m65_capslock];
    end

    // Core instance (replace galaga with mrdo if needed)
    galaga i_galaga (
        .clock_18   (clk_main_i),
        .reset      (reset),
        .video_r    (video_red_o),
        .video_g    (video_green_o),
        .video_b    (video_blue_o),
        .video_hs   (video_hs_o),
        .video_vs   (video_vs_o),
        .blank_h    (video_hblank_o),
        .blank_v    (video_vblank_o),
        .audio      (audio),
        .self_test  (self_test),
        .service    (~keyboard_n[m65_s]),
        .coin1      (~keyboard_n[m65_5]),
        .coin2      (~keyboard_n[m65_6]),
        .start1     (~keyboard_n[m65_1]),
        .start2     (~keyboard_n[m65_2]),
        .up1        (~joy_1_up_n_i),
        .down1      (~joy_1_down_n_i),
        .left1      ((~joy_1_left_n_i) | (~keyboard_n[m65_a])),
        .right1     ((~joy_1_right_n_i) | (~keyboard_n[m65_d])),
        .fire1      ((~joy_1_fire_n_i) | (~keyboard_n[m65_up_crsr])),
        .up2        (~joy_2_up_n_i),
        .down2      (~joy_2_down_n_i),
        .left2      (~joy_2_left_n_i),
        .right2     (~joy_2_right_n_i),
        .fire2      (~joy_2_fire_n_i),
        .flip_screen(flip_screen),
        .dip_switch_a(~dsw_b_i),
        .dip_switch_b(~dsw_a_i),
        .h_offset   (status[27:24]),
        .v_offset   (status[31:28]),
        .pause      (pause_cpu | pause_i),
        .hs_address (hs_address),
        .hs_data_out(hs_data_out),
        .hs_data_in (hs_data_in),
        .hs_write   (hs_write_enable),
        .dn_clk     (dn_clk_i),
        .dn_addr    (dn_addr_i),
        .dn_data    (dn_data_i),
        .dn_wr      (dn_wr_i)
    );

    // Pause instance
    pause #(
        .RW(3),
        .GW(3),
        .BW(2),
        .CLKSPD(18)
    ) i_pause (
        .clk_sys       (clk_main_i),
        .reset         (reset),
        .user_button   (keyboard_n[m65_p]),
        .pause_request (hs_pause),
        .options       (options),
        .OSD_STATUS    (1'b0),
        .r             (video_red_o),
        .g             (video_green_o),
        .b             (video_blue_o),
        .pause_cpu     (pause_cpu),
        .dim_video     (dim_video_o)
    );

    // Keyboard adapter
    keyboard i_keyboard (
        .clk_main_i      (clk_main_i),
        .key_num_i       (kb_key_num_i),
        .key_pressed_n_i (kb_key_pressed_n_i),
        .keyboard_n_o    (keyboard_n)
    );

endmodule

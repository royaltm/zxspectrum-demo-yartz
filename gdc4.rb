# -*- coding: BINARY -*-
require 'z80'
require 'z80/math_i'
require 'z80/stdlib'
require 'zxlib/gfx'
require 'zxlib/sys'
require 'zxlib/basic'
require 'zxutils/zx7'
require 'z80/utils/shuffle'
require 'z80/utils/sincos'
require 'zxutils/bigfont'
require_relative 'music'

class GDC
  include Z80
  include Z80::TAP

  VERSION = '1.0.1'.freeze

  ##
  # This constant controls rendering mode and may be one of:
  #
  # * false - renders from 0 to 22 attribute line
  # * true - renders full screen
  # * :center - renders from 1 to 23 attribute line
  #
  FULL_SCREEN_MODE = false

  # rotate_flags bit constants
  B_ROTATE_SIMPLY = 0 # if set simple rotator is enabled
  B_ENABLE_ZOOM   = 1 # if set simple rotator also simple zooms back and forth
  B_RND_PATTERN   = 1 # if B_ROTATE_SIMPLY is unset and this is set, the advanced control moves the pattern around
  B_EFFECT_OVER   = 7 # is set when some extra effect is over

  ###########
  # Exports #
  ###########

  export        start

  ###########
  # Imports #
  ###########

  macro_import  Stdlib
  macro_import  MathInt
  macro_import  Utils::SinCos
  macro_import  Utils::Shuffle
  label_import  ZXLib::Sys, macros: true
  macro_import  ZXLib::Gfx
  macro_import  ZXUtils::BigFont

  ###########
  # Structs #
  ###########

  # The rendering matrix of the current iteration
  class Rotator < Label
    dx2  word # delta x when moving down/up screen
    dx1  word # delta x when moving right/left screen
    dy2  word # delta y when moving down/up screen
    dy1  word # delta y when moving right/left screen
  end

  # Control structure of the simple zoom & scale.
  class RotateState < Label
    angle byte    # only for simple rotating when B_ROTATE_SIMPLY is set
    scale byte    # only for simple zooming when B_ENABLE_ZOOM and B_ROTATE_SIMPLY is set
    state angle word # union as word
  end

  # Control structure of the advanced random zoom & scale & pan.
  class ValueControl < Label
    frms      byte     # frames counter (left to change target)
    tgt_incr  byte     # target  delta (unsigned)
    cur_incr  byte     # current delta (unsigned)
    vlo       byte     # current value (fractional part)
    vhi       byte     # current value (signed integer part)
    value     vlo word # vlo+vhi union as word
  end

  # Control structure of the "snake" ("street") effect.
  class SnakeControl < Label
    counter   byte # length
    color     byte # current color
    delta     byte # 1, -1, 16, -16
    yx        byte # last row|col
  end

  # class WaveControl < Label
  #   last_note byte
  #   direction byte
  #   current   byte
  # end

  # Control structure of the "scroll text" effect.
  class ScrollControl < Label
    text_cursor word      # current pointer to the text
    color       byte      # last paint color
    bits_view   byte, 2*6 # 16x8 pixel bit view of the scroll (bits being painted onto pattern cells)
    bits        byte      # counter of bits to shift: 0..8
    char_data   byte, 6   # a copy of the next text character shape being scrolled into bits_view
  end

  # Control structure of the "spectrum analyzer" effect.
  class SpectrumControl < Label
    margin0   byte     # polluted space by the updating process
    margin1   byte     # polluted space by the updating process
    data      byte, 16 # 16 data points
    margin2   byte     # polluted space by the updating process
    margin3   byte     # polluted space by the updating process
  end

  # The variables
  class DemoVars < Label
    pattern_lo      byte
    pattern_hi      byte
    pattern         pattern_lo word # target pattern address in the process of replacing the current one
    fgcolor         byte            # pixel grid's current fg color on the 3 most significant bits
    bgcolor         byte            # pixel grid's current bg color on the paper bits (3-5), used by extra_destroy
    at_position     ZXSys::Cursor   # text screen cursor
    general_delay   byte            # general purpose delay counter
    text_delay      byte            # text delay counter
    text_cursor     word            # pointer to the next character to print
    colors_delay    byte            # colors delay counter
    shuffle_state   byte            # current shuffle index
    rotate_flags    byte            # rotation control with B_* flags
    scale_control   ValueControl    # advanced scale control
    angle_control   ValueControl    # advanced angle control
    pattx_control   ValueControl    # advanced pan x control
    patty_control   ValueControl    # advanced pan y control
    snake_control   SnakeControl    # snake control
    rotate_state    RotateState     # simple zoom & scale control
    rotator         Rotator, 2      # 2 rotator matrixes: 1st for left to right and 2nd for right to left
    x1              word            # normalized pan x shift for current iteration
    move_x          word            # simple move delta x
    move_y          word            # simple move delta y
    rotate_delay    byte            # a delay for rotate delta
    rotate_delta    byte            # simple rotate delta
    pattern_bufh    byte            # address (MSB) of the currently rendered pattern
    anim_wait       byte            # animation slowdown counter
    anim_frames     word            # current animation frames address; no animation if 0
    anim_start      word            # restart animation frames address
    seed1           word            # 1st seed for the advanced random rotation control
    seed2           word            # 2nd seed for extra tasks' randomizer
    counter_sync_lo byte            # music counter target (LSB)
    counter_sync_hi byte            # music counter target (MSB)
    counter_sync    counter_sync_lo word
    scroll_ctrl     ScrollControl   # scroll text control
    spectrum        SpectrumControl # spectrum analyzer control
    # chan_a          WaveControl
    # chan_b          WaveControl
    # chan_c          WaveControl
  end

  ##########
  # Layout #
  ##########

  sincos        addr 0xE700, Z80SinCos::SinCos
  pattern1      addr sincos[256]
  pattern2      addr pattern1[256]
  pattern3      addr pattern2[256]
  pattern4      addr pattern3[256]
  pattern6      addr pattern4[256]

  dvar          addr 0xF000, DemoVars
  dvar_end      addr :next, 0
  intr_stk_end  addr 0xF600, 2
  mini_stk_end  addr intr_stk_end[128], 2
  patt_shuffle  addr mini_stk_end[0]
  pattern_buf   addr patt_shuffle[256]      # current pattern data
  pattern_ani1  addr pattern_buf[256]       # animation pattern data
  pattern_ani2  addr pattern_ani1[256]      # animation pattern data
  pattern_ani3  addr pattern_ani2[256]      # animation pattern data
  pattern_ani4  addr pattern_ani3[256]      # animation pattern data
  pattern_ani5  addr pattern_ani4[256]      # animation pattern data
  pattern_ani6  addr pattern_ani5[256]      # animation pattern data
  # wave_control  addr 0, WaveControl

  ##########
  # Macros #
  ##########

  ##
  # The attribute pattern matrix renderer
  #
  # hl - normalized current x:  ssssxxxx. xxxxxxxx
  # de - normalized dx                  ^ fraction point
  # hl' - normalized current y: yyyy.yyyy yyyyyyyy (y-axix has more precision bits)
  # de' - normalized dy             ^ fraction point
  # bc - current screen attributes address
  # b' - current pattern hi byte address
  macro :render_attr do |_, dir:|
                    add  hl, de     # hl: x += dx1
                    ld   a, h       # a: x (hi)
                    exx             # de': dx1, de: dy1, hl': x, hl: y, bc: pattern
                    add  hl, de     # hl: y += dy1
        cstart      ld   c, a       # c: x (hi)
                    xor  h          # a: x (hi) ^ y (hi)
                    anda 0b11110000 # a: ^^^^0000
                    xor  c          # a: yyyyxxxx
                    ld   c, a       # c: yyyyxxxx

                    ld   a, [bc]    # bc: pattern bbbbbbbb yyyyxxxx
                    exx             # de': dy1, hl': y, de: dx1, hl: x, bc: attrs
        case dir 
        when :right
                    inc  c          # next attr col
        when :left
                    dec  c
        else
                    raise ArgumentError, "dir may be :left or :right only, got: #{dir}"
        end
                    ld   [bc], a    # set attr
  end

  ########
  # MAIN #
  ########

  ns :start do
                  exx
                  push hl                   # save hl'

                  di
                  # ld  hl, 42423 # 1952 42422
                  # ld  [vars.seed], hl
                  ld   [save_sp + 1], sp
                  ld   sp, mini_stk_end     # own stack in "fast" mem

                  xor  a
                  call clear_screen

                  call music.init

                  clrmem dvar, +dvar

                  ld  hl, [vars.seed]       # initialize seed
                  ld  [dvar.seed1], hl
                  ld  [dvar.seed2], hl

                  call make_sincos

                  call make_pattern1
                  call make_pattern2
                  call make_pattern3
                  call make_pattern4
                  call make_pattern6
                  call make_figurines

                  xor  a   # ld   a, 256
                  ld   [dvar.shuffle_state], a
                  shuffle_bytes_source_max256 target:patt_shuffle, length:a do
                    call next_rnd2
                    ld   a, l
                  end

                  ld   hl, ludek_anim1
                  ld   [dvar.anim_start], hl
                  call animation.restart

                  # ld   a, pattern_buf >> 8
                  # ld   [dvar.pattern_bufh], a

                  ld   hl, 0x6000
                  # ld   hl, 0x7f00
                  ld   [dvar.rotate_state.state], hl
                  ld   hl, 0x8000
                  ld   [dvar.pattx_control.value], hl
                  ld   [dvar.patty_control.value], hl
                  ld   hl, dvar.angle_control.frms
                  ld   a, 192
                  ld   c, a
                  ld   [hl], a
                  ld   de, +dvar.angle_control
                  add  hl, de
                  sub  c
                  ld   [hl], a # dvar.pattx_control.frms
                  sub  c
                  add  hl, de
                  ld   [hl], a # dvar.patty_control.frms
                  inc  hl      # dvar.patty_control.tgt_incr
                  inc  hl      # dvar.patty_control.cur_incr
                  ld   a, 0x80
                  ld   [hl], a # dvar.patty_control.cur_incr = neutral
                  sbc  hl, de
                  ld   [hl], a # dvar.pattx_control.cur_incr = neutral

                  # ld   a, 0b11011111
                  # ld   a, [vars.seed + 1]
                  # ld   [dvar.fgcolor], a

                  ld   hl, dvar.rotate_flags
                  ld   [hl], 1 << B_ROTATE_SIMPLY

                  memcpy pattern_buf, pattern4, 256

                  # ld   a, [vars.seed]
                  # anda 7
                  # xor  6

                  # ld   a, 2
                  # call extra_colors.set_fg_color

                  ld   hl, dvar.text_delay
                  ld   [hl], 1
                  ld   hl, intro_text
                  ld   [dvar.text_cursor], hl

                  # start rotating
                  setup_custom_interrupt_handler rotate_int

                  ld   hl, extra_text
                  call wait_for_next.set_extra

                  ld   hl, 300
                  call synchronize_music.set_hl
                  ld   hl, ludek_anim1a
                  ld   [dvar.anim_start], hl
                  ld   a, 20
                  call wait_for_next.set_delay
                  ld   hl, ludek_anim2
                  ld   [dvar.anim_start], hl
                  call clearscr
                  ld   hl, 372
                  call synchronize_music.set_hl
                  # ld   a, 15
                  # call wait_for_next.set_delay
                  ld   a, -1
                  ld   [dvar.rotate_delta], a
                  ld   a, 40
                  call wait_for_next.set_delay

                  ld   hl, 128+16
                  ld   [dvar.move_y], hl
                  ld   hl, extra_spin
                  call wait_for_next.set_extra

                  ld   hl, dvar.rotate_flags
                  set  B_ENABLE_ZOOM, [hl]

                  ld   hl, 0x0111
                  ld   [dvar.move_x], hl
                  # ld   hl, 128
                  # ld   [dvar.move_y], hl
                  ld   a, 8
                  call wait_for_next.set_delay
                  ld   hl, 0
                  ld   [dvar.move_x], hl
                  ld   hl, 0x8800
                  ld   [dvar.pattx_control.value], hl
                  ld   a, 60
                  call wait_for_next.set_delay
                  ld   hl, 0
                  ld   [dvar.move_y], hl
                  ld   hl, 0x3800
                  ld   [dvar.patty_control.value], hl
                  ld   a, 28
                  call wait_for_next.set_delay

                  ld   hl, dvar.rotate_flags
                  res  B_ENABLE_ZOOM, [hl]

                  ld   hl, 0
                  ld   [dvar.anim_frames], hl
                  ld   a, pattern_buf >> 8
                  ld   [dvar.pattern_bufh], a
                  ld   hl, dvar.rotate_flags
                  set  B_ENABLE_ZOOM, [hl]

                  ld   hl, extra_unspin
                  call wait_for_next.set_extra

                  # convert current simple rotate angle and scale states to control values
                  ld   hl, dvar.angle_control.tgt_incr
                  ld   [hl], 128+127 # target
                  inc  l
                  ld   [hl], 128-32 # current
                  ld   de, dvar.rotate_state.angle
                  ld   a, [de]      # angle
                  inc  l
                  inc  l
                  ld   [hl], a      # angle_control.vhi = angle
                  inc  de
                  ld   a, [de]      # rotate_state.scale
                  add  a            # convert to control handler cur_incr: scale *= 2
                  jr   NC, skip_negscale
                  rra               # scale < 0 ? scale = -2 * (scale + 1)
                  inc  a
                  neg
                  add  a
    skip_negscale ld   hl, dvar.scale_control.tgt_incr
                  ld   [hl], 255    # target
                  inc  l
                  ld   [hl], a      # current

                  ld   hl, dvar.rotate_flags
                  ld   [hl], 0

                  # ld   hl, title_text
                  # ld   [dvar.text_cursor], hl
                  ld   hl, extra_text
                  call wait_for_next.set_extra

                  ld   a, 80
                  call wait_for_next.set_delay

                  ld   hl, dvar.rotate_flags
                  set  B_RND_PATTERN, [hl]

                  ld   hl, 16<<8|0
                  ld   [dvar.scale_control.frms], hl

                  ld   hl, extra_hide2
                  call wait_for_next.set_extra
  
                  halt
                  ld   a, 0b01010101
                  call alt_clear_scr

                  ld   a, 0b00011111
                  ld   [dvar.fgcolor], a

                  ld   hl, (128-127)<<8|0
                  ld   [dvar.angle_control.frms], hl

                  ld   hl, extra_destroy2
                  call wait_for_next.set_extra

                  ld   hl, (128+127)<<8|128
                  ld   [dvar.angle_control.frms], hl
                  ld   hl, 255<<8|0
                  ld   [dvar.scale_control.frms], hl

                  ld   a, 0b01011111
                  ld   [dvar.fgcolor], a

                  ld   hl, pattern2
                  ld   [dvar.pattern], hl
                  ld   hl, extra_swap2
                  call wait_for_next.set_extra

                  ld   hl, 1429
                  call synchronize_music.set_hl

                  ld   a, 0b00011111
                  ld   [dvar.fgcolor], a

                  ld   hl, extra_colors
                  call wait_for_next.set_extra

                  ld   a, 24
                  call wait_for_next.set_delay

                  ld   a, 0b10111111
                  ld   [dvar.fgcolor], a
                  ld   a, 3
                  call extra_colors.set_fg_color

                  ld   hl, pattern3
                  ld   [dvar.pattern], hl
                  ld   hl, extra_swap2
                  call wait_for_next.set_extra

                  ld   hl, 1801
                  call synchronize_music.set_hl

                  ld   hl, 128<<8|0
                  ld   [dvar.scale_control.frms], hl

                  ld   a, 0b00011111
                  ld   [dvar.fgcolor], a

                  ld   hl, extra_colors
                  call wait_for_next.set_extra

                  ld   a, 24
                  call wait_for_next.set_delay

                  ld   a, 6
                  call extra_colors.set_fg_color

                  ld   a, 24
                  call wait_for_next.set_delay

                  ld   hl, 0<<8|0
                  ld   [dvar.scale_control.frms], hl

                  ld   a, 0b11011111
                  ld   [dvar.fgcolor], a
                  ld   a, 0b00010000
                  ld   [dvar.bgcolor], a
                  ld   hl, extra_destroy2
                  call wait_for_next.set_extra

                  # # ld   hl, 0x8000
                  ld   hl, dvar.rotate_flags
                  res  B_RND_PATTERN, [hl]
                  ld   hl, 0x0000
                  ld   [dvar.pattx_control.value], hl
                  ld   hl, 0xC000
                  ld   [dvar.patty_control.value], hl
                  ld   hl, 0xB000
                  ld   [dvar.scale_control.frms], hl
                  ld   hl, 128<<8|0
                  ld   [dvar.angle_control.frms], hl
                  ld   hl, dvar.rotate_flags
                  res  B_RND_PATTERN, [hl]

                  ld   hl, 3444
                  ld   [dvar.counter_sync], hl
                  ld   hl, extra_spectrum
                  call wait_for_next.set_extra

                  ld   hl, 128+32<<8|240
                  ld   [dvar.angle_control.frms], hl

                  ld   hl, 3959 - 168
                  ld   [dvar.counter_sync], hl
                  call wait_for_next

                  ld   hl, 0x0000
                  ld   [dvar.scale_control.frms], hl
                  ld   hl, dvar.rotate_flags
                  set  B_RND_PATTERN, [hl]
                  ld   hl, 3959
                  ld   [dvar.counter_sync], hl
                  call wait_for_next

                  ld   hl, 0xFF00
                  ld   [dvar.scale_control.frms], hl
                  memcpy pattern_buf, pattern3, 256

                  ld   a, 0
                  call extra_colors.set_fg_clrbrd
                  ld   hl, extra_random
                  call wait_for_next.set_extra
                  call wait_for_next

                  ld   hl, pattern6
                  ld   [dvar.pattern], hl
                  ld   hl, extra_swap_hide2
                  call wait_for_next.set_extra
                  # call wait_for_next.reset

                  ld   hl, 5608
                  ld   [dvar.counter_sync], hl
                  ld   hl, 16<<8|128
                  ld   [dvar.scale_control.frms], hl
                  ld   a, 1
                  ld   [dvar.snake_control.counter], a
                  ld   hl, extra_snake
                  call wait_for_next.set_extra

                  ld   hl, (128+80)<<8|0
                  ld   [dvar.angle_control.frms], hl
                  ld   hl, extra_hide2
                  call wait_for_next.set_extra

                  ld   hl, dvar.rotate_flags
                  res  B_RND_PATTERN, [hl]
                  ld   hl, 128<<8|0
                  ld   [dvar.scale_control.frms], hl
                  ld   hl, (128-8)<<8|0
                  ld   [dvar.angle_control.frms], hl
                  xor  a
                  ld   [dvar.pattx_control.vlo], a
                  ld   [dvar.patty_control.vlo], a

                  memcpy pattern_ani1, pattern_buf, 256*3, reverse: false
                  ld   hl, dvar.scroll_ctrl.bits
                  ld   [hl], 24
                  ld   hl, scroll_text
                  ld   [dvar.scroll_ctrl.text_cursor], hl
                  # ld   [dvar.text_cursor], hl
                  ld   hl, 6328
                  ld   [dvar.counter_sync], hl
                  ld   hl, extra_scroll
                  call wait_for_next.set_extra

                  ld   hl, dvar.rotate_flags
                  set  B_RND_PATTERN, [hl]
                  ld   hl, (128+10)<<8|0
                  ld   [dvar.angle_control.frms], hl
                  ld   hl, 6834 # 6520
                  ld   [dvar.counter_sync], hl
                  call wait_for_next

                  ld   a, pattern_buf >> 8
                  ld   [dvar.pattern_bufh], a
                  memcpy pattern_buf, pattern_ani1, 256

                  ld   hl, pattern1
                  ld   [dvar.pattern], hl
                  ld   hl, extra_swap_hide
                  call wait_for_next.set_extra

                  call clearscr
                  memcpy pattern_buf, pattern1, 256

                  ld   hl, greetz_text
                  ld   [dvar.text_cursor], hl
                  ld   hl, extra_text
                  call wait_for_next.set_extra

                  ld   hl, 7990 #7990 # 7794
                  call synchronize_music.set_hl
                  ld   hl, extra_text
                  call wait_for_next.set_extra

                  ld   hl, 8326
                  call synchronize_music.set_hl
                  ld   hl, extra_text
                  call wait_for_next.set_extra

                  ld   hl, 16<<8|0
                  ld   [dvar.scale_control.frms], hl
                  ld   hl, 128<<8|0
                  ld   [dvar.angle_control.frms], hl

                  ld   hl, 8588
                  call synchronize_music.set_hl

                  xor  a
                  ld   [dvar.bgcolor], a
                  dec  a
                  ld   [dvar.fgcolor], a
                  ld   hl, 255<<8|0
                  ld   [dvar.scale_control.frms], hl
                  ld   hl, 0<<8|0
                  ld   [dvar.angle_control.frms], hl

                  ld   hl, extra_destroy
                  call wait_for_next.set_extra
                  ld   a, 50
                  call wait_for_next.set_delay

    demo_exit     di
                  call music.mute
                  ld   a, 0b00111000
                  call clear_screen
    save_sp       ld   sp, 0                # set above
                  restore_rom_interrupt_handler
                  pop  hl                   # restore hl'
                  exx
                  ld   bc, [vars.seed]
                  ret
  end # :start

  ###############
  # Subroutines #
  ###############

  # Do some *extra* effect work (if possibly) each frame and return when the effect is over.
  ns :wait_for_next do
    wloop       halt
    extra_a     call just_wait
    extra_p     extra_a + 1
                # call rom.break_key
                # jr   NC, start.demo_exit
                ld   hl, dvar.rotate_flags
                bit  B_EFFECT_OVER, [hl]
                jr   Z, wloop
                res  B_EFFECT_OVER, [hl]
                ret
    # Wait for the number of frames given in accumulator.
    set_delay   ld   [dvar.general_delay], a
    # Sets up the just_wait as an extra task and waits.
    reset       ld   hl, just_wait
    # Sets up an extra task to the address given in +hl+ and waits until the effect is over.
    set_extra   ld   [extra_p], hl
                jr   wloop
  end

  # The simplest *extra* task: just waits general_delay iterations.
  just_wait   ld   hl, dvar.general_delay
              dec  [hl]
              ret  NZ
              pop  af
              ret

  # Creates a grid pattern on the pixel screen alternating ~ accumulator each line.
  ns :alt_clear_scr do
                ld   hl, mem.screen
                ld   c, 24
    cloop       ld   b, 256
    clr_loop    ld   [hl], a
                inc  l
                djnz clr_loop
                inc  h
                cpl
                dec  c
                jr   NZ, cloop
                ret
  end

  # Sets the screen attributes to the value given in accumulator and border to paper bits and clears all the pixels.
  clear_screen  clrmem  mem.attrs, mem.attrlen, a
  set_border_cr anda 0b00111000
                3.times { rrca }
                out  (io.ula), a
                call clearscr
                ret

  # Clears the pixel screen.
  ns :clearscr do
                clrmem  mem.screen, mem.scrlen, 0
                ret
  end

  # Returns the next random number in +hl+ from the seed given in +hl+.
  next_rnd      rnd
                ret

  # Returns the next random number in +hl+ from the seed found in +dvar.seed2+. Updates +dvar.seed2+.
  next_rnd2     ld  hl, [dvar.seed2]
                call next_rnd
                ld  [dvar.seed2], hl
                ret

  # Creates the full sin/cos table from the minimal sinus table base.
  make_sincos   create_sincos_from_sintable sincos, sintable:sintable

  # Forward to +ix+. Call it to emulate: +call ix+.
  forward_ix    jp   (ix)

  # Returns the next random (pre-shuffled) pattern_buf cell address.
  # Sets ZF:1 when the shuffle cycle ends (all cells has been visited).
  x_shuffle     ld   hl, dvar.shuffle_state
                inc  [hl]
                ld   l, [hl]
                ld   h, patt_shuffle >> 8
                ld   l, [hl]             # pattern index: $00-$FF
                ld   h, pattern_buf >> 8 # the full pattern address
                ret

  # Outputs 16x15 anti-aliased character from the 8x8 font.
  #
  # a' - character to print
  # d - a vertical row (0-177) to start printing at
  # e - a byte column (0-30) to start printing at
  print_big_chr ytoscr d, col:e, t:c
                ld   c, 8             # 8 source character lines
                exx                   # save screen address and height
                ex   af, af           # restore code
                                      # yep, you can customize font by changing CHARS
                char_ptr_from_code([vars.chars], a, tt:de)
                enlarge_char8_16 compact:false, over: :or, scraddr:nil, assume_chars_aligned:true
                ret

  # Updates the randomized zoom/scale/pan variables and returns the current value.
  #
  # hl: -> ValueControl to update
  # CF: mode - 0: delta+stable frames, 1: current only+random frames
  # preserves: af
  # out: de if delta, a' if current
  ns :control_value do
                  ex   af, af  # save mode
                  dec  [hl]    # frms
                  jr   Z, change_target
                  inc  l
                  ld   c, [hl] # tgt_incr
    continue      inc  l
                  ld   a, [hl] # cur_incr
                  cp   c       # tgt - cur
                  jr   Z, in_target # tgt == cur
                  ld   c, a    # cur_incr
                  ccf
                  sbc  a       # dir: 0 if tgt > cur, -1 if tgt < cur
                  ora  1       # dir: 1 if tgt > cur, -1 if tgt < cur
                  add  c       # a: cur += dir
                  ld   [hl], a # a: cur_incr
    in_target     ex   af, af
                  ret  C       # a' current value
    delta         ex   af, af
                  sub  0x80    # delta = 8 * (cast cur as i16 - 128)
                  add  a       # cur *= 2
                  ld   c, a    # c: cur (lo)
                  sbc  a       # a: if cur >= 0 then 0 else -1
                  sla  c       # cur *= 2
                  rla
                  sla  c       # cur *= 2
                  rla
                  ld   b, a    # b: cur (hi), bc: delta
                  inc  l
                  ld   e, [hl] # vlo
                  inc  l
                  ld   d, [hl] # vhi
                  ex   de, hl
                  add  hl, bc  # value += delta
                  ex   de, hl
                  ld   [hl], d # vhi
                  dec  l
                  ld   [hl], e # vlo
                  ex   af, af
                  ret          # updated value in de

    change_target push hl
                  ld  hl, [dvar.seed1]
                  call next_rnd
                  ld  [dvar.seed1], hl
                  ex   de, hl  # de=rnd()
                  pop  hl
                  ex   af, af
                  jr   NC, stable_frames
                  set  6, d
                  ld   [hl], d # frms
    stable_frames ex   af, af
                  inc  l
                  ld   [hl], e # tgt_incr
                  ld   c, e
                  jp   continue
  end

  ###############
  # Render task #
  ###############

  with_saved :rotate_int, :all_but_ixiy, :exx, :ex_af, :all_but_ixiy, ret: :after_ei do
                  ld   [save_sp_p], sp
                  # ld   a, 1; out  (254), a

    # Renders the lower half of the screen from the center right and downwards and left and so on.
    # Current rotation matrixes:
    #     [0]   [1]
    #    dx2   dx2
    #   -dx1   dx1
    #    dy2   dy2
    #   -dy1   dy1
    if FULL_SCREEN_MODE == :center || !FULL_SCREEN_MODE
                  ld   a, 6
    else
                  ld   a, 7
    end
                  ex   af, af
    if FULL_SCREEN_MODE == :center
                  ld   bc, mem.attrs + 32*11 + 15 # center of attrs
    else
                  ld   bc, mem.attrs + 32*10 + 15 # center of attrs
    end
                  ld   hl, [dvar.x1] # pattern_x shift as a fraction (-0.5)...(0.5) normalized
                  ld   sp, dvar.rotator[1].dx1
                  pop  de         # de: rotator.dx1
                  ld   a, h       # a: x (hi)
                  exx
                  ld   hl, dvar.pattern_bufh
                  ld   b, [hl]
                  ld   hl, [dvar.patty_control.value] # pattern_y shift as a fraction (-0.5)...(0.5)
                  pop  de         # de: rotator.dy2 (discard)
                  pop  de         # de: rotator.dy1
                  jp   center_attr.cstart

    tloop1        ex   af, af
                  ld   a, 31
                  add  c
                  ld   c, a       # end of line
                  inc  bc         # next line (begin of line)

                  pop  de         # rotator.dx2
                  add  hl, de     # hl: x += dx2
                  pop  de         # rotator.dx1
                  ld   a, h       # a: x (hi)
                  exx             # de': dx1, bc: pattern
                  pop  de         # rotator.dy2
                  add  hl, de     # hl: y += dy2
                  pop  de         # rotator.dy1
                  ld   c, a       # c: x (hi)
                  xor  h          # a: x (hi) ^ y (hi)
                  anda 0b11110000 # a: ^^^^0000
                  xor  c          # a: yyyyxxxx
                  ld   c, a       # c: yyyyxxxx

                  ld   a, [bc]    # bc: pattern bbbbbbbb yyyyxxxx
                  exx             # de': dy1, hl': y, de: dx1, hl: x, bc: attrs
                  ld   [bc], a    # set attr

    15.times do
                  render_attr dir: :right
    end
    center_attr   render_attr dir: :right
    15.times do
                  render_attr dir: :right
    end
                  inc  bc         # next line (begin of line)
                  ld   a, 31
                  add  c  
                  ld   c, a       # next line (end of line)

                  ld   sp, dvar.rotator[0]
                  pop  de         # rotator.dx2
                  add  hl, de     # hl: x += dx2
                  pop  de         # rotator.ndx1
                  ld   a, h       # a: x (hi)
                  exx             # de': ndx1, bc: pattern
                  pop  de         # rotator.dy2
                  add  hl, de     # hl: y += dy2
                  pop  de         # rotator.ndy1
                  ld   c, a       # c: x (hi)
                  xor  h          # a: x (hi) ^ y (hi)
                  anda 0b11110000 # a: ^^^^0000
                  xor  c          # a: yyyyxxxx
                  ld   c, a       # c: yyyyxxxx

                  ld   a, [bc]    # bc: pattern bbbbbbbb yyyyxxxx
                  exx             # de': dy1, hl': y, de: dx1, hl: x, bc: attrs
                  ld   [bc], a    # set attr
    31.times do
                  render_attr dir: :left
    end
                  ex   af, af
                  dec  a          # lines -= 1
                  jp   NZ, tloop1 # tloop1 if lines != 0

    # The lower half is rendered, waste some time on music
                  # ld   a, 5; out  (254), a
                  ld   sp, intr_stk_end
                  call music.play

    # Forward animation if active
                  call animation

    # Now progress rotate, scale and panning.
                  ld   a, [dvar.rotate_flags]
                  # out  (254), a
                  rra  # B_ROTATE_SIMPLY
                  jr   NC, update_ctrls
    # Simple panning x-wise
                  ld   hl, [dvar.move_x]
                  ld   sp, dvar.pattx_control.value
                  pop  bc
                  add  hl, bc
                  push hl
    # Simple panning y-wise
                  ld   hl, [dvar.move_y]
                  ld   sp, dvar.patty_control.value
                  pop  bc
                  add  hl, bc
                  push hl
    # Simple rotating
                  # angle 0 - 255, scale 0-255 (1.0)
                  # c = angle (0..255), b = scale 0..7f
                  # prepare_rotator
                  ld   sp, dvar.rotate_state.state
                  pop  bc # state: c = angle (0..255), b = scale 0..7f

                  # rra  # B_ENABLE_ROTATE
                  # jr   NC, skip_rotate
                  ex   af, af
                  ld   a, [dvar.rotate_delta]
                  add  c
                  ld   c, a
                  ex   af, af
                  # dec  c  # rotate
    # Simple zooming
    skip_rotate   rra  # B_ENABLE_ZOOM
                  sbc  a, a
                  add  b
                  ld   b, a
                  # dec  b  # scale
                  push bc
                  jp   P, skip_rot_adj # scale >= 0
                  xor  a  # scale < 0 ? scale = - (scale + 1)
                  inc  b  # scale + 1
                  sub  b  # a = 0 - (scale + 1)
                  ld   b, a
                  jr   skip_rot_adj

    # Advanced rotating, zooming and panning.
    update_ctrls  rra  # B_RND_PATTERN
                  jr   NC, skip_patt_ct
    # Advanced panning
                  ld   hl, dvar.patty_control
                  ora  a             # CF = 0
                  call control_value
                  ld   hl, dvar.pattx_control
                  call control_value # CF = 0 preserved
    # Advanced rotating
    skip_patt_ct  ld   hl, dvar.angle_control
                  ora  a             # CF = 0
                  call control_value
                  ld   a, d          # angle from vhi
    # Advanced zooming
                  ld   hl, dvar.scale_control
                  scf                # CF = 1
                  call control_value
                  ld   c, a          # angle
                  ex   af, af        # curr in a'
                  srl  a
                  ld   b, a          # scale = curr / 2
                  cp   4             # scale >= 4 ? skip_rot_adj
                  jr   NC, skip_rot_adj
                  ld   b, 4          # scale = 4

    # Calculate:
    #
    # x1:  (256*(-(a/16.0)-(dx1 * xs) - (dx2 * ys))).truncate,
    # y1:  (256*16*(8-(dy1 * xs) - (dy2 * ys))).truncate,
    # dx1: (scale*Math.cos(angle) * 256).truncate,
    # dy1: (scale*Math.sin(angle) * 256 * 16).truncate,
    # dx2: (scale*-Math.sin(angle) * 256).truncate,
    # dy2: (scale*Math.cos(angle) * 256 * 16).truncate
    skip_rot_adj  ld   a, c          # angle
                  sincos_from_angle sincos, h, l
                  ld   sp, hl        # hl: address of SinCos entry from an angle in a (256 based)
                  pop  de            # sin(angle)
                  ld   a, b          # scale
                  mul8 d, e, a, tt:de, clrhl:true, double:false # sin(angle) * scale
                  ld   a, b          # scale
                  exx                # hl': sin(angle) * scale
                  pop  de            # cos(angle)
                  mul8 d, e, a, tt:de, clrhl:true, double:false # cos(angle) * scale
                                     # hl: cos(angle) * scale
                  ld   a, l          # dx1: normalize cos(angle) * scale
                  ld   e, h
                  add  a             # llllllll -> CF: l a: lllllll0
                  rl   e             # shhhhhhh -> CF: s e: hhhhhhhl
                  sbc  a             # a: ssssssss
                  ld   d, a          # de: dx1 = sssssssshhhhhhhl

                  ld   a, l          # dy2: normalize cos(angle) * scale
                3.times do           # shhhhhhhllllllll -> sssshhhhhhhlllll
                  sra h              # y axis has better angle resolution
                  rra                # but it's only visible when extremally zoomed in
                end
                  ld   l, a          # hl: dy2 = sssshhhhhhhlllll
    # Set rotate matrixes:
    #  [0]  [1]
    # -dx2 -dx2
    # -dx1  dx1 
    # -dy2 -dy2
    # -dy1  dy1 
                  exx             # hl: sin(angle) * scale

                  ld   a, l       # -dx2: normalize sin(angle) * scale
                  ld   e, h
                  add  a          # llllllll -> CF: l e: lllllll0
                  rl   e          # shhhhhhh -> CF: s a: hhhhhhhl
                  sbc  a          # a: ssssssss
                  ld   d, a       # de: -dx2 = sssssssshhhhhhhl

                  ld   a, l       # dy1: normalize sin(angle) * scale
                3.times do        # shhhhhhhllllllll -> sssshhhhhhhlllll
                  sra  h          # y axis has better angle resolution
                  rra             # but it's only visible when extremely zoomed in
                end
                  ld   l, a       # hl: dy1 = sssshhhhhhhlllll

                  ld   sp, dvar.rotator[2]
                  push hl         # rotator[1].dy1 = dy1
                  exx
                  neg16 h, l      # -dy2
                  push hl         # rotator[1].dy2 = -dy2
                  push de         # rotator[1].dx1 = dx1
                  exx
                  push de         # rotator[1].dx2 = -dx2
                  neg16 h, l      # -dy1
                  push hl         # rotator[0].dy1 = -dy1
                  exx
                  push hl         # rotator[0].dy2 = -dy2
                  neg16 d, e      # -dx1
                  push de         # rotator[0].dx1 = -dx1
                  exx
                  push de         # rotator[0].dx2 = -dx2
                  exx             # de: -dx1
    # Calculate x1
                  ld   hl, [dvar.pattx_control.value] # pattern_x shift as a fraction (-0.5)...(0.5)
                  ld   a, l       # normalize to match x
                4.times do        # shhhhhhhllllllll -> ssssshhhhhhhhlll
                  sra  h
                  rra
                end
                  ld   l, a
    # Save x1 for the next render iteration (lower half).
                  ld   [dvar.x1], hl # pattern_x shift as a fraction (-0.5)...(0.5) normalized

    # Renders the upper half of the screen from the center left and upwards and right and so on.
                  ld   a, 6
                  # out  (254), a
                  ex   af, af
    if FULL_SCREEN_MODE == :center
                  ld   bc, mem.attrs + 32*11 + 16 # center of attrs
    else
                  ld   bc, mem.attrs + 32*10 + 16 # center of attrs
    end
                  add  hl, de     # hl: x -= dx1
                  ld   a, h       # a: x (hi)
                  exx
                  ld   hl, dvar.pattern_bufh
                  ld   b, [hl]
                  ld   hl, [dvar.patty_control.value] # pattern_y shift as a fraction (-0.5)...(0.5)

                  ld   sp, dvar.rotator[0].dy1
                  pop  de         # de: rotator.ndy1
                  add  hl, de     # hl: y -= dy1
                  jp   center_att2.cstart

    tloop2        ex   af, af
                  dec  bc         # prev line (end of line)
                  ld   a, c
                  sub  31
                  ld   c, a       # prev line (begin of line)

                  pop  de         # rotator.ndx2
                  add  hl, de     # hl: x -= dx2
                  pop  de         # rotator.dx1
                  ld   a, h       # a: x (hi)
                  exx             # de': ndx1, bc: pattern
                  pop  de         # rotator.ndy2
                  add  hl, de     # hl: y -= dy2
                  pop  de         # rotator.dy1
                  ld   c, a       # c: x (hi)
                  xor  h          # a: x (hi) ^ y (hi)
                  anda 0b11110000 # a: ^^^^0000
                  xor  c          # a: yyyyxxxx
                  ld   c, a       # c: yyyyxxxx

                  ld   a, [bc]    # bc: pattern bbbbbbbb yyyyxxxx
                  exx             # de': dy1, hl': y, de: dx1, hl: x, bc: attrs
                  ld   [bc], a    # set attr

      31.times do
                  render_attr dir: :right
      end
                  ld   a, c
                  sub  31  
                  ld   c, a       # begin of line
                  dec  bc         # prev line (end of line)

                  ld   sp, dvar.rotator[0]
                  pop  de         # rotator.ndx2
                  add  hl, de     # hl: x -= dx2
                  pop  de         # rotator.ndx1
                  ld   a, h       # a: x (hi)
                  exx             # de': -dx1, bc: pattern
                  pop  de         # rotator.ndy2
                  add  hl, de     # hl: y -= dy2
                  pop  de         # rotator.ndy1
                  ld   c, a       # c: x (hi)
                  xor  h          # a: x (hi) ^ y (hi)
                  anda 0b11110000 # a: ^^^^0000
                  xor  c          # a: yyyyxxxx
                  ld   c, a       # c: yyyyxxxx

                  ld   a, [bc]    # bc: pattern bbbbbbbb yyyyxxxx
                  exx             # de': -dy1, hl': y, de: -dx1, hl: x, bc: attrs
                  ld   [bc], a    # set attr
      15.times do
                  render_attr dir: :left
      end
    center_att2   render_attr dir: :left
      15.times do
                  render_attr dir: :left
      end
                  ex   af, af
                  dec  a          # lines -= 1
                  jp   NZ, tloop2 # tloop2 if lines != 0

  # Prepare the rotation matrixes for the lower half on the next iteration:
  #  [0]  [1]     [0]  [1]
  # -dx2 -dx2 ->  dx2  dx2
  # -dx1  dx1 -> -dx1  dx1 
  # -dy2 -dy2 ->  dy2  dy2
  # -dy1  dy1 -> -dy1  dy1 
                  pop  hl         # -rotator[1].dx2
                  neg16 h, l
                  push hl         # rotator[1].dx2
                  ld   [dvar.rotator[0].dx2], hl
                  ld   sp, dvar.rotator[1].dy2
                  pop  hl         # -dy2
                  neg16 h, l
                  push hl
                  ld   [dvar.rotator[0].dy2], hl

    save_sp_a     ld   sp, 0      # restore sp
    save_sp_p     save_sp_a + 1
                  # xor  a; out  (254), a
  end # ei; ret

  ###########
  # Effects #
  ###########

  # The "crazy spin" effect.
  ns :extra_spin do
                  ld   hl, dvar.rotate_delay
                  ld   a, 64
                  add  [hl]
                  ld   [hl], a
                  ret  NC
                  inc  hl      # dvar.rotate_delta
                  dec  [hl]
                  ld   a, [hl]
                  cp   -65
                  ret  NZ
                  jr   signal_next
  end

  # The "brake spin" effect.
  ns :extra_unspin do
                  ld   hl, dvar.rotate_delta
                  inc  [hl]
                  ld   a, [hl]
                  cp   -1
                  ret  NZ
                  jr   signal_next
  end

  # The "cycle ink and border colors to the rhythm" effect.
  ns :extra_colors do
                  ld   hl, dvar.fgcolor
                  inc  [hl]             # increase color's fraction
                  jr   NZ, apply        # 0 ? end of effect
                  ld   de, signal_next
                  push de               # exit via signal_next
    apply         ld   a, [hl]          # dvar.fgcolor
                  anda 0b00011111
                  ret  NZ               # return unless color's fraction is 0
                  ld   a, [hl]          # dvar.fgcolor
                  add  32-24            # adjust fraction by 0.25
                  ld   [hl], a          # dvar.fgcolor
                  anda 0b11100000       # bits 5-7 are paper and border color
                  3.times { rlca }      # color on ink bits 0-2
    set_fg_clrbrd out (io.ula), a       # set border color
                  ld   c, a
                  3.times { rlca }
                  ora  c                # a: paper bits 3-5 = ink bits 0-2
                                        # optionally set the margin rows' attributes to match the border color
    if FULL_SCREEN_MODE == :center      # upper and lower row
                  ld   hl, mem.attrs
                  cp   [hl]             # update only if different
                  jr   Z, set_fg_color
                  clrmem hl, 32, a
                  clrmem mem.attrs + mem.attrlen - 32, 32, a
    elsif !FULL_SCREEN_MODE             # 2 bottom rows
                  ld   hl, mem.attrs + mem.attrlen - 64
                  cp   [hl]             # update only if different
                  jr   Z, set_fg_color
                  clrmem hl, 64, a
    end

    # Sets ink color of all of the pattern_buf cells.
    # Assumes all of the pattern cells has the same ink bits.
    # a: ink bits 0-2
    set_fg_color  ld   hl, pattern_buf
                  xor  [hl]             # diff bits
                  anda 0b00000111       # check the ink bits only
                  ret  Z                # return if no change needed
                  ld   b, 256           # counter
                  ld   c, a             # copy diff bits
    invloop       ld   a, [hl]          # get the pattern cell
                  xor  c                # apply diff bits
                  ld   [hl], a          # set the pattern cell
                  inc  l                # next cell
                  djnz invloop
                  ret
  end

  # Sets signal "effect is over" for the wait_for_next routine.
  ns :signal_next do
                  ld   hl, dvar.rotate_flags
                  set  B_EFFECT_OVER, [hl]
                  ret
  end

  # Signal the effect is over if the music counter reaches dvar.counter_sync
  ns :synchronize_music do
                  ld   de, music.music_control.counter_hi
                  ld   hl, dvar.counter_sync_hi
                  ld   a, [de]
                  cp   [hl]
                  ret  C
                  jr   NZ, signal_next
                  dec  de
                  dec  hl
                  ld   a, [de]
                  cp   [hl]
                  ret  C
                  jp   signal_next

    # Sets dvar.counter_sync and waits until music reaches the given counter.
    # hl: a value to set counter_sync to
    set_hl        ld   [dvar.counter_sync], hl
                  ld   hl, synchronize_music
                  jp   wait_for_next.set_extra
  end

  # The "write text" effect.
  ns :extra_text do
                  ld   hl, dvar.text_delay
                  dec  [hl]                         # decrease effect's counter
                  ret  NZ                           # delay printing
                  ld   [hl], 3                      # dvar.text_delay = 3
                  ld   hl, [dvar.text_cursor]       # character's address
                  ld   de, [dvar.at_position]       # screen cursor position
    next_char     ld   a, [hl]                      # a: text character
                  inc  hl                           # next character's address
                  ora  a
                  jp   M, check_control             # a >= 128 control character
                  ld   [dvar.text_cursor], hl       # save the address of the next text character
                  jr   Z, signal_next               # a == 0 ? all text written, effect is over
                  cp   32
                  jr   C, handle_wait               # a < 32 ? set delay
                  ex   af, af                       # a': character to print
                  ld   a, e                         # cursor column (0..30)
                  add  2                            # increase by 2
                  ld   [dvar.at_position.column], a # save cursor position
                  jp   print_big_chr                # exit via print
    check_control cp   0xF0
                  jr   C, handle_pos                # a < 0xF0 ? move cursor
                  ld   [dvar.text_cursor], hl       # save the address of the next text character
                  cp   0xFF                         # a = 0xFF ? clear pixel screen
                  jp   Z, clearscr                  # exit via clearscr
    handle_other  cp   0xF8
                  jr   NZ, handle_color
                  ld   a, -2                        # a = 0xF8 ? back space
                  add  e
                  anda 31
                  ld   e, a                         # cursor = cursor - 2
                  jr   save_position
    handle_color  anda 0x07                         # set ink color to bits 0-2
                  jp   extra_colors.set_fg_color    # exit via set_fg_color
    handle_pos    anda 0x1F                         # move the screen cursor to the given position
                  ld   e, a                         # column in bits 0-4
                  ld   d, [hl]                      # line number in the following code
                  inc  hl                           # next character's address
    save_position ld   [dvar.at_position], de       # save cursor position
                  jr   next_char                    # process the next text character
    handle_wait   add  a
                  add  a
                  add  a
                  ld   [dvar.text_delay], a         # set the delay to code * 8
                  ret
  end

  # The "random ink color stripes" effect.
  ns :extra_random do
                  ld   hl, dvar.colors_delay
                  dec  [hl]                   # decrease effect's counter
                  jr   NZ, apply              # 0 ? end of effect
                  ld   de, signal_next
                  push de                     # exit via signal_next
    apply         ld   a, [hl]                # a: counter value
                  anda 3
                  ret  NZ                     # render once each 4 counter ticks
                  call next_rnd2              # hl: next random number $0000-$ffff
                  ld   a, h                   # a: next random number (bits 8-15)
                  ld   h, pattern_buf >> 8    # h: pattern_buf MSB, l: random cell index $00-$ff
                  anda 0b00000111             # a: crop random number to ink color
                  jr   NZ, not_black
                  ld   a, 7                   # set to white if black
    not_black     ld   c, a                   # c: random ink color 1..7
                  ld   b, 16                  # b: row counter
                  ld   e, 15                  # next line increment - 1
                  res  0, l                   # only even columns
                  ld   d, 0b11111000          # d: attributes mask
    loop0         ld   a, [hl]                # get cell
                  anda d                      # clear ink bits 0-2
                  ora  c                      # merge ink bits
                  ld   [hl], a                # even cell
                  inc  l                      # next column
                  # ld   a, [hl]
                  # anda d
                  # ora  c
                  ld   [hl], a                # odd cell
                  ld   a, e
                  add  l
                  ld   l, a                   # next row
                  djnz loop0
                  ret
  end

  # The random "snake" (or "streets") effect.
  ns :extra_snake do
                  ld   hl, dvar.snake_control.counter
                  dec  [hl]                   # decrease snake's counter
                  jr   Z, next_dir_rnd        # change direction when counter = 0
                  ld   a, [hl]                # get counter
                  anda 0b00000001             # check lowest bit
                  jr   NZ, skip_drawing       # draw every 2nd tick
                  inc  hl                     # -> snake_control.color
                  ld   c, [hl]                # c: color
                  inc  hl                     # -> snake_control.delta
                  ld   a, [hl]                # a: delta
                  inc  hl                     # -> snake_control.yx
                  add  [hl]                   # yx += delta
                  ld   [hl], a                # save yx
                  ld   l, a                   # l: cell index
                  ld   h, pattern_buf >> 8    # hl: cell address
                  ld   a, [hl]                # get cell
                  anda 0b11111000             # clear ink
                  ora  c                      # set ink
                  ld   [hl], a                # put cell
    skip_drawing  jp   synchronize_music      # exit via music counter check
                                              # select new direction and color
    next_dir_rnd  push hl                     # save -> snake_control.counter
                  call next_rnd2              # hl: next random number $0000-$ffff
                  ex   de, hl                 # de: rnd
                  pop  hl                     # -> snake_control.counter
                  ld   a, d
                  anda 0b00011111
                  ora  3
                  ld   [hl], a                # snake_control.counter = (rnd >> 8) & 31 | 3
                  inc  hl                     # -> snake_control.color
                  ld   a, e
                  2.times { rrca }
                  anda 0b00000111
                  ld   [hl], a                # snake_control.color = (rnd >> 2) & 7
                  inc  hl                     # -> snake_control.delta
    select(directions & 0xFF){|v| v < (256 - 4) }.then do
                  ld   bc, directions
                  ld   a, e
                  anda 3
                  add  c
                  ld   c, a
    end.else do
      raise "sanity error: directions should not cross the 256 byte page boundary"
    end
                  ld   a, [bc]
                  ld   [hl], a                # snake_control.delta = [directions[rnd & 3]]
                  ret

    directions    db -1, 1, -16, 16
  end

  # 2 * extra_hide.
  ns :extra_hide2 do
                  call extra_hide
  end
  # Set cells' ink color to cells' paper color randomly cell by cell.
  ns :extra_hide do
                  call x_shuffle       # hl: random pattern cell address
                  jr   NZ, apply       # ZF=1 ? that was the last one
                  ld   de, signal_next # the effect is over
                  push de              # return via signal_next
    apply         ld  a, [hl]          # get cell
    # Sets the attribute cell at +hl+ to ink and paper color from the paper color in accumulator.
    hide_color    ld  c, a
                  3.times { rrca }
                  xor c
                  anda 0b00000111
                  xor c                # 0b__ppp___ -> 0b__pppppp
                  ld  [hl], a          # put cell
                  ret
  end

  # 2 * extra_swap_hide.
  ns :extra_swap_hide2 do
                  call extra_swap_hide
  end
  # Replace cells with the pattern at dvar.pattern and set ink color to paper's, randomly cell by cell.
  ns :extra_swap_hide do
                  call x_shuffle       # hl: random pattern cell address
                  jr   NZ, apply       # ZF=1 ? that was the last one
                  ld   de, signal_next # the effect is over
                  push de              # return via signal_next
    apply         ld   a, [dvar.pattern_hi]
                  ld   d, a
                  ld   e, l
                  ld   a, [de]         # get the target pattern cell
                  jr   extra_hide.hide_color
  end

  # Replace cells' ink color with dvar.fgcolor randomly cell by cell.
  ns :extra_show do
                  call x_shuffle       # hl: random pattern cell address
                  jr   NZ, apply       # ZF=1 ? that was the last one
                  ld   de, signal_next # the effect is over
                  push de              # return via signal_next
    apply         ld   a, [hl]         # get cell
    # Sets the attribute cell at +hl+ to paper color from the accumulator and to ink color from dvar.fgcolor.
    mix_fg_color  anda  0b11111000
                  ld   c, a
                  ld   a, [dvar.fgcolor]
                  anda 0b11100000
                  3.times { rlca }
                  ora  c
                  ld   [hl], a         # put cell
                  ret
  end

  # 2 * extra_swap.
  ns :extra_swap2 do
                  call extra_swap
  end
  # Replace cells with the pattern at dvar.pattern and set ink color to dvar.fgcolor, randomly cell by cell.
  ns :extra_swap do
                  call x_shuffle       # hl: random pattern cell address
                  jr   NZ, apply       # ZF=1 ? that was the last one
                  ld   de, signal_next # the effect is over
                  push de              # return via signal_next
    apply         ld   a, [dvar.pattern_hi]
                  ld   d, a
                  ld   e, l
                  ld   a, [de]         # get the target pattern cell
                  jr   extra_show.mix_fg_color
  end

  # 2 * extra_destroy.
  ns :extra_destroy2 do
                  call extra_destroy
  end
  # Replace cells' paper color with dvar.bgcolor and the ink color with dvar.fgcolor, randomly cell by cell.
  ns :extra_destroy do
                  call x_shuffle       # hl: random pattern cell address
                  jr   NZ, apply       # ZF=1 ? that was the last one
                  ld   de, signal_next # the effect is over
                  push de              # return via signal_next
    apply         ld   a, [dvar.bgcolor]
                  jr   extra_show.mix_fg_color
  end

  # ns :extra_wave do
  #                 ld   a, [music.music_control.counter]
  #                 rrca
  #                 jr   C, upper
  #                 ld   de, pattern_buf | 0x00
  #                 ld   hl, pattern_buf | 0x10
  #                 ld   bc, 0x70
  #                 ldir
  #                 jp   no_upper
  #   upper         ld   de, pattern_buf | 0xFF
  #                 ld   hl, pattern_buf | 0xEF
  #                 ld   bc, 0x70
  #                 lddr
  #   no_upper      ld   l, 0x70
  #                 ld   bc, 32<<8|0b00001000
  #   dloop         ld   a,  [hl]
  #                 sub  c
  #                 jr   NC, skip0
  #                 xor  a
  #   skip0         ld   [hl], a
  #                 inc  l
  #                 djnz dloop
  #                 ld   hl, dvar.chan_a
  #                 exx
  #                 ld   de, music.music_control.chan_a.current_note
  #                 # ld   bc, music.music_control.ay_registers.volume_a
  #                 ld   bc, music.music_control.chan_a.volume_envelope.current_value
  #                 ld   h, 0b01001001
  #                 call mixvol
  #                 ld   hl, dvar.chan_b
  #                 exx
  #                 ld   de, music.music_control.chan_b.current_note
  #                 # ld   bc, music.music_control.ay_registers.volume_b
  #                 ld   bc, music.music_control.chan_b.volume_envelope.current_value
  #                 ld   h, 0b01010010
  #                 call mixvol
  #                 ld   hl, dvar.chan_c
  #                 exx
  #                 ld   de, music.music_control.chan_c.current_note
  #                 # ld   bc, music.music_control.ay_registers.volume_c
  #                 ld   bc, music.music_control.chan_c.volume_envelope.current_value
  #                 ld   h, 0b01100100
  #   mixvol        ld   a, [de]
  #                 exx
  #                 cp   [hl]    # last_note
  #                 jr   NZ, set_direction
  #                 inc  hl      # direction
  #                 jr   same_note
  #   set_direction ld   [hl], a # last_note
  #                 sbc  a, a
  #                 ora  1
  #                 inc  hl      # direction
  #                 ld   [hl], a # direction
  #   same_note     ld   a, [hl] # direction
  #                 inc  hl      # current
  #                 add  [hl]    # current
  #                 ld   [hl], a # current
  #                 exx
  #                 anda 0x0F
  #                 add  0x70
  #                 ld   l, a
  #                 ld   a, [bc]
  #                 srl  a
  #                 # add  a, a
  #                 # sbc  a, a
  #                 anda h
  #                 ld   h, pattern_buf >> 8
  #                 ora  [hl]
  #                 ld   [hl], a
  #                 ex   af, af
  #                 ld   a, l
  #                 add  0x10
  #                 ld   l, a
  #                 ex   af, af
  #                 ld   [hl], a
  #                 ret
  # end

  # The "scroll text" effect.
  ns :extra_scroll do
                  ld   hl, dvar.scroll_ctrl.color
                  inc  [hl]                   # ++color
                  ld   a, [hl]
                  inc  hl                     # -> scroll_ctrl.bits_view
                  anda 0b00000101
                  ora  0b00000001
                  ld   c, a                   # c: color & 0b101 | 1
    # paint bits view onto the pattern cells
    set_buf_a     ld   de, pattern_buf | 0x10 # de: target pattern address
    set_buf_p_hi  set_buf_a + 2
    cloop         ld   a, [hl]                # a: [scroll_ctrl.bits_view]
                  inc  l                      # -> scroll_ctrl.bits_view++
                  scf
                  rla                         # CF <- a <- 1 (adds marker bit)
                  ld   b, a
    bloop         jr   NC, copy_color         # CF=0 ? copy ink color
    put_color     ld   a, [de]                # CF=1 ? set ink color
                  anda 0b11111000
                  ora  c
                  ld   [de], a                # put cell
                  inc  e                      # next column
                  sla  b                      # CF <- b <- 0
                  jr   Z, exit_bloop          # b=0 ? exit rendering
                  jr   C, put_color           # CF=1 ? set ink color
    copy_color    inc  d                      # de: background pattern page address
                  ld   a, [de]                # get cell
                  dec  d                      # de: target pattern address
                  ld   [de], a                # put cell
                  inc  e                      # next column
                  sla  b                      # CF <- b <- 0
                  jr   NC, copy_color         # CF=0 ? copy ink color
                  jr   NZ, put_color          # b<>0 ? set ink color
    exit_bloop    ld   a, e
                  cp   0x10 + 0x60
                  jr   C, cloop               # repeat until all character lines has been painted
    # swap pattern buffers
                  ld   a, d
                  ld   [dvar.pattern_bufh], a # set the painted pattern for rendering
                  xor  2
                  ld   [set_buf_p_hi], a      # set the shadow pattern for painting
    # left scroll each 16 bits of bits_view and populate rightmost bits from the char_data
                  ld   b, 6                   # b: line counter
                  ld16 de, hl                 # de: -> dvar.scroll_ctrl.bits
                  ld   a, l
                  add  b
                  ld   l, a                   # hl: -> dvar.scroll_ctrl.char_data[b]
    rloop         sla  [hl]                   # CF <- [char_data--] <- 0
                  dec  l
                  ex   de, hl
                  dec  l
                  rl   [hl]                   # CF <- [--bits_view] <- CF
                  dec  l
                  rl   [hl]                   # CF <- [--bits_view] <- CF
                  ex   de, hl
                  djnz rloop
                                              # hl: -> dvar.scroll_ctrl.bits
                  dec  [hl]                   # bits -= 1
                  jr   NZ, sync_focus         # still some bits left ? skip next character copy
    # copy the shape of the next character to dvar.scroll_ctrl.char_data
    copy_chr      ld   [hl], 8                # dvar.scroll_ctrl.bits = 8
                  ld   hl, [dvar.scroll_ctrl.text_cursor]
    read_char     ld   a, [hl]                # a: character code
                  ora  a
                  jr   Z, reset_text          # 0 ? reset text pointer
                  inc  hl                     # -> next character code address
                  ld   [dvar.scroll_ctrl.text_cursor], hl
                  char_ptr_from_code([vars.chars], a, tt:de)
                  inc  hl
                  ld   de, dvar.scroll_ctrl.char_data
                  ld   bc, 6
                  ldir                        # copy the shape of the character to dvar.scroll_ctrl.char_data
    # slowly force the advanced scale control to the desired magnitude
    ensure_focus  ld   hl, dvar.scale_control.frms
                  ld   [hl], 0
                  ld   hl, dvar.pattx_control.vhi
                  ld   c, 0x80
                  call move_towards
                  ld   hl, dvar.patty_control.vhi
                  ld   c, 0x40
    move_towards  ld   a, [hl]
                  cp   c
                  ret  Z
                  ccf
                  ld   c, a    # cur_incr
                  sbc  a       # dir: 0 if tgt > cur, -1 if tgt < cur
                  ora  1       # dir: 1 if tgt > cur, -1 if tgt < cur
                  add  c       # a: cur += dir
                  ld   [hl], a
                  ret
    # check music counter
    sync_focus    call synchronize_music
                  jr   ensure_focus
    # reset text pointer
    reset_text    ld   hl, [dvar.text_cursor]
                  jr   read_char
  end

  # The "spectrum analyzer" effect
  ns :extra_spectrum do
                  ld   hl, dvar.scale_control
                  ld   [hl], 0      # keep the focus unchanged (frms)

    # the following routine renders the 16x16 "spectrum" based on 16 data points (0..255)
                  ld   hl, pattern_buf
                  ld   de, dvar.spectrum.data
                  ld   a, 16        # row counter
    # process each row
    vloop         ex   af, af       # hide row counter
                  ld   a, [de]      # get data point
                  sub  16           # decay data point
                  jr   NC, no_zero  # data point >= 16 ?
                  xor  a            # clear data point if < 16
    no_zero       ld   [de], a      # do decay
                  add  16           # restore original data point value
                  inc  de           # cursor to next data point
                  anda 0b11100000   # take the most significant 3 bits only of the data point
                  jr   Z, skip_line # just paint the whole row black
                  2.times { rrca }
                  # ld   c, 7<<3#a    # bg color 1-7
                  ld   b, a         # paper color 1-7 << 3
                  anda 0b00011000   # paper color 1-3
                  ora  0x07         # white ink
                  ld   c, a         # color to put
                  ld   a, b
                  3.times { rrca }
                  ld   b, a         # 1-7 (counter)
                  cpl
                  add  0x11         # $0F-$09    - col
                  ora  l            # l: $00-$F0 - row, a: $l0-$lF - end gap
    # the routine puts 16 colors in a row
    # first (1..b) dark colors, black gap (b+1..a-1), (a..$lf) bright colors mirrored
    hloop1        dec  c            # next color
                  ld   [hl], c      # put color
                  inc  l            # next col
                  djnz hloop1
                                    # fill middle gap
    hloop2        ld   [hl], b      # b: 0
                  inc  l            # next col
                  cp   l            # until end of gap
                  jr   NZ, hloop2

                  ld   b, 0x0F      # mask
                  set  6, c         # set bright color
    hloop3        inc  c            # next color (mirror)
                  ld   [hl], c      # put color
                  inc  l            # next col (next row at the end)
                  ld   a, l
                  anda b            # col == 0 ?
                  jr   NZ, hloop3   # until end of the row

    next_line     ex   af, af       # restore row counter
                  dec  a
                  jr   NZ, vloop    # next row

                  call synchronize_music

    # the following routine updates the spectrum data points based on music control variables
                  ld   hl, dvar.spectrum.data
                  ld   de, music.music_control.chan_a.current_note
                  # ld   bc, music.music_control.ay_registers.volume_a
                  ld   bc, music.music_control.chan_a.volume_envelope.current_value
                  call mixvol
                  ld   hl, dvar.spectrum.data
                  ld   de, music.music_control.chan_b.current_note
                  # ld   bc, music.music_control.ay_registers.volume_b
                  ld   bc, music.music_control.chan_b.volume_envelope.current_value
                  call mixvol
                  ld   hl, dvar.spectrum.data
                  ld   de, music.music_control.chan_c.current_note
                  # ld   bc, music.music_control.ay_registers.volume_c
                  ld   bc, music.music_control.chan_c.volume_envelope.current_value
    mixvol        ld   a, [de] # current_note
                  # 1.times { rrca }
                  # add  e
                  # add  c
                  anda 0x0F
                  add  a, l
                  ld   l, a
                  ld   a, [bc] # volume
                  ld   b, a
                  srl  b
                  ld   c, b
                  srl  c
                  cp   [hl]
                  jr   C, skipmix1
                  # ld   a, 0x7F
                  # srl  a
                  # add  [hl]
                  # ld   c, a
                  # sbc  a, a
                  # ora  c
                  ld   [hl], a
    skipmix1      inc  l
                  inc  l
                  ld   a, b
                  cp   [hl]
                  jr   C, skipmix2
                  # ld   a, 0x3F
                  # srl  a
                  # add  [hl]
                  # ld   c, a
                  # sbc  a, a
                  # ora  c
                  # add  0x1F
                  ld   [hl], a
    skipmix2      dec  l
                  ld   a, c
                  cp   [hl]
                  jr   C, skipmix3
                  ld   [hl], a
    skipmix3      dec  l
                  dec  l
                  cp   [hl]
                  jr   C, skipmix4
                  ld   [hl], a
    skipmix4      dec  l
                  ld   a, b
                  cp   [hl]
                  ret  C
                  # ld   a, 0x3F
                  # srl  a
                  # add  [hl]
                  # ld   c, a
                  # sbc  a, a
                  # ora  c
                  # add  0x1F
                  ld   [hl], a
                  ret
    # paints the whole row black
    skip_line     ld   b, 16
    skloop        ld   [hl], a   # a: 0
                  inc  l         # next col (next row at the end)
                  djnz skloop
                  jp   next_line # back to loop
  end

  # Animates frames at dvar.pattern_bufh.
  ns :animation do
                  ld   hl, [dvar.anim_frames]
    get_frame_ck  ld   a, l
                  ora  h
                  ret  Z  # no animation
                  ld   de, dvar.anim_wait
                  ld   a, [de]
                  anda a
                  jr   NZ, skip_frame
                  ld   a, [hl] # MSB frame address
                  ld   [dvar.pattern_bufh], a
                  inc  hl
                  ld   a, [hl] # next counter
                  anda a
                  jr   Z, restart
                  inc  hl
                  ld   [dvar.anim_frames], hl
    skip_frame    dec  a
                  ld   [de], a
                  ret
    restart       ld   hl, [dvar.anim_start]
                  jr   get_frame_ck
  end

  ############
  # Builders #
  ############

  # Red G D C letters on a white bright chequered background
  ns :make_pattern1 do
                  ld   hl, pattern1
                  ld   e, 0b00100010
                  ld   c, 0b00111000
                  push hl
                  call make_pattern6.loop0
                  pop  hl
                  ld   de, pattern1_data
    loop0         ld   a, [de] # color and count
                  inc  de
                  ld   c, a
                  anda 0x0F
                  ret  Z
                  ld   b, a    # counter
                  xor  c
                  rrca
                  ld   c, a    # color
                  ld   a, [de] # start xy
                  inc  de
    looph         ld   l, a
                  push hl
                  ld   a, [de] # data
                  inc  de
    loopw         add  a
                  jr   NC, skip_pix
                  ld   [hl], c
    skip_pix      inc  hl
                  jr   NZ, loopw
                  pop  hl
                  ld   a, l
                  add  0x10
                  djnz looph
                  jr   loop0
  end

  # Colored, centered frames.
  ns :make_pattern2 do
                ld   hl, pattern2
                push hl
                ld   de, pattern2_data
                call make_pattern4.start
                pop  hl
    loop0       ld   a, l
                anda 0b10001000
                jp   PE, skip_res
                res  6, [hl]
    skip_res    inc  l
                jr   NZ, loop0
                ret
  end

  # Colored stripes
  ns :make_pattern3 do
                  ld   hl, pattern3
                  ld   c, 16
    looph         ld   a, 16
                  sub  c
                  rra
                  ld   b, a
                  sbc  a
                  anda 0b00001000
                  ora  b
                  3.times { rlca }
                  ld   b, 16
    loopv         ld   [hl], a
                  inc  l
                  djnz loopv
                  dec  c
                  jr   NZ, looph
                  ret
  end

  # Red bricks
  ns :make_pattern4 do
                  ld   h, pattern4 >> 8
                  ld   de, pattern4_data
    start         ld   a, [de]           # color and counter
                  anda a
                  ret  Z
                  inc  de
                  ld   c, a
                  anda 0x0F
                  ld   b, a              # counter
                  xor  c
                  rrca
                  ld   c, a              # color
                  ld   a, [de]           # lengths
                  inc  de
    loop1         push af                # save lengths
                  ex   de, hl
                  ld   e, [hl]           # coordinates-1
                  ex   de, hl
                  inc  de
    looph         push af                # save lengths
                  push hl                # save coords
    loopw         ld   [hl], c
                  inc  l
                  dec  a
                  anda 0x0F              # only length
                  jr   NZ, loopw
                  pop  hl                # restore coords
                  ld   a, l
                  add  0x10              # next row
                  ld   l, a
                  pop  af                # restore lengths
                  sub  0x10
                  cp   0x10
                  jr   NC, looph
                  pop  af
                  djnz loop1
                  jr   start
  end

  # White bright chequered background
  ns :make_pattern6 do
                  ld   hl, pattern6
    pattern       ld   e, 0b11001100
    color         ld   c, 0b00111111
    loop0         ld   a, l
                  anda e
                  jp   PO, reset0
                  set  6, c
                  jr   over
    reset0        res  6, c
    over          ld   [hl], c
                  inc  l
                  jr   NZ, loop0
                  ret
  end

  # Animated B/W and color figurines
  ns :make_figurines do
                  clrmem pattern_ani1, 3*256, 0x02
                  clrmem pattern_ani4, 3*256, 0b01111010
                  ld   c, 0b10000111 # color mask
                  ld   hl, ludek1_data
                  ld   d, pattern_ani1 >> 8
                  ld   ix, make_figurine_plane
                  # 1st create 3 times a step 1 figurine on all patterns
                  call make_figurines_step1
                  # 2nd step
                  ld   hl, ludek2_data
                  ld   d, pattern_ani2 >> 8
                  call make_figurine_plane
                  # 3rd step
                  # ld   hl, ludek3_data
                  # ld   d, pattern_ani3 >> 8
                  call make_figurine_plane
                  # colors
                  # ld   hl, ludek1_color
                  # ld   d, pattern_ani4 >> 8
                  ld   ix, make_figurine_color
                  # 1st create 3 times a step 1 color figurine on all patterns
                  call make_figurines_step1
                  # 2nd step
                  ld   hl, ludek2_color
                  ld   d, pattern_ani5 >> 8
                  call make_figurine_color
                  # 3rd step
                  # ld   hl, ludek3_color
                  # ld   d, pattern_ani6 >> 8
                  jr   make_figurine_color
  end

  ns :make_figurines_step1 do
                  ld   b, 3
    figloop       push bc
                  push hl
                  call forward_ix
                  pop  hl
                  pop  bc
                  djnz figloop
                  ret
  end

  # a : pre xor
  # d : patternXY >> 8
  # hl: ludek data
  # c : 0b10001111 # color mask
  ns :make_figurine_plane do
                  ld   e, [hl] # y0,x0
                  inc  hl
                  ld   b, [hl] # counter
                  inc  hl
                  ex   de, hl
    mloop         push bc
                  push hl
                  ld   a, [de]
                  inc  de
                  push de
                  scf
                  rla
                  ld   b, a
    bitloop       sbc  a
                  ld   e, a                    # e: value to set
                  xor  [hl]                    # original ^ value
                  anda c                       # (original ^ value) & ~mask
                  xor  e                       # ((original ^ value) & ~mask) ^ value
                  ld   [hl], a
                  inc  l
                  sla  b
                  jr   NZ, bitloop
                  pop  de
                  pop  hl
                  pop  bc
                  ld   a, l
                  add  0x10
                  ld   l, a
                  djnz mloop
                  ex   de, hl
                  inc  d                       # next pattern
                  ret
  end

  # d : patternXY >> 8
  # hl: ludek data
  ns :make_figurine_color do
                  ld   e, [hl] # y0,x0
                  inc  hl
                  ld   b, [hl] # counter
                  inc  hl
                  ex   de, hl
    mloop         push bc
                  push hl
                  ld   b, 4
    vloop         ld   a, [de]
                  rrca
                  ld   c, a                    # e: value to set
                  xor  [hl]                    # original ^ value
                  anda 0b10000111              # (original ^ value) & ~mask
                  xor  c                       # ((original ^ value) & ~mask) ^ value
                  ld   [hl], a
                  inc  l
                  ld   a, [de]
                  inc  de
                  3.times { rlca }
                  ld   c, a                    # e: value to set
                  xor  [hl]                    # original ^ value
                  anda 0b10000111              # (original ^ value) & ~mask
                  xor  c                       # ((original ^ value) & ~mask) ^ value
                  ld   [hl], a
                  inc  l
                  djnz vloop
                  pop  hl
                  pop  bc
                  ld   a, l
                  add  0x10
                  ld   l, a
                  djnz mloop
                  ex   de, hl
                  inc  d                       # next pattern
                  ret
  end

  end_of_code     label

  ########
  # Data #
  ########


  # The minimal sinus table base for creating the full sin/cos table.
  sintable  bytes neg_sintable256_pi_half_no_zero_lo

  # Control characters:
  # $00: EOT
  # $80..$9F: bits 0 to 4 ($00..$1f) = cursor column position, should follow by the cursor line position
  # $F0..$F7: change the ink color to bits 0 to 2
  # $F8: backspace
  # $01..$1f: wait this many frames * 8
  # $FF: clear pixel screen
  intro_text    data "\x08\x92\x82G D C\x04\x82\xA0presents"
                db 0
  title_text    data "\xF6\x87\x4FY A R T Z"
                db 0
  scroll_text   db '*** SPECCY.PL PARTY 2019.04.06 ***', 0
  greetz_text   data "\x1F\xF1\x81\x18Greetings:\x92\x30\x08Fred\x92\x40\x05Grych\x92\x50\x05KYA\x92\x60\x05M0nster\x92\x70\x05Tygrys\x92\x80\x05Voyager\x92\x90\x05Woola-T"
                db 0
                data "\xFF\xF4\x83\x90from r-type"
                db 0
                data "\xFF\xF0\x83\x38Thanks\x8A\x50for\x8B\x68watching!"
                db 0

  # G D C characters
  pattern1_data db 0xA6, 0x00, 0b01111000,
                               0b10000000,
                               0b10000000,
                               0b10001110,
                               0b10000000,
                               0b10000000,
                   0x26, 0x10, 0b01000000,
                               0b01000000,
                               0b01000000,
                               0b01000110,
                               0b01100110,
                               0b01111100,
                   0xA6, 0x80, 0b01111100,
                               0b10000110,
                               0b10000000,
                               0b10000000,
                               0b10000000,
                               0b10000010,
                   0x26, 0x90, 0b01000000,
                               0b01000000,
                               0b01000000,
                               0b01000000,
                               0b01000100,
                               0b01111100,
                   0xA8, 0x48, 0b11111000,
                               0b10000100,
                               0b10000010,
                               0b10000000,
                               0b10000000,
                               0b10000000,
                               0b10000000,
                               0b10000000,
                   0x27, 0x58, 0b01111000,
                               0b01000100,
                               0b01000110,
                               0b01000110,
                               0b01000110,
                               0b01111100,
                               0b01111000,
                   0

                # 0: bcccnnnn b - bright, c - color, n - counter
                # 1: hhhhwwww h - height, w - width
                # 2: yyyyxxxx y, x - coordinates (n times)
  pattern2_data db 0x81, 0x00, 0x00, # bright black
                   0x91, 0xEE, 0x11, # bright blue
                   0xA1, 0xCC, 0x22, # bright red
                   0xB1, 0xAA, 0x33, # bright magenta
                   0xC1, 0x88, 0x44, # bright green
                   0xD1, 0x66, 0x55, # bright cyan
                   0xE1, 0x44, 0x66, # bright yellow
                   0xF1, 0x22, 0x77, # bright white
                   0
                # db 0x02, 0x88, 0x80, 0x08 # black
                # db 0x12, 0x77, 0x81, 0x18 # blue
                # db 0x22, 0x66, 0x82, 0x28 # red
                # db 0x32, 0x55, 0x83, 0x38 # magenta
                # db 0x42, 0x44, 0x84, 0x48 # green
                # db 0x52, 0x33, 0x85, 0x58 # cyan
                # db 0x62, 0x22, 0x86, 0x68 # yellow
                # db 0x72, 0x11, 0x87, 0x78 # white

  pattern4_data db  0xA1, 0x00, 0x00, # bright red
                    0x26, 0x37, 0x11,
                                0x19,
                                0x55,
                                0x91,
                                0x99,
                                0xD5,
                    0x22, 0x34, 0x50, 0xD0,
                    0x22, 0x33, 0x5D, 0xDD,
                    0
  # pattern4_data db 0xF1, 0x00, 0x00, # bright white 16x16
  #                  0x74, 0x33, 0x00, # white 0x0+3x3
  #                              0x0D, # white 0xD+3x3
  #                              0xD0, # white Dx0+3x3
  #                              0xDD  # white DxD+3x3
  #                  0xD2, 0x33, 0x33, # bright cyan 3x3+3x3
  #                              0xAA, # bright cyan AxA+3x3
  #                  0x52, 0x33, 0x3A, # cyan 3xA+3x3
  #                              0xA3, # cyan Ax3+3x3
  #                  0x91, 0x44, 0x66, # bright blue 6x6+4x4
  #                  0x11, 0x22, 0x77, # blue 7x7+2x2
  #                  0

  # Animation data
  ludek_anim1   db pattern_ani1>>8, 6, pattern_ani2>>8, 6, pattern_ani3>>8, 6, pattern_ani2>>8, 0
  ludek_anim2   db pattern_ani4>>8, 6, pattern_ani5>>8, 6, pattern_ani6>>8, 6, pattern_ani5>>8, 0
  ludek_anim1a  db [pattern_ani1>>8, 1, pattern_ani4>>8, 1]*3,
                   [pattern_ani2>>8, 1, pattern_ani5>>8, 1]*3,
                   [pattern_ani3>>8, 1, pattern_ani6>>8, 1]*3,
                   [pattern_ani2>>8, 1, pattern_ani5>>8, 1]*2,
                   pattern_ani2>>8, 1, pattern_ani5>>8, 0

  # B/W figurine plane data
  ludek1_data   db (1<<4|4), 15,
                   0b00111100,
                   0b01111110,
                   0b00110100,
                   0b00111110,
                   0b00011100,
                   0b00011000,
                   0b00111100,
                   0b01111110,
                   0b01101110,
                   0b01101110,
                   0b01110110,
                   0b00111100,
                   0b00011000,
                   0b00011000,
                   0b00011100

  ludek2_data   db (9<<4|4), 7,
                   0b01111110,
                   0b01110110,
                   0b01111010,
                   0b00111100,
                   0b01110110,
                   0b01101110,
                   0b01110111

  ludek3_data   db (9<<4|4), 7,
                   0b11111110,
                   0b11011011,
                   0b10111101,
                   0b01111100,
                   0b11101111,
                   0b11000111,
                   0b11100010

  # Color figurine chunky data
  ludek1_color  db (1<<4|4), 15,
                   0xFF,0x44,0x4C,0xFF,
                   0xF4,0x44,0x44,0xCF,
                   0xFF,0x66,0x26,0xFF,
                   0xFF,0x66,0x66,0xAF,
                   0xFF,0xF6,0x60,0xFF,
                   0xFF,0xF3,0xBF,0xFF,
                   0xFF,0xBB,0xBB,0xFF,
                   0xFB,0xBB,0xBB,0xBF,
                   0xFB,0x36,0xBB,0xBF,
                   0xFB,0x36,0xBB,0xBF,
                   0xFB,0xB3,0x6B,0xBF,
                   0xFF,0x15,0x55,0xFF,
                   0xFF,0xF1,0x5F,0xFF,
                   0xFF,0xF1,0x5F,0xFF,
                   0xFF,0xF9,0x99,0xFF

  ludek2_color  db (9<<4|4), 7,
                   0xFB,0xBB,0x3B,0xBF,
                   0xFB,0xBB,0x63,0xBF,
                   0xFB,0xB3,0x36,0xBF,
                   0xFF,0x15,0x55,0xFF,
                   0xF1,0x55,0xF1,0x5F,
                   0xF1,0x5F,0x15,0x5F,
                   0xF9,0x99,0xF9,0x99

  ludek3_color  db (9<<4|4), 7,
                   0xBB,0x3B,0xB6,0xBF,
                   0xB3,0x6B,0x3F,0x6B,
                   0x36,0x3B,0xB3,0xF6,
                   0xF1,0x55,0x55,0xFF,
                   0x15,0x5F,0x15,0x59,
                   0x15,0xFF,0xF1,0x59,
                   0x99,0x9F,0xFF,0x9F

  import        Music, :music, override: {'music.sincos': sincos}
end

include ZXLib

class Program
  include Z80
  include Z80::TAP

  GDC_SEED = 422 # 12347, 288, 640, 65535, 7777, 351, 9291, 6798, 4422, 1742

  io_ay = ZXSys.io128
  # io_ay = ZXSys.fuller_io
  # io_ay = ZXSys.ioT2k

  GDC = ::GDC.new 48000, override: { 'music.io128': io_ay }

  export start

  label_import  ZXSys
  macro_import  ZX7

  start         ld   hl, code_zx7
                ld   de, GDC.org # start address
                push de
                call decompress
                ld   hl, GDC_SEED
                ld   [vars.seed], hl
                ret  # jump [sp]

  decompress    dzx7_standard
  code_zx7      data ZX7.compress(GDC.code)
  end_of_data   label
end

gdc = Program::GDC
puts gdc.debug
puts "SIZE : #{gdc.code.bytesize}"
puts "CODE : #{gdc[:end_of_code] - gdc[:start]}"
puts "DATA : #{gdc[:music] - gdc[:end_of_code]}"
puts "MUSIC: #{gdc['+music']}"
puts "wrktop: #{gdc.org + gdc.code.bytesize}"

reserved = gdc['music.fine_tones'] - (gdc['music.notes'] + 96*2)
raise "org too high by: #{reserved}" if reserved < 0

def display_labels(program, names)
  names.map {|n| [n,program[n]]}
  .sort_by {|(n,v)| v}
  .each do |(name, value)|
    puts "  #{name.ljust(30)}: 0x#{'%04x'%value} #{value}"
  end
end

display_labels gdc, %w[
dvar
dvar.pattx_control.value
dvar.patty_control.value
dvar.rotate_state.angle
dvar.rotate_state.scale
+dvar
dvar_end
start +start end_of_code
rotate_int +rotate_int
control_value +control_value
extra_spectrum
extra_scroll
pattern1
pattern3
pattern6
pattern2
pattern4
make_pattern1 +make_pattern1
make_pattern2 +make_pattern2
make_pattern3 +make_pattern3
make_pattern4 +make_pattern4
make_pattern6 +make_pattern6
make_figurines +make_figurines
make_figurines_step1 +make_figurines_step1
make_figurine_plane +make_figurine_plane
make_figurine_color +make_figurine_color
pattern_ani1
pattern_ani2
pattern_ani3
pattern_ani4
pattern_ani5
pattern_ani6
mini_stk_end intr_stk_end
sincos patt_shuffle pattern_buf
music music.init music.play music.mute music.music music.music.play
music.track_a music.track_b music.track_c music.index_table
music.song +music.song music.song_end
music.notes music.ministack music.note_to_cursor music.fine_tones
music.track_stack_end music.empty_instrument
music.music_control.counter
music.music_control +music.music_control
] + GDC::DemoVars.members_of_struct.keys.map{|n| 'dvar.'+n }

bootstrap = Program.new Program::GDC.org - Program.code.bytesize
# puts bootstrap.debug[0..52]
code_compressed = ZX7.compress(Program::GDC.code[0, Program::GDC[:music] - Program::GDC.org])
music_compressed = ZX7.compress(Program::GDC.code[Program::GDC[:music] - Program::GDC.org, Program::GDC['+music']])
puts "COMPRESSED TOTAL SIZE:\t#{bootstrap.code.bytesize}"
puts "COMPRESSED BUNDLE SIZE:\t#{bootstrap['+code_zx7']} < #{Program::GDC.code.bytesize}"
puts "COMPRESSED CODE SIZE:\t#{code_compressed.bytesize} < #{Program::GDC[:music] - Program::GDC.org}"
puts "COMPRESSED MUSIC SIZE:\t#{music_compressed.bytesize} < #{Program::GDC['+music']}"
puts "COMPRESSED SEPARATELY:\t#{code_compressed.bytesize + music_compressed.bytesize}"

program = Basic.parse_source <<-END
   0 REM `8``8``8``8``8``8``8``8``8``PAPER 2``INK 6`  Yet Another `FLASH 1`RoToZoomer`FLASH 0``TAB 0``PAPER 0``INK 7`by r-type/GDC`TAB 0``PAPER 7``INK 0`
   1 RANDOMIZE USR VAL "#{Program::GDC.org}"
9998 STOP
9999 CLEAR VAL "#{bootstrap.org-1}": LOAD ""CODE : RANDOMIZE USR VAL "#{bootstrap[:start]}"
END
puts program.to_source escape_keywords:true
program.save_tap 'yartz', name: 'Y A R T Z', line: 9999
bootstrap.save_tap 'yartz', name: 'y a r t z', append: true

Z80::TAP.parse_file('yartz.tap') do |hb|
    puts hb.to_s
end

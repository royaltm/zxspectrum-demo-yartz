# -*- coding: BINARY -*-
here = File.expand_path('..', __dir__)
$:.unshift(here) unless $:.include?(here)

require 'z80'
require 'z80/math_i'
require 'z80/stdlib'
require 'zxlib/gfx'
require 'zxlib/sys'
require 'utils/zx7'
require 'utils/shuffle'
require 'utils/sincos'
require 'gdc/bfont'

class GDC
  include Z80
  include Z80::TAP

  # this controls rendering mode
  # may be one of:
  #
  # * false - renders from 0 to 22 attribute line
  # * true - renders full screen
  # * :center - renders from 1 to 23 attribute line
  #
  FULL_SCREEN_MODE = false

  B_ROTATE_SIMPLY = 0
  B_ZOOM_SIMPLY   = 1
  B_RND_PATTERN   = 1
  B_EFFECT_OVER   = 7

  ###########
  # Exports #
  ###########

  export        gdc

  ###########
  # Imports #
  ###########

  label_import  ZXSys
  macro_import  Z80Lib
  macro_import  Z80MathInt
  macro_import  Z80SinCos
  macro_import  Z80Shuffle
  macro_import  ZXGfx
  # macro_import  ZX7
  macro_import  BigFont

  ###########
  # Structs #
  ###########

  # current iteration rendering data
  class Rotator < Label
    dx2  word # delta x when moving down/up screen
    dx1  word # delta x when moving right/left screen
    dy2  word # delta y when moving down/up screen
    dy1  word # delta y when moving right/left screen
  end

  # simple zoom/scale control data
  class RotateState < Label
    angle byte    # only for simple rotating when B_ROTATE_SIMPLY is set
    scale byte    # only for simple zooming when B_ZOOM_SIMPLY and B_ROTATE_SIMPLY is set
    state angle word # union as word
  end

  # advanced random zoom/scale/pan control data
  class ValueControl < Label
    frms      byte     # frames counter (left to change target)
    tgt_incr  byte     # target  delta (unsigned)
    cur_incr  byte     # current delta (unsigned)
    vlo       byte     # current value (fractional part)
    vhi       byte     # current value (signed integer part)
    value     vlo word # vlo+vhi union as word
  end

  # color snake control data
  class SnakeControl < Label
    total     byte
    counter   byte
    color     byte
    delta     byte # 1, -1, 16, -16
    yx        byte
  end

  # all demo variables
  class DemoVars < Label
    pattern_lo    byte
    pattern_hi    byte
    pattern       pattern_lo word # current pattern in the process of randomized swap
    fgcolor       byte            # pixel grid current fg color on the 3 most significant bits
    at_position   ZXSys::Cursor   # text cursor
    general_delay byte            # some delay counter
    logo_current  byte            # logo shuffle cursor
    logo_mask     byte            # current logo show/clear mask
    text_delay    byte            # text delay counter
    text_cursor   word            # pointer to text
    colors_delay  byte            # colors delay counter
    shuffle_state byte            # current shuffle cursor
    rotate_flags  byte            # rotation control with B_* flags
    scale_control ValueControl    # advanced scale control
    angle_control ValueControl    # advanced angle control
    pattx_control ValueControl    # advanced pan x control
    patty_control ValueControl    # advanced pan y control
    snake_control SnakeControl    # color snake control
    rotate_state  RotateState     # simple scale/angle control
    rotator       Rotator, 2      # 2 rotators: 1st for left to right and 2nd right to left
    x1            word            # normalized pan x shift for current iteration
    logo_lines    byte, 64        # logo lines shuffle data
  end

  ########
  # Vars #
  ########

  logo_shadow   addr 0xE800
  sincos        addr 0xE400, Z80SinCos::SinCos
  pattern1      addr sincos - 256
  pattern2      addr pattern1 - 256
  pattern3      addr pattern2 - 256
  pattern4      addr pattern3 - 256
  pattern6      addr pattern4 - 256

  dvar          addr 0xF000, DemoVars
  dvar_end      addr :next, 0
  save_sp_basic addr :next, 2
  save_sp_int   addr :next, 2
  logo_temp     addr 0xF800             # just a temporary decompress space, currently unused
  pattern_buf   addr logo_temp - 256    # current pattern data
  patt_shuffle  addr pattern_buf - 256  # pattern shuffle index
  mini_stk_end  addr patt_shuffle[0]    # stack for main program
  int_stk_end   addr mini_stk_end - 256 # stack for music player

  ##########
  # Macros #
  ##########

  # ZF=0 if any key is being pressed
  macro :key_pressed? do
                xor  a
                inp  a, (254)
                cpl
                anda 0x1F
  end

  macro :init_interrupts do |_, handleint|
      ld  a, 0x18          # 18H is jr
      ld  [0xFFFF], a
      ld  a, 0xC3          # C3H is jp
      ld  [0xFFF4], a
      ld  hl, handleint
      ld  [0xFFF5], hl
      ld  a, 0x39
      ld  i, a             # load the accumulator with FF filled page in rom.
      im2
      ei
  end

  ##
  # main attribute renderer piece of the puzzle
  #
  # hl - normalized current x:  ssssxxxx.xxxxxxxx
  # de - normalized dx                  ^ fraction point
  # hl' - normalized current y: yyyy.yyyyyyyyyyyy (y-axix has more precision bits)
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

  ns :gdc, use: dvar do
                  exx
                  push hl                   # save hl'

                  call release_key

                  di

                  # ld  hl, 42423
                  # ld  [vars.seed], hl

                  ld   [save_sp_basic], sp
                  ld   sp, mini_stk_end     # own stack in "fast" mem

                  ld   a, 0b00000000
                  call clear_screen

                  call music_init

                  clrmem dvar, +dvar

                  ld   hl, logo_data
                  # ld   de, logo_temp
                  # push de
                  # call decompress
                  # pop  hl
                  ld   bc, (62 << 8) | 18
                  call prepare_logo

                  call make_sincos

                  call make_pattern1
                  call make_pattern2
                  call make_pattern3
                  call make_pattern4
                  call make_pattern6

                  ld   ix, identity
                  ld   hl, patt_shuffle
                  ld   a, 256
                  ld   [dvar.shuffle_state], a
                  call shuffle

                  ld   hl, 0x6000
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
                  ld   a, [vars.seed + 1]
                  ld   [dvar.fgcolor], a

                  ld   hl, dvar.rotate_flags
                  ld   [hl], 1 << B_ROTATE_SIMPLY

                  memcpy pattern_buf, pattern4, 256

                  ld   a, [vars.seed]
                  anda 7
                  xor  6
                  call extra_colors.set_fg_color

                  ld   hl, dvar.text_delay
                  ld   [hl], 1
                  ld   hl, greetz_text
                  ld   [dvar.text_cursor], hl

                  # start rotating
                  init_interrupts rotate_int

                  call wait_for_next.reset

                  ld   hl, dvar.rotate_flags
                  set  B_ZOOM_SIMPLY, [hl]

                  ld   hl, extra_show_logo
                  ld   [wait_for_next.extra + 1], hl
                  call wait_for_next
                  call prepare_logo.reset_vars
                  call wait_for_next.reset

                  ld   hl, extra_clear_logo
                  ld   [wait_for_next.extra + 1], hl
                  call wait_for_next

                  # convert current simple rotate angle and scale states to control values
                  ld   hl, dvar.angle_control.tgt_incr
                  ld   [hl], 128+127 # target
                  inc  l
                  ld   [hl], 128-64 # current
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

                  ld   hl, extra_hide
                  ld   [wait_for_next.extra + 1], hl
                  call wait_for_next
  
                  halt
                  ld   a, 0b01010101
                  call alt_clear_scr

                  ld   hl, extra_show
                  ld   [wait_for_next.extra + 1], hl
                  call wait_for_next

                  ld   hl, extra_colors
                  ld   [wait_for_next.extra + 1], hl
                  call wait_for_next
                  call wait_for_next
                  ld   hl, dvar.rotate_flags
                  set  B_RND_PATTERN, [hl]
                  call wait_for_next

                  ld   hl, extra_destroy
                  ld   [wait_for_next.extra + 1], hl
                  call wait_for_next

    [pattern2, pattern3].each_with_index do |addr, i|
                  ld   hl, addr
                  ld   [dvar.pattern], hl
                  ld   hl, extra_swap
                  ld   [wait_for_next.extra + 1], hl
                  call wait_for_next

                  ld   hl, extra_colors
                  ld   [wait_for_next.extra + 1], hl
      (3 - i).times do
                  call wait_for_next
      end
    end
                  ld   hl, extra_random
                  ld   [wait_for_next.extra + 1], hl
                  ld   a, 0
                  call extra_colors.set_fg_clrbrd
                  3.times { call wait_for_next }

                  ld   hl, extra_hide
                  ld   [wait_for_next.extra + 1], hl
                  call wait_for_next
                  call wait_for_next.reset

                  ld   hl, pattern6
                  ld   [dvar.pattern], hl
                  ld   hl, extra_swap_hide
                  ld   [wait_for_next.extra + 1], hl
                  call wait_for_next
                  call wait_for_next.reset

                  ld   hl, extra_snake
                  ld   [wait_for_next.extra + 1], hl
                  ld   hl, dvar.snake_control.total
                  ld   [hl], 87 # total
                  inc  hl
                  ld   [hl], 1  # counter
                  call wait_for_next

                  ld   hl, pattern1
                  ld   [dvar.pattern], hl
                  ld   hl, extra_swap_hide
                  ld   [wait_for_next.extra + 1], hl
                  call wait_for_next

                  call clearscr
                  memcpy pattern_buf, pattern1, 256

                  ld   hl, extra_text
                  ld   [wait_for_next.extra + 1], hl
                  call wait_for_next

                  ld   a, 255
                  ld   [dvar.fgcolor], a
                  ld   hl, extra_destroy
                  ld   [wait_for_next.extra + 1], hl
                  call wait_for_next
                  call wait_for_next.reset

    demo_exit     di
                  call music_mute
                  ld   a, 0b00111000
                  call clear_screen
                  ld   hl, outro_text
                  ld   [dvar.text_cursor], hl
    eloop         call extra_text
                  ld   hl, dvar.rotate_flags
                  bit  B_EFFECT_OVER, [hl]
                  jr   Z, eloop

                  ld   sp, [save_sp_basic]
                  ld   iy, vars.err_nr      # restore iy
                  ld  a, 0x3F
                  ld  i, a
                  im1
                  ei
                  pop  hl                   # restore hl'
                  exx
                  ret
                  # jp   cleanup_out

    ns :wait_for_next, use: dvar do
      wloop       halt
      extra       call just_wait
                  key_pressed?
                  jr   NZ, demo_exit
                  ld   hl, dvar.rotate_flags
                  bit  B_EFFECT_OVER, [hl]
                  jr   Z, wloop
                  res  B_EFFECT_OVER, [hl]
                  ret
      reset       ld   hl, just_wait
                  ld   [extra + 1], hl
                  jr   wloop
      just_wait   ld   hl, dvar.general_delay
                  dec  [hl]
                  ret  NZ
                  pop  af
                  ret
    end
  end

  ###############
  # Subroutines #
  ###############

  # clear screen using CL-ALL and reset border
  # cleanup_out   call rom.cl_all
  #               ld   a, [vars.bordcr]
  #               call set_border_cr
  #               ret
                # ld  a, 2
                # call rom.chan_open
                # ld   de, outro_text
                # ld   bc, +outro_text
                # jp   rom.pr_string

  # create pixel pattern alternating ~ register A each line
  ns :alt_clear_scr, use: mem do
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

  # clears screen area with border and attributes set according to register a
  clear_screen  clrmem  mem.attrs, mem.attrlen, a
  set_border_cr anda 0b00111000
                3.times { rrca }
                out  (254), a
                call clearscr
                ret

  # clear pixel screen
  ns :clearscr, use: mem do
                clrmem  mem.screen, mem.scrlen, 0
                ret
  end

  # waits until no key is being pressed
  release_key   halt
                key_pressed?
                jr   NZ, release_key
                ret

  # next random number from math_i library
  next_rnd      ld  hl, [vars.seed]
                rnd
                ld  [vars.seed], hl
                ret

  # Parameters:
  #   HL: source address (compressed data)
  #   DE: destination address (decompressing)
  # -----------------------------------------------------------------------------
  # decompress    dzx7_standard

  # create full sin/cos table from minimal sintable
  make_sincos   create_sincos_from_sintable sincos, sintable:sintable

  # create shuffled array
  shuffle       shuffle_bytes_source_max256 next_rnd, target:hl, length:a, source:forward_ix
                ret

  forward_ix    jp   (ix)

  # |a| (a & 7) | ((a & 0b111000) << 2)
  mangle_line   ld   c, a
                anda 0b00111000
                2.times { add  a }
                ld   b, a
                ld   a, c
                anda 0b00000111
                ora  b
                ret

  lines_even    ld   a, c
                add  a
                jr   mangle_line
  lines_odd     ld   a, c
                scf
                adc  a
                jr   mangle_line

  identity      ld   a, c
                ret

  x_shuffle     ld   hl, dvar.shuffle_state
                inc  [hl]
                ld   l, [hl]
                ld   h, patt_shuffle >> 8
                ld   l, [hl] # index 
                ld   h, pattern_buf >> 8 # pattern address
                ret

  # Outputs 16x16 antialiased printable character.
  #
  # a - character to print
  # d - a vertical row (0-191) to start printing at
  # e - a byte column (0-31) to start printing at
  print_big_chr print_char [vars.chars], compact:false, over:true
                ret

  #   frms      byte
  #   tgt_incr  byte
  #   cur_incr  byte
  #   vhi       byte
  #   vlo       byte
  # hl: vc
  # CF: mode - 0: delta+stable frames, 1: current only+random frames
  # preserves: af
  # out: de if delta, a' if current
  ns :control_value do
                  ex   af, af # save mode
                  dec  [hl]   # frms
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
                  ret  # updated value in de

    change_target push hl
                  call next_rnd
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

  # hl - logo
  # c - logo byte width
  # b - logo height
  ns :prepare_logo do
                exx
                clrmem logo_shadow, 2048
                exx
                ld   de, logo_shadow
    loop0       push de
                ld   a, 32
                sub  c
                ora  a
                jr   Z, skip_offs1
                rra          # offset = (32 - b) / 2
                adda_to d, e
    skip_offs1  push bc
                ld   b, 0
                ldir
                pop  bc
    skip_offs2  pop  de
                nextline d, e, false
                djnz loop0
                # (0...64).step(2).map{|c| (c & 7) | ((c & 0b111000) << 2)}.shuffle
                ld   ix, lines_even
                ld   hl, dvar.logo_lines
                ld   a, 32
                call shuffle
                # (1...64).step(2).map{|c| (c & 7) | ((c & 0b111000) << 2)}.shuffle)
                ld   ix, lines_odd
                ld   a, 32
                call shuffle
    reset_vars  ld   a, 64
                ld   [dvar.logo_current], a
                ld   a, 0b10101010
                ld   [dvar.logo_mask], a
                ret
  end

  # x1:  (256*(-(a/16.0)-(dx1 * xs) - (dx2 * ys))).truncate,
  # y1:  (256*16*(8-(dy1 * xs) - (dy2 * ys))).truncate,
  # dx1: (scale*Math.cos(angle) * 256).truncate,
  # dy1: (scale*Math.sin(angle) * 256 * 16).truncate,
  # dx2: (scale*-Math.sin(angle) * 256).truncate,
  # dy2: (scale*Math.cos(angle) * 256 * 16).truncate

  with_saved :rotate_int, :no_ixy, :exx, :ex_af, :no_ixy, use: sincos do
                  ld   [save_sp_int], sp
            # ld   a, 1
            # out  (254), a
  # render lower half - current rotators:
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
                  ld   b, pattern_buf >> 8
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

            # ld   a, 5
            # out  (254), a
                  ld   sp, int_stk_end
                  call music_play
      #             ld   b, 20
      # busyloop    nop
      #             djnz busyloop
    # extra         call extra_wait

                  # calculate new coords (rotate and so on)
                  ld   a, [dvar.rotate_flags]
            # out  (254), a
                  rra  # B_ROTATE_SIMPLY
                  jr   NC, update_ctrls
                  # angle 0 - 255, scale 0-255 (1.0)
                  # c = angle (0..255), b = scale 0..7f
                  # prepare_rotator
                  ld   sp, dvar.rotate_state.state
                  pop  bc # state: c = angle (0..255), b = scale 0..7f

                  dec  c  # rotate
                  rra  # B_ZOOM_SIMPLY
                  jr   NC, skip_scale_sm

                  dec  b  # scale
                  push bc
                  jp   P, start_rotate0 # scale >= 0
                  xor  a  # scale < 0 ? scale = - (scale + 1)
                  inc  b  # scale + 1
                  sub  b  # a = 0 - (scale + 1)
                  ld   b, a
                  jr   start_rotate1
    skip_scale_sm push bc
                  jr   start_rotate0

    update_ctrls  rra  # B_RND_PATTERN
                  jr   NC, skip_patt_ct
                  ld   hl, dvar.patty_control
                  ora  a             # CF = 0
                  call control_value
                  ld   hl, dvar.pattx_control
                  call control_value # CF = 0 preserved

    skip_patt_ct  ld   hl, dvar.angle_control
                  ora  a             # CF = 0
                  call control_value
                  ld   a, d          # angle from vhi

                  ld   hl, dvar.scale_control
                  scf                # CF = 1
                  call control_value
                  ld   c, a          # angle
                  ex   af, af        # curr in a'
                  srl  a
                  ld   b, a          # scale = curr / 2

    start_rotate0 ld   a, b          # scale
    start_rotate1 cp   4             # scale >= 4 ? skip_adjust
                  jr   NC, skip_adjust
                  ld   b, 4          # scale = 4
                                     # calculate: dx1, dy1, dx2, dy2, x1, y1
    skip_adjust   ld   a, c          # angle
                  sincos_from_angle sincos, h, l
                  ld   sp, hl     # hl: address of SinCos entry from an angle in a (256 based)
                  pop  de         # sin(angle)
                  ld   a, b       # scale
                  mul8 d, e, a, tt:de, clrhl:true, double:false # sin(angle) * scale
                  ld   a, b       # scale
                  exx             # hl': sin(angle) * scale
                  pop  de         # cos(angle)
                  mul8 d, e, a, tt:de, clrhl:true, double:false # cos(angle) * scale
                                  # hl: cos(angle) * scale
                  ld   a, l       # dx1: normalize cos(angle) * scale
                  ld   e, h
                  add  a          # llllllll -> CF: l a: lllllll0
                  rl   e          # shhhhhhh -> CF: s e: hhhhhhhl
                  sbc  a          # a: ssssssss
                  ld   d, a       # de: dx1 = sssssssshhhhhhhl

                  ld   a, l       # dy2: normalize cos(angle) * scale
                3.times do        # shhhhhhhllllllll -> sssshhhhhhhlllll
                  sra h           # y axis has better angle resolution
                  rra             # but it's only visible when extremally zoomed in
                end
                  ld   l, a       # hl: dy2 = sssshhhhhhhlllll
  # set rotators:
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
                  rra             # but it's only visible when extremally zoomed in
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

                  ld   hl, [dvar.pattx_control.value] # pattern_x shift as a fraction (-0.5)...(0.5)
                  ld   a, l       # normalize to match x
            4.times do            # shhhhhhhllllllll -> ssssshhhhhhhhlll
                  sra  h
                  rra
            end
                  ld   l, a
                  ld   [dvar.x1], hl # pattern_x shift as a fraction (-0.5)...(0.5) normalized
  # render upper half
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
                  ld   b, pattern_buf >> 8
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
  # prepare rotators for lower half on next interrupt:
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

                  ld   sp, [save_sp_int]
            # xor  a
            # out  (254), a
  end
                  ei
                  ret

  # toggle fg colors
  ns :extra_colors, use: mem do
                  ld   hl, dvar.fgcolor
                  inc  [hl]
                  jr   NZ, apply
                  ld   de, signal_next
                  push de
    apply         ld   a, [hl]
                  anda 0b11100000
                  3.times { rlca }
    set_fg_clrbrd out (254), a
                  ld   c, a
                  3.times { rlca }
                  ora  c
    if FULL_SCREEN_MODE == :center
                  ld   hl, mem.attrs
                  cp   [hl]
                  jr   Z, set_fg_color
                  clrmem hl, 32, a
                  clrmem mem.attrs + mem.attrlen - 32, 32, a
    elsif !FULL_SCREEN_MODE
                  ld   hl, mem.attrs + mem.attrlen - 64
                  cp   [hl]
                  jr   Z, set_fg_color
                  clrmem hl, 64, a
    end

    set_fg_color  ld   hl, pattern_buf
                  xor  [hl]
                  anda 0b00000111
                  ret  Z
                  ld   b, 0
                  ld   c, a
    invloop       ld   a, [hl]
                  xor  c
                  ld   [hl], a
                  inc  hl
                  djnz invloop
                  ret
  end

  ns :signal_next do
                  ld   hl, dvar.rotate_flags
                  set  B_EFFECT_OVER, [hl]
    # reset_extra   ld   hl, extra_wait
    #               ld   [rotate_int.extra + 1], hl
                  ret
  end

  # ns :extra_wait do
  #                 ret
  # end

  # write text
  ns :extra_text do
                  ld   hl, dvar.text_delay
                  dec  [hl]
                  ret  NZ
                  ld   [hl], 3
                  ld   hl, [dvar.text_cursor]
                  ld   de, [dvar.at_position]
    next_char     ld   a, [hl]
                  ora  a
                  jp   Z, signal_next
                  inc  hl
                  jp   M, check_control
                  ld   [dvar.text_cursor], hl
                  cp   32
                  jr   C, handle_wait
                  ex   af, af
                  ld   a, e
                  add  2
                  ld   [dvar.at_position.column], a
                  ex   af, af
                  jp   print_big_chr
    check_control cp   0xF0
                  jr   C, handle_pos
                  ld   [dvar.text_cursor], hl
                  cp   0xFF
                  jr   NZ, handle_other
                  jp   clearscr
    handle_other  cp   0xF8
                  jr   NZ, handle_color
                  ld   a, -2
                  add  e
                  anda 31
                  ld   e, a
                  jr   save_position
    handle_color  anda 0x07
                  jp   extra_colors.set_fg_color
    handle_pos    anda 0x1F
                  ld   e, a
                  ld   d, [hl]
                  inc  hl
    save_position ld   [dvar.at_position], de
                  jr   next_char
    handle_wait   add  a
                  add  a
                  add  a
                  ld   [dvar.text_delay], a
                  ret
  end

  # show logo
  ns :extra_show_logo do
                  ld   hl, dvar.logo_current
                  dec  [hl]
                  jp   M, check_mask
                  ld   a, [hl]
                  ld   hl, dvar.logo_lines
                  adda_to h, l
                  ld   a, [hl] # current line
                  ld   h, a # xxx00yyy
                  anda 0b11100000
                  ld   l, a # xxx00000
                  xor  h    # 00000yyy
                  ora  logo_shadow >> 8 # 0xE8 11101yyy
                  ld   h, a
                  xor  0xE8^0x48
                  ld   d, a
                  ld   a, l
                  add  (32-18)/2
                  ld   l, a
                  ld   e, a
                  ld   b, 18
                  ld   a, [dvar.logo_mask]
                  bit  0, h
                  jr   NZ, skipshft0
                  rlca
    skipshft0     ld   c, a
    loop0         ld   a, [hl]
                  anda c
                  ld   [de], a
                  inc  e
                  inc  l
                  djnz loop0
                  ret
    check_mask    ld   a, [dvar.logo_mask]
                  ld   c, a
                  rrca
                  ora  c
                  cp   c
                  jp   Z, signal_next
                  ld   [dvar.logo_mask], a
                  ld   [hl], 64
                  ret
  end

  # clear logo
  ns :extra_clear_logo do
                  ld   hl, dvar.logo_current
                  dec  [hl]
                  jp   M, check_mask
                  ld   a, [hl]
                  ld   hl, dvar.logo_lines
                  adda_to h, l
                  ld   a, [hl] # current line
                  ld   h, a # xxx00yyy
                  anda 0b11100000
                  ld   l, a # xxx00000
                  xor  h    # 00000yyy
                  ora  0x48 # 01001yyy
                  ld   h, a
                  ld   a, l
                  add  (32-18)/2
                  ld   l, a
                  ld   b, 18
                  ld   a, [dvar.logo_mask]
                  bit  0, h
                  jr   NZ, skipshft0
                  rlca
    skipshft0     ld   c, a
    loop0         ld   a, [hl]
                  anda c
                  ld   [hl], a
                  inc  l
                  djnz loop0
                  ret
    check_mask    ld   a, [dvar.logo_mask]
                  ld   c, a
                  rrca
                  anda c
                  cp   c
                  jp   Z, signal_next
                  ld   [dvar.logo_mask], a
                  ld   [hl], 64
                  ret
  end

  # randomize pattern ink color
  ns :extra_random do
                  ld   hl, dvar.colors_delay
                  dec  [hl]
                  jr   NZ, apply
                  ld   de, signal_next
                  push de
    apply         ld   a, [hl]
                  anda 3
                  ret  NZ
                  call next_rnd
                  ld   a, h # rnd lo
                  ld   h, pattern_buf >> 8 # pattern hi
                  ld   d, 0b11111000 # attr mask
                  anda 0b00000111    # crop to ink color
                  ld   c, a          # ink color
                  ld   b, 16         # counter
                  ld   e, 15         # next line increment - 1
                  res  0, l          # only even columns
    loop0         ld   a, d          # attr mask
                  anda [hl]
                  ora  c
                  ld   [hl], a
                  inc  l             # next column
                  # ld   a, d
                  # anda [hl]
                  # ora  c
                  ld   [hl], a
                  ld   a, e
                  add  l
                  ld   l, a
                  djnz loop0
                  ret
  end

  # color snake
  ns :extra_snake do
                  ld   hl, dvar.snake_control.counter
                  dec  [hl]
                  jr   Z, next_dir_rnd
                  ld   a, [hl] # counter
                  anda 0b00000001
                  ret  NZ
                  inc  hl
                  ld   c, [hl] # color
                  inc  hl
                  ld   a, [hl] # delta
                  inc  hl
                  add  [hl]    # yx
                  ld   [hl], a # yx updated
                  ld   l, a
                  ld   h, pattern_buf >> 8
                  ld   a, [hl]
                  anda 0b11111000
                  ora  c
                  ld   [hl], a
                  ret
    next_dir_rnd  push hl
                  dec  hl      # total
                  dec  [hl]
                  jr   NZ, randomize
                  pop  hl
                  jp   signal_next
    randomize     call next_rnd
                  ex   de, hl
                  pop  hl
                  ld   a, d
                  anda 0b00011111
                  ora  3
                  ld   [hl], a # counter
                  inc  hl      # color
                  ld   a, e
                  2.times { rrca }
                  anda 0b00000111
                  ld   [hl], a # color
                  inc  hl      # delta
                  ld   a, e
                  ld   bc, directions
                  anda 0b00000011
                  adda_to b, c
                  ld   a, [bc] # direction
                  ld   [hl], a # delta
                  ret
    directions    db -1, 1, -16, 16
  end

  # hide ink
  ns :extra_hide do
                  call x_shuffle
                  jr   NZ, apply
                  ld   de, signal_next
                  push de
    apply         ld  a, [hl] # 0b__aaa___ -> 0b__aaaaaa
    hide_color    ld  c, a
                  3.times { rrca }
                  xor c
                  anda 0b00000111
                  xor c
                  ld  [hl], a
                  ret
  end

  # swap pattern and hide ink
  ns :extra_swap_hide do
                  call x_shuffle
                  jr   NZ, apply
                  ld   de, signal_next
                  push de
    apply         ld   a, [dvar.pattern_hi]
                  ld   d, a
                  ld   e, l
                  ld   a, [de]
                  jp   extra_hide.hide_color
  end

  # clear ink color
  ns :extra_show do
                  call x_shuffle
                  jr   NZ, apply
                  ld   de, signal_next
                  push de
    apply         ld   a, [hl]
    mix_fg_color  anda  0b11111000
                  ld   c, a
                  ld   a, [dvar.fgcolor]
                  anda 0b11100000
                  3.times { rlca }
                  ora  c
                  ld   [hl], a
                  ret
  end

  # swap pattern
  ns :extra_swap do
                  call x_shuffle
                  jr   NZ, apply
                  ld   de, signal_next
                  push de
    apply         ld   a, [dvar.pattern_hi]
                  ld   d, a
                  ld   e, l
                  ld   a, [de]
                  jp   extra_show.mix_fg_color
  end

  # destroy pattern
  ns :extra_destroy do
                  call x_shuffle
                  jr   NZ, apply
                  ld   de, signal_next
                  push de
    apply         xor  a
                  jp   extra_show.mix_fg_color
  end

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

  # ns :make_pattern2 do
  #                 ld   h, pattern2 >> 8
  #                 ld   d, 0             # 0 - 0b01110111
  #   loop0         ld   a, 0xF8
  #                 sub  d
  #                 anda 0x0F             # 1 - 8
  #                 ld   b, a
  #                 ld   a, d
  #                 rrca
  #                 anda 0b00111000
  #                 ld   c, a
  #                 push de
  #   loop1         ld   e, d
  #                 call pixels
  #                 ld   a, e
  #                 4.times { rlca }
  #                 ld   e, a
  #                 call pixels
  #                 inc  d
  #                 djnz loop1
  #                 pop  de
  #                 ld   a, d
  #                 add  0x11
  #                 ld   d, a
  #                 jp   P, loop0
  #                 ret
  #   pixels        ld   l, e
  #                 set  6, c
  #                 ld   [hl], c
  #                 ld   a, 0xFF
  #                 sub  e
  #                 ld   l, a
  #                 ld   [hl], c
  #                 xor  e
  #                 anda 0x0F
  #                 xor  e
  #                 ld   l, a
  #                 res  6, c
  #                 ld   [hl], c
  #                 ld   a, 0xFF
  #                 sub  e
  #                 xor  e
  #                 anda 0xF0
  #                 xor  e
  #                 ld   l, a
  #                 ld   [hl], c
  #                 ret
  # end

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

  end_of_code     label

  ########
  # Data #
  ########


  sintable  bytes neg_sintable256_pi_half_no_zero_lo
  # cos256(a) = sin256(a+64)
  # rotator       data Rotator, *angles
  # rotator_end   label

  # 0x00: EOT
  # 0x80..0x9F: c & 0x1f = x cursor position, should follow by y cursor position
  # 0xFc: change color
  # 0xF8: backspace
  # 0x01..0x1f: wait this many frames * 8
  # 0xFF: clear ink screen
  greetz_text   data "\xff\xf6\x85\x08Niech ryczy\x80\x18z bo\xF8'lu ranny l\xF8-os\xF8'\x08\x81\x28Zwierz zdro\xF8'w\x8C\x38przebiega\x90\x48knieje,\x0f\x85\x58Ktos\xF8' nie s\xF8'pi\x82\x68aby spac\xF8' mo\xF8'gl\xF8-\x90\x78ktos\xF8'.\x08\x82\x88To sa\xF8, zwyczajne\x8E\x98dzieje."
                data "\x1f\x0f\xff\xf1\x81\x18Respec' @:\x92\x30\x04Fred\x92\x40\x04Grych\x92\x50\x04KYA\x92\x60\x04M0nster\x92\x70\x04Tygrys\x92\x80\x04Voyager\x92\x90\x04Woola-T"
                data "\x1f\xff\x9A\xA0'18\x82\x10\xf5ASM:\x04\x92\x10r-type"
                data "\x04\x82\x30MSX:\x04\x90\x30Floppys"
                data "\x04\x82\x50GFX:\x04\x92\x50r-type"
                data "\x04\x82\x70FONT:\x04\x98\x70ROM\x83\x81+ antialiasing"
                data "\x1f\xff\x82\x30\xf0Thanks\x89\x48for\x8A\x60watching!\x04\x8e\x80BYE!!!\x1f"
                db 0
  # outro_text    data "Some effects in this demo dependon pseudorandomness.\r\rUse ZX Basic RANDOMIZE command\rto set up rng seed and run againwith USR 32768\r"
  outro_text    data "\x80\x00Some effects in\x80\x10this demo depend\x80\x20on pseudorandom\x80\x30code.\x80\x40Use ZX Basic's\x80\x50RANDOMIZE n\x80\x60to set up rng\x80\x70seed and run\x80\x80again with\x80\x90USR 32768\x00"

  pattern1_data db 0xA6, 0x00, 0b01111000,
                               0b10000000,
                               0b10000000,
                               0b10001110,
                               0b10000000,
                               0b10000000
                db 0x26, 0x10, 0b01000000,
                               0b01000000,
                               0b01000000,
                               0b01000110,
                               0b01100110,
                               0b01111100
                db 0xA6, 0x80, 0b01111100,
                               0b10000110,
                               0b10000000,
                               0b10000000,
                               0b10000000,
                               0b10000010
                db 0x26, 0x90, 0b01000000,
                               0b01000000,
                               0b01000000,
                               0b01000000,
                               0b01000100,
                               0b01111100
                db 0xA8, 0x48, 0b11111000,
                               0b10000100,
                               0b10000010,
                               0b10000000,
                               0b10000000,
                               0b10000000,
                               0b10000000,
                               0b10000000
                db 0x27, 0x58, 0b01111000,
                               0b01000100,
                               0b01000110,
                               0b01000110,
                               0b01000110,
                               0b01111100,
                               0b01111000
                db 0

  pattern2_data db 0x81, 0x00, 0x00 # bright black
                db 0x91, 0xEE, 0x11 # bright blue
                db 0xA1, 0xCC, 0x22 # bright red
                db 0xB1, 0xAA, 0x33 # bright magenta
                db 0xC1, 0x88, 0x44 # bright green
                db 0xD1, 0x66, 0x55 # bright cyan
                db 0xE1, 0x44, 0x66 # bright yellow
                db 0xF1, 0x22, 0x77 # bright white
                db 0
                # db 0x02, 0x88, 0x80, 0x08 # black
                # db 0x12, 0x77, 0x81, 0x18 # blue
                # db 0x22, 0x66, 0x82, 0x28 # red
                # db 0x32, 0x55, 0x83, 0x38 # magenta
                # db 0x42, 0x44, 0x84, 0x48 # green
                # db 0x52, 0x33, 0x85, 0x58 # cyan
                # db 0x62, 0x22, 0x86, 0x68 # yellow
                # db 0x72, 0x11, 0x87, 0x78 # white

  pattern4_data db 0xF1, 0x00, 0x00  # bright white 16x16
                db 0x74, 0x33, 0x00, # white 0x0+3x3
                               0x0D, # white 0xD+3x3
                               0xD0, # white Dx0+3x3
                               0xDD  # white DxD+3x3
                db 0xD2, 0x33, 0x33, # bright cyan 3x3+3x3
                               0xAA  # bright cyan AxA+3x3
                db 0x52, 0x33, 0x3A, # cyan 3xA+3x3
                               0xA3  # cyan Ax3+3x3
                db 0x91, 0x44, 0x66  # bright blue 6x6+4x4
                db 0x11, 0x22, 0x77  # blue 7x7+2x2
                db 0

  logo_data     import_file 'gdc/gdc_logo2.bin'
  # logo_data      data ZX7.compress(IO.read('gdc/gdc_logo2.bin', mode: 'rb'))

  # colormapper = proc do |c|
  #   c = case c
  #   when 0..7
  #     c << 3
  #   when 8..14
  #     0b01000000 | ((c - 7) << 3)
  #   else
  #     raise Syntax, "color palette error: unexpected color"
  #   end
  #   c
  # end

                # org  (pc + 0xff) & 0xff00
  # pattern1      data(IO.read('gdc/gdc.data', mode: 'rb').bytes.map(&colormapper))
  # pattern2      data(File.open('gdc/patternB.data', 'rb'){|f| f.read}.bytes.map(&colormapper))
  # pattern4      data(IO.read('gdc/patternC.data', mode: 'rb').bytes.map(&colormapper))
  # pattern5      data(IO.read('gdc/patternA.data', mode: 'rb').bytes.map(&colormapper))

  music_init    addr 40000
  music_play    addr music_init + 5
  music_mute    addr music_init + 8

end

class Program
  include Z80
  include Z80::TAP

  MUSIC_NAME = 'gdc/music4.tap'
  MUSIC_TAP = Z80::TAP.parse_file(MUSIC_NAME)

  GDC = ::GDC.new 0x8000
  PLAYER = MUSIC_TAP.next
  MUSIC  = MUSIC_TAP.next

  label_import  ZXSys
  macro_import  ZX7

  music_data    addr MUSIC.header.p1
  music_player  addr PLAYER.header.p1

                ld   hl, code_zx7
                ld   de, 32768
                push de
                call decompress
                ld   hl, player_zx7
                ld   de, music_player
                call decompress
                ld   hl, music_zx7
                ld   de, music_data
                call decompress
                ld   hl, 42420
                ld   [vars.seed], hl
                pop  hl
                jp   (hl)

  decompress    dzx7_standard
  code_zx7      data ZX7.compress(GDC.code)
  player_zx7    data ZX7.compress(PLAYER.body.data)
  music_zx7     data ZX7.compress(MUSIC.body.data)
  end_of_data   label
end

gdc = Program::GDC
puts gdc.debug
puts "SIZE: #{gdc.code.bytesize}"
puts "CODE: #{gdc[:end_of_code] - gdc[:gdc]}"
puts "wrktop: #{gdc.org + gdc.code.bytesize}"
%w[end_of_code
rotate_int
pattern1
pattern3
pattern6
pattern2
pattern4
make_pattern1
make_pattern2
make_pattern3
make_pattern4
make_pattern6
dvar.logo_current
dvar.logo_mask
dvar.text_delay
dvar.text_cursor
dvar.shuffle_state
dvar.rotate_flags
dvar.scale_control
dvar.angle_control
dvar.pattx_control
dvar.patty_control
dvar.snake_control
dvar.rotate_state
dvar.rotator
dvar.logo_lines
dvar
dvar_end
mini_stk_end
save_sp_int
logo_temp sincos dvar.pattern dvar.fgcolor dvar.at_position patt_shuffle pattern_buf logo_shadow]
.map {|n| [n,gdc[n]]}
.sort_by {|(n,v)| v}
.each do |(name, value)|
  puts "  #{name.ljust(20)}: 0x#{value.to_s 16} #{value}"
end

program = Program.new 0x4000
# puts program.debug
puts "ZX7 SIZE: #{program.code.bytesize}"
puts "ZX7 CODE SIZE: #{program[:player_zx7] - program[:code_zx7]} vs #{Program::GDC.code.bytesize}"
puts "PLAYER SIZE: #{program[:music_zx7] - program[:player_zx7]} vs #{Program::PLAYER.header.length}"
puts "MUSIC SIZE: #{program[:end_of_data] - program[:music_zx7]} vs #{Program::MUSIC.header.length}"

Z80::TAP.read_chunk('gdc/loader_gdc_screen.tap').save_tap 'gdc.tap'
program.save_tap 'gdc', append: true

Z80::TAP.parse_file('gdc.tap') do |hb|
    puts hb.to_s
end

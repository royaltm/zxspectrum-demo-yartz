# -*- coding: BINARY -*-
here = File.expand_path('../..', __dir__)
$:.unshift(here) unless $:.include?(here)

require 'z80'
require 'z80/math_i'
require 'z80/stdlib'
require 'zxlib/gfx'
require 'zxlib/sys'
require 'zxlib/basic'
require 'utils/zx7'
require 'utils/shuffle'
require 'utils/sincos'
# require 'gdc/bfont'
require 'utils/bigfont'
require_relative 'music3'

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
  B_ENABLE_ZOOM   = 1
  B_RND_PATTERN   = 1
  B_EFFECT_OVER   = 7

  ###########
  # Exports #
  ###########

  export        start

  ###########
  # Imports #
  ###########

  import        ZXSys, labels: true, macros: true, code: false
  macro_import  Z80Lib
  macro_import  Z80MathInt
  macro_import  Z80SinCos
  macro_import  Z80Shuffle
  macro_import  ZXGfx
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
    scale byte    # only for simple zooming when B_ENABLE_ZOOM and B_ROTATE_SIMPLY is set
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
    move_x        word            # simple move delta x
    rotate_delay  byte            # a delay for rotate delta
    rotate_delta  byte            # simple rotate delta
    pattern_bufh  byte            # address (MSB) of the current render buffer
    anim_wait     byte            # animation slowdown counter
    anim_frames   word            # current animation frames no animation if 0
    anim_start    word            # next animation frames
    seed1         word            # 1st seed for rnd rotate control
    seed2         word            # 2nd seed for extra tasks' rnd
  end

  ########
  # Vars #
  ########

  sincos        addr 0xE400, Z80SinCos::SinCos
  pattern1      addr sincos - 256
  pattern2      addr pattern1 - 256
  pattern3      addr pattern2 - 256
  pattern4      addr pattern3 - 256
  pattern6      addr pattern4 - 256

  dvar          addr 0xF000, DemoVars
  dvar_end      addr :next, 0
  pattern_buf   addr 0xF700               # current pattern data
  pattern_ani1  addr 0xF800               # animation pattern data
  pattern_ani2  addr 0xF900               # animation pattern data
  pattern_ani3  addr 0xFA00               # animation pattern data
  pattern_ani4  addr 0xFB00               # animation pattern data
  pattern_ani5  addr 0xFC00               # animation pattern data
  pattern_ani6  addr 0xFD00               # animation pattern data
  patt_shuffle  addr pattern_buf - 256    # pattern shuffle index
  mini_stk_end  addr patt_shuffle[0], 2   # stack for main program
  intr_stk_end  addr mini_stk_end[-80], 2 # stack for interrupt handler
  
  ##########
  # Macros #
  ##########

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

  ns :start, use: :dvar do
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

                  ld   ix, identity
                  ld   hl, patt_shuffle
                  xor  a   # ld   a, 256
                  ld   [dvar.shuffle_state], a
                  call shuffle

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

                  # ld   hl, -1024
                  # ld   [dvar.move_x], hl

                  ld   a, 100
                  call wait_for_next.set_delay

                  ld   a, -1
                  ld   [dvar.rotate_delta], a
                  ld   a, 80
                  call wait_for_next.set_delay

                  ld   hl, dvar.rotate_flags
                  set  B_ENABLE_ZOOM, [hl]

                  ld   a, 120
                  call wait_for_next.set_delay

                  ld   hl, ludek_anim1a
                  ld   [dvar.anim_start], hl
                  ld   a, 40
                  call wait_for_next.set_delay

                  ld   hl, ludek_anim2
                  ld   [dvar.anim_start], hl

                  ld   hl, greetz_text
                  ld   [dvar.text_cursor], hl

                  # ld   hl, dvar.rotate_flags
                  # res  B_ENABLE_ZOOM, [hl]

                  ld   hl, extra_spin
                  call wait_for_next.set_extra
                  # ld   a, 190
                  # call wait_for_next.set_delay

                  ld   hl, 0
                  ld   [dvar.anim_frames], hl
                  ld   a, pattern_buf >> 8
                  ld   [dvar.pattern_bufh], a

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

                  ld   a, 80
                  call wait_for_next.set_delay

                  ld   hl, dvar.rotate_flags
                  set  B_RND_PATTERN, [hl]

                  ld   hl, extra_hide
                  call wait_for_next.set_extra
  
                  halt
                  ld   a, 0b01010101
                  call alt_clear_scr

                  # ld   a, 0b11011111
                  # ld   [dvar.fgcolor], a

                  # ld   hl, extra_show
                  # call wait_for_next.set_extra

                  ld   a, 0b00011111
                  ld   [dvar.fgcolor], a

                  ld   hl, extra_destroy
                  call wait_for_next.set_extra

    [pattern2, pattern3].each_with_index do |addr, i|
                  ld   hl, addr
                  ld   [dvar.pattern], hl
                  ld   hl, extra_swap
                  call wait_for_next.set_extra

                  ld   hl, extra_colors
                  call wait_for_next.set_extra
      (1 - i).times do
                  call wait_for_next
      end
    end
                  ld   a, 0
                  call extra_colors.set_fg_clrbrd
                  ld   hl, extra_random
                  call wait_for_next.set_extra
                  2.times { call wait_for_next }

                  ld   hl, extra_hide
                  call wait_for_next.set_extra
                  call wait_for_next.reset

                  ld   hl, pattern6
                  ld   [dvar.pattern], hl
                  ld   hl, extra_swap_hide
                  call wait_for_next.set_extra
                  call wait_for_next.reset

                  ld   hl, dvar.snake_control.total
                  ld   [hl], 87 # total
                  inc  hl
                  ld   [hl], 1  # counter
                  ld   hl, extra_snake
                  call wait_for_next.set_extra

                  ld   hl, pattern1
                  ld   [dvar.pattern], hl
                  ld   hl, extra_swap_hide
                  call wait_for_next.set_extra

                  call clearscr
                  memcpy pattern_buf, pattern1, 256

                  ld   hl, extra_text
                  call wait_for_next.set_extra

                  ld   a, 255
                  ld   [dvar.fgcolor], a
                  ld   hl, extra_destroy
                  call wait_for_next.set_extra
                  call wait_for_next.reset

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

    ns :wait_for_next do
      wloop       halt
      extra       call just_wait
                  call rom.break_key
                  jr   NC, demo_exit
                  ld   hl, dvar.rotate_flags
                  bit  B_EFFECT_OVER, [hl]
                  jr   Z, wloop
                  res  B_EFFECT_OVER, [hl]
                  ret
      set_delay   ld   [dvar.general_delay], a
      reset       ld   hl, just_wait
      set_extra   ld   [extra + 1], hl
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

  # next random number from math_i library
  next_rnd      rnd
                ret

  # entry point for extra task
  next_rnd2     ld  hl, [dvar.seed2]
                call next_rnd
                ld  [dvar.seed2], hl
                ret

  # Parameters:
  #   HL: source address (compressed data)
  #   DE: destination address (decompressing)
  # -----------------------------------------------------------------------------
  # decompress    dzx7_standard

  # create full sin/cos table from minimal sintable
  make_sincos   create_sincos_from_sintable sincos, sintable:sintable

  # create shuffled array
  shuffle       shuffle_bytes_source_max256 next_rnd2, target:hl, length:a, source:forward_ix
                ret

  forward_ix    jp   (ix)

  # |a| (a & 7) | ((a & 0b111000) << 2)
  # mangle_line   ld   c, a
  #               anda 0b00111000
  #               2.times { add  a }
  #               ld   b, a
  #               ld   a, c
  #               anda 0b00000111
  #               ora  b
  #               ret

  # lines_even    ld   a, c
  #               add  a
  #               jr   mangle_line
  # lines_odd     ld   a, c
  #               scf
  #               adc  a
  #               jr   mangle_line

  identity      ld   a, c
                ret

  x_shuffle     ld   hl, dvar.shuffle_state
                inc  [hl]
                ld   l, [hl]
                ld   h, patt_shuffle >> 8
                ld   l, [hl] # index 
                ld   h, pattern_buf >> 8 # pattern address
                ret

  # Outputs 16x15 printable character.
  #
  # a' - character to print
  # d - a vertical row (0-191) to start printing at
  # e - a byte column (0-31) to start printing at
  print_big_chr ytoscr d, col:e, t:c
                ld   c, 8             # 8 character lines
                exx                   # save screen address and height
                ex   af, af           # restore code
                char_ptr_from_code [vars.chars], a, tt:de
                enlarge_char8_16 compact:false, over: :or, scraddr:nil, assume_chars_aligned:true
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

  # x1:  (256*(-(a/16.0)-(dx1 * xs) - (dx2 * ys))).truncate,
  # y1:  (256*16*(8-(dy1 * xs) - (dy2 * ys))).truncate,
  # dx1: (scale*Math.cos(angle) * 256).truncate,
  # dy1: (scale*Math.sin(angle) * 256 * 16).truncate,
  # dx2: (scale*-Math.sin(angle) * 256).truncate,
  # dy2: (scale*Math.cos(angle) * 256 * 16).truncate

  with_saved :rotate_int, :all_but_ixiy, :exx, :ex_af, :all_but_ixiy, ret: :after_ei do
                  ld   [save_sp + 1], sp
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

            # ld   a, 5
            # out  (254), a
                  ld   sp, intr_stk_end
                  call music.play
                  call animation
      #             ld   b, 20
      # busyloop    nop
      #             djnz busyloop
    # extra         call extra_wait

                  # calculate new coords (rotate and so on)
                  ld   a, [dvar.rotate_flags]
            # out  (254), a
                  rra  # B_ROTATE_SIMPLY
                  jr   NC, update_ctrls

                  # ld   hl, [dvar.move_x] # -683
                  # ld   sp, dvar.pattx_control.value
                  # pop  bc
                  # add  hl, bc
                  # push hl

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

    skip_rotate   rra  # B_ENABLE_ZOOM
                  # jr   NC, skip_scale_sm
                  sbc  a, a
                  add  b
                  ld   b, a
                  # dec  b  # scale
                  push bc
                  jp   P, start_rotate0 # scale >= 0
                  xor  a  # scale < 0 ? scale = - (scale + 1)
                  inc  b  # scale + 1
                  sub  b  # a = 0 - (scale + 1)
                  ld   b, a
                  jr   start_rotate1
    # skip_scale_sm push bc
    #               jr   start_rotate0

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

    save_sp       ld   sp, 0      # set on top
            # xor  a
            # out  (254), a
  end # ei; ret

  ns :extra_spin do
                  ld   hl, dvar.rotate_delay
                  ld   a, 64
                  add  [hl]
                  ld   [hl], a
                  ret  NC
                  inc  hl
                  dec  [hl]
                  ld   a, [hl]
                  cp   -64
                  ret  NZ
                  jr   signal_next
  end

  # toggle fg colors
  ns :extra_colors do
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
                  jr   Z, signal_next
                  inc  hl
                  jp   M, check_control
                  ld   [dvar.text_cursor], hl
                  cp   32
                  jr   C, handle_wait
                  ex   af, af
                  ld   a, e
                  add  2
                  ld   [dvar.at_position.column], a
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
                  call next_rnd2
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
    randomize     call next_rnd2
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

  # animate frames at dvar.pattern_bufh
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

  ns :make_figurines do
                  clrmem pattern_ani1, 3*256, 0x02
                  clrmem pattern_ani4, 3*256, 0b01111110
                  ld   c, 0b10000111 # counter | color mask
                  ld   hl, ludek1_data
                  ld   d, pattern_ani1 >> 8
                  xor  a
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
                  # 1st step color bit 0
                  # ld   hl, ludek1a_data1
                  ld   c, 0b11110111 # bit 0
                  cpl    # a: 0xFF
                  # ld   d, pattern_ani4 >> 8
                  call make_figurines_step1
                  # 2nd step
                  ld   hl, ludek2a_data1
                  ld   d, pattern_ani5 >> 8
                  call make_figurine_plane
                  # 3rd step
                  # ld   hl, ludek3a_data1
                  # ld   d, pattern_ani6 >> 8
                  call make_figurine_plane
                  # 1st step color bit 1
                  # ld   hl, ludek1a_data2
                  ld   c, 0b11101111 # bit 1
                  ld   d, pattern_ani4 >> 8
                  call make_figurines_step1
                  # 2nd step
                  ld   hl, ludek2a_data2
                  ld   d, pattern_ani5 >> 8
                  call make_figurine_plane
                  # 3rd step
                  # ld   hl, ludek3a_data2
                  # ld   d, pattern_ani6 >> 8
                  call make_figurine_plane
                  # 1st step color bit 2
                  ld   hl, ludek1a_data4
                  ld   c, 0b11011111 # bit 2
                  ld   d, pattern_ani4 >> 8
                  call make_figurines_step1
                  ld   hl, ludek1b_data4
                  ld   d, pattern_ani4 >> 8
                  call make_figurines_step1
                  # 2nd step
                  ld   hl, ludek2a_data4
                  ld   d, pattern_ani5 >> 8
                  call make_figurine_plane
                  # 3rd step
                  # ld   hl, ludek3a_data4
                  # ld   d, pattern_ani6 >> 8
                  call make_figurine_plane
                  # 1st step color bit 4 (brightness)
                  # ld   hl, ludek1a_data8
                  ld   c, 0b10111111 # bit 4
                  ld   d, pattern_ani4 >> 8
                  call make_figurines_step1
                  # 2nd step
                  ld   hl, ludek2a_data8
                  ld   d, pattern_ani5 >> 8
                  call make_figurine_plane
                  # 3rd step
                  # ld   hl, ludek3a_data8
                  # ld   d, pattern_ani6 >> 8
                  call make_figurine_plane
                  ret
  end

  ns :make_figurines_step1 do
                  ld   b, 3
    figloop       push bc
                  push hl
                  call make_figurine_plane
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
    mloop         push af
                  push bc
                  push de
                  xor  [hl]
                  inc  hl
                  push hl
                  ex   de, hl
                  scf
                  rla
                  ld   b, a
    bitloop       sbc  a
                  ld   e, a                    # c: value to set
                  xor  [hl]                    # original ^ value
                  anda c                       # (original ^ value) & ~mask
                  xor  e                       # ((original ^ value) & ~mask) ^ value
                  ld   [hl], a
                  inc  l
                  rl   b
                  jr   NZ, bitloop
                  pop  hl
                  pop  de
                  pop  bc
                  ld   a, e
                  add  0x10
                  ld   e, a
                  pop  af
                  djnz mloop
                  inc  d                       # next pattern
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
  intro_text    data "\x08\x92\x82G.D.C.\x04\x82\xA0presents\x1F\xFF\xF3\x85\x4FV O R T E X\x97\x674k\x04"
                db 0
  greetz_text   data "\xF1\x81\x18Respec' @:\x92\x30\x04Fred\x92\x40\x04Grych\x92\x50\x04KYA\x92\x60\x04M0nster\x92\x70\x04Tygrys\x92\x80\x04Voyager\x92\x90\x04Woola-T"
                data "\x1F\xFF\xF4\x81\x10Made\x8A\x20for\x8F\x30SPECCY\x96\x4004.19"
                data "\x04\x84\x60by r-type"
                data "\x04\x86\x80of GDC"
                data "\x1F\xFF\x82\x30\xf0Thanks\x89\x48for\x8A\x60watching!\x04\x8e\x80BYE!!!\x1F"
                db 0

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

  pattern4_data db  0xA1, 0x00, 0x00, # # bright red
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

  ludek_anim1   db pattern_ani1>>8, 6, pattern_ani2>>8, 6, pattern_ani3>>8, 6, pattern_ani2>>8, 0
  ludek_anim2   db pattern_ani4>>8, 6, pattern_ani5>>8, 6, pattern_ani6>>8, 6, pattern_ani5>>8, 0
  ludek_anim1a  db [pattern_ani1>>8, 1, pattern_ani4>>8, 1]*3,
                   [pattern_ani2>>8, 1, pattern_ani5>>8, 1]*3,
                   [pattern_ani3>>8, 1, pattern_ani6>>8, 1]*3,
                   [pattern_ani2>>8, 1, pattern_ani5>>8, 1]*2,
                   pattern_ani2>>8, 1, pattern_ani5>>8, 0

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

  # same as ludek2a_data2
  ludek2_data   db (9<<4|4), 7,
                   0b01111110,
                   0b01110110,
                   0b01111010,
                   0b00111100,
                   0b01110110,
                   0b01101110,
                   0b01110111

  # same as ludek3a_data2
  ludek3_data   db (9<<4|4), 7,
                   0b11111110,
                   0b11011011,
                   0b10111101,
                   0b01111100,
                   0b11101111,
                   0b11000111,
                   0b11100010

  # 1 - clear color bit-0
  # step 1
  ludek1a_data1 db (6<<4|4), 6,
                   0b00011000,
                   0b00111100,
                   0b01111110,
                   0b01101110,
                   0b01101110,
                   0b01110110
  # step 2
  ludek2a_data1 db (9<<4|4), 3,
                   0b01111110,
                   0b01110110,
                   0b01111010
  # step 3
  ludek3a_data1 db (9<<4|4), 3,
                   0b11111110,
                   0b11011011,
                   0b10011001

  # 1 - clear color bit-1
  # step 1
  ludek1a_data2 db (3<<4|4), 13,
                   0b00001000,
                   0b00000000,
                   0b00000000,
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
  # step 2
  ludek2a_data2 ludek2_data[0]
                # db (9<<4|4), 7,
                #    0b01111110,
                #    0b01110110,
                #    0b01111010,
                #    0b00111100,
                #    0b01110110,
                #    0b01101110,
                #    0b01110111
  # step 3
  ludek3a_data2 ludek3_data[0]
                # db (9<<4|4), 7,
                #    0b11111110,
                #    0b11011011,
                #    0b10111101,
                #    0b01111100,
                #    0b11101111,
                #    0b11000111,
                #    0b11100010

  # 1 - clear color bit-2
  # step 1
  ludek1a_data4 db (1<<4|4), 2,
                   0b00111100,
                   0b01111110
  ludek1b_data4 db (12<<4|4), 4,
                   0b00111100,
                   0b00011000,
                   0b00011000,
                   0b00011100
  # step 2
  ludek2a_data4 db (12<<4|4), 4,
                   0b00111100,
                   0b01110110,
                   0b01101110,
                   0b01110111
  # step 3
  ludek3a_data4 db (11<<4|4), 5,
                   0b00100100,
                   0b01111100,
                   0b11101111,
                   0b11000111,
                   0b11100010

  # 1 - clear color bright bit
  # step 1
  ludek1a_data8 db (1<<4|4), 15,
                   0b00111100,
                   0b01111110,
                   0b00110100,
                   0b00111110,
                   0b00011100,
                   0b00010000,
                   0b00000000,
                   0b00000000,
                   0b00011000,
                   0b00011000,
                   0b00101100,
                   0b00000000,
                   0b00000000,
                   0b00000000,
                   0b00011100
  # step 2
  ludek2a_data8 db (9<<4|4), 7,
                   0b00001000,
                   0b00000100,
                   0b00110000,
                   0b00000000,
                   0b00000000,
                   0b00000000,
                   0b01110111
  # step 3
  ludek3a_data8 db (9<<4|4), 7,
                   0b00100100,
                   0b01000010,
                   0b10000001,
                   0b00000000,
                   0b00000001,
                   0b00000001,
                   0b11100010

  import        Music, :music, override: {'music.sincos': sincos}
end

class Program
  include Z80
  include Z80::TAP

  GDC_SEED = 12347 # 640, 65535, 7777, 351, 9291, 6798, 4422, 1742

  GDC = ::GDC.new 0x8000

  label_import  ZXSys
  macro_import  ZX7

                ld   hl, code_zx7
                ld   de, GDC.org # start address
                push de
                call decompress
                ld   hl, GDC_SEED
                ld   [vars.seed], hl
                ret  # jump [sp]
                # pop  hl
                # jp   (hl)

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

def display_labels(program, names)
  names.map {|n| [n,program[n]]}
  .sort_by {|(n,v)| v}
  .each do |(name, value)|
    puts "  #{name.ljust(30)}: 0x#{'%04x'%value} #{value}"
  end
end

display_labels gdc, %w[
start +start end_of_code
rotate_int +rotate_int
control_value +control_value
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
pattern_ani1
pattern_ani2
pattern_ani3
pattern_ani4
pattern_ani5
pattern_ani6
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
dvar.seed1 dvar.seed2
dvar
+dvar
dvar_end
mini_stk_end intr_stk_end
sincos dvar.pattern dvar.fgcolor dvar.at_position patt_shuffle pattern_buf
music music.init music.play music.mute music.music music.music.play
music.instrument_table music.notes music.ministack music.note_to_cursor music.fine_tones
music.track_stack_end music.empty_instrument
music.music_control.counter
music.music_control +music.music_control
]

bootstrap = Program.new 0x4000
# puts bootstrap.debug[0..52]
code_compressed = ZX7.compress(Program::GDC.code[0, Program::GDC[:music] - Program::GDC.org])
music_compressed = ZX7.compress(Program::GDC.code[Program::GDC[:music] - Program::GDC.org, Program::GDC['+music']])
puts "COMPRESSED TOTAL SIZE:\t#{bootstrap.code.bytesize}"
puts "COMPRESSED BUNDLE SIZE:\t#{bootstrap['+code_zx7']} < #{Program::GDC.code.bytesize}"
puts "COMPRESSED CODE SIZE:\t#{code_compressed.bytesize} < #{Program::GDC[:music] - Program::GDC.org}"
puts "COMPRESSED MUSIC SIZE:\t#{music_compressed.bytesize} < #{Program::GDC['+music']}"
puts "COMPRESSED SEPARATELY:\t#{code_compressed.bytesize + music_compressed.bytesize}"

# Z80::TAP.read_chunk('gdc/loader_gdc_screen.tap').save_tap 'gdc.tap'
program = Basic.parse_source <<-END
   1 RANDOMIZE : RANDOMIZE USR VAL "32768": STOP
9999 CLEAR VAL "32767": LOAD ""SCREEN$ : RANDOMIZE USR VAL "16384"
END
program.start = 9999
puts program.to_source escape_keywords:true
program.save_tap 'gdc'
bootstrap.save_tap 'gdc', append: true

Z80::TAP.parse_file('gdc.tap') do |hb|
    puts hb.to_s
end
# Copyright © 2019 r-type/GDC (Rafał Michalski) <royal@yeondir.com>
# This work is free. You can redistribute it and/or modify it under the
# terms of the Do What The Fuck You Want To Public License, Version 2,
# as published by Sam Hocevar. See the COPYING file for more details.
require 'z80'
require_relative 'gdc_layout'

class GDCRenderer
  include Z80

  ##
  # This constant controls rendering mode and may be one of:
  #
  # * false - renders from 0 to 22 attribute line
  # * true - renders full screen
  # * :center - renders from 1 to 23 attribute line
  #
  FULL_SCREEN_MODE = false

  # requires overrides: music, next_rnd, animation

  macro_import    MathInt
  macro_import    Utils::SinCos
  label_import    ZXLib::Sys
  label_import    GDCLayout

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

  export :auto

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

  ##############
  # Rotozoomer #
  ##############

  with_saved :render_task, :all_but_ixiy, :exx, :ex_af, :all_but_ixiy, ret: :after_ei do
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

end

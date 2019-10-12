# Copyright © 2019 r-type/GDC (Rafał Michalski) <royal@yeondir.com>
# This work is free. You can redistribute it and/or modify it under the
# terms of the Do What The Fuck You Want To Public License, Version 2,
# as published by Sam Hocevar. See the COPYING file for more details.
require 'z80'
require 'zxlib/sys'
require 'zxutils/bigfont'
require_relative 'gdc_layout'
require_relative 'gdc_renderer'

class GDCEffects
  include Z80
  include GDCLayout::Flags

  FULL_SCREEN_MODE = GDCRenderer::FULL_SCREEN_MODE

  # requires overrides: music, next_rnd2

  macro_import    Stdlib
  label_import    ZXLib::Sys, macros: true
  macro_import    ZXLib::Gfx
  macro_import    ZXUtils::BigFont
  label_import    GDCLayout

  export :auto

  # Do some *extra* effect work (if possible) each frame and return when the effect is over.
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
    wait_for_hl   ld   [dvar.counter_sync], hl
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
    # paint bits_view pixels as the pattern cells' ink color
    set_buf_a     ld   de, pattern_buf        # de: target pattern address
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
                  cp   0x80
                  jr   C, cloop               # repeat until all character lines have been painted
    # swap pattern buffers
                  ld   a, d
                  ld   [dvar.pattern_bufh], a # set the painted pattern for rendering
                  xor  2
                  ld   [set_buf_p_hi], a      # set the shadow pattern for painting
    # left scroll each 16 bits of bits_view and populate rightmost bits from the char_data
                  ld   b, 8                   # b: line counter
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
                  ld   de, dvar.scroll_ctrl.char_data
                  ld   bc, 8
                  ldir                        # copy the shape of the character to dvar.scroll_ctrl.char_data
    # prevents zoom and slowly forces the advanced pan control to the desired position
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

  # Sets the screen attributes to the value given in accumulator and border to paper bits and clears all the pixels.
  ns :clear_screen do
                  clrmem  mem.attrs, mem.attrlen, a
    set_border_cr anda 0b00111000
                  3.times { rrca }
                  out  (io.ula), a
                  call clearscr
                  ret
  end

  # Clears the pixel screen.
  ns :clearscr do
                clrmem  mem.screen, mem.scrlen, 0
                ret
  end

  export :noauto

  ###############
  # Subroutines #
  ###############

  # The simplest *extra* task: just waits general_delay iterations.
  just_wait   ld   hl, dvar.general_delay
              dec  [hl]
              ret  NZ
              pop  af
              ret

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

end

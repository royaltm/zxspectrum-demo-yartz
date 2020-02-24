# -*- coding: BINARY -*-
#
# Copyright © 2019 r-type/GDC (Rafał Michalski) <r-type@yeondir.com>
# This work is free. You can redistribute it and/or modify it under the
# terms of the Do What The Fuck You Want To Public License, Version 2,
# as published by Sam Hocevar. See the COPYING file for more details.
require 'rubygems'
require 'bundler/setup'
require 'z80'
require 'z80/math_i'
require 'z80/stdlib'
require 'zxlib/gfx'
require 'zxlib/sys'
require 'zxlib/basic'
require 'zxutils/zx7'
require 'z80/utils/shuffle'
require 'z80/utils/sincos'
require_relative 'music'
require_relative 'gdc_layout'
require_relative 'gdc_renderer'
require_relative 'gdc_effects'
require_relative 'gdc_builders'

class GDC
  include Z80
  include Z80::TAP

  VERSION = '1.0.1'.freeze

  include GDCLayout::Flags

  ###########
  # Exports #
  ###########

  export            start

  ###########
  # Imports #
  ###########

  macro_import      Stdlib
  macro_import      MathInt
  macro_import      Utils::SinCos
  macro_import      Utils::Shuffle
  label_import      ZXLib::Sys, macros: true
  label_import      GDCLayout

  ###########
  # Helpers #
  ###########

  # These are pretty straightforward

  macro :wait_frames do |_, frames|
                  ld   a, frames
                  call wait_for_next.set_delay
  end

  macro :wait_for_music do |_, counter|
                  ld   hl, counter
                  call synchronize_music.wait_for_hl
  end

  macro :set_target_rotation_delta do |_, delta, frames:256|
                  ld   hl, ((128 + delta)&0xFF)<<8|(frames&0xFF)
                  ld   [dvar.angle_control.frms], hl
  end

  macro :set_target_zoom do |_, zoom, frames:256|
                  ld   hl, (zoom&0xFF)<<8|(frames&0xFF)
                  ld   [dvar.scale_control.frms], hl
  end

  macro :start_and_wait_for do |_, extra_fn, counter_sync:nil|
    if counter_sync
                  ld   hl, counter_sync
                  ld   [dvar.counter_sync], hl
    end
                  ld   hl, extra_fn
                  call wait_for_next.set_extra
  end

  ########
  # MAIN #
  ########

  ns :start do
                  exx
                  push hl                   # save hl'

                  di
                  ld   [save_sp_p], sp      # save system's sp
                  ld   sp, mini_stk_end     # own stack in "fast" mem

                  xor  a
                  call clear_screen

                  call music.init

                  clrmem dvar, +dvar        # clear variables

                  ld  hl, [vars.seed]       # initialize seeds
                  ld  [dvar.seed1], hl
                  ld  [dvar.seed2], hl

                  call make_sincos          # create sincos table

                  call make_pattern1        # build patterns
                  call make_pattern2
                  call make_pattern3
                  call make_pattern4
                  call make_pattern6
                  call make_figurines

                  # pre-randomize shuffle pattern indexes
                  shuffle_bytes_source_max256 target:patt_shuffle, length:256 do
                    call next_rnd2
                    ld   a, l
                  end

                  # walking b/w figurine
                  ld   hl, ludek_anim1
                  ld   [dvar.anim_start], hl
                  call animation.restart

                  # set initial zoom and angle
                  ld   hl, 0x6000
                  ld   [dvar.rotate_state.state], hl
                  # set initial panning coordinates
                  ld   hl, 0x8000
                  ld   [dvar.pattx_control.value], hl
                  ld   [dvar.patty_control.value], hl
                  # initialize auto rotate/pan control
                  ld   hl, dvar.angle_control.frms
                  ld   a, 192
                  ld   c, a
                  ld   [hl], a # dvar.angle_control.frms = 192
                  ld   de, +dvar.angle_control
                  add  hl, de
                  sub  c
                  ld   [hl], a # dvar.pattx_control.frms = 0
                  sub  c
                  add  hl, de
                  ld   [hl], a # dvar.patty_control.frms = 64
                  inc  hl      # -> dvar.patty_control.tgt_incr
                  inc  hl      # -> dvar.patty_control.cur_incr
                  ld   a, 0x80
                  ld   [hl], a # dvar.patty_control.cur_incr = neutral
                  sbc  hl, de
                  ld   [hl], a # dvar.pattx_control.cur_incr = neutral

                  # rotate simply
                  ld   hl, dvar.rotate_flags
                  ld   [hl], 1 << B_ROTATE_SIMPLY

                  # show pattern4
                  memcpy pattern_buf, pattern4, 256

                  # initialize text pointer to intro_text and text delay counter
                  ld   hl, dvar.text_delay
                  ld   [hl], 1
                  ld   hl, intro_text
                  ld   [dvar.text_cursor], hl

                  # start pattern rendering
                  setup_custom_interrupt_handler render_task

                  # "write text" effect
                  start_and_wait_for extra_text

                  wait_for_music 300

                  # figurine strobe morph
                  ld   hl, ludek_anim1a
                  ld   [dvar.anim_start], hl

                  wait_frames 20

                  # walking color figurine
                  ld   hl, ludek_anim2
                  ld   [dvar.anim_start], hl

                  # clear text
                  call clearscr

                  wait_for_music 372

                  # start rotation
                  ld   a, -1
                  ld   [dvar.rotate_delta], a
                  wait_frames 40
                  # pan view's y-axis to target the figurine's eye
                  ld   hl, 128+16
                  ld   [dvar.move_y], hl

                  # "crazy spin" effect
                  start_and_wait_for extra_spin
                  # start zooming
                  ld   hl, dvar.rotate_flags
                  set  B_ENABLE_ZOOM, [hl]
                  # pan view's x-axis to target the figurine's eye
                  ld   hl, 0x0111
                  ld   [dvar.move_x], hl

                  wait_frames 8
                  # stop x-panning
                  ld   hl, 0
                  ld   [dvar.move_x], hl
                  # adjust x-axis
                  ld   hl, 0x8800
                  ld   [dvar.pattx_control.value], hl

                  wait_frames 60

                  # stop y-panning
                  ld   hl, 0
                  ld   [dvar.move_y], hl
                  # adjust y-axis
                  ld   hl, 0x3800
                  ld   [dvar.patty_control.value], hl

                  wait_frames 28

                  # stop animation
                  ld   hl, 0
                  ld   [dvar.anim_frames], hl
                  # set the rendering pattern adress to main buffer
                  ld   a, pattern_buf >> 8
                  ld   [dvar.pattern_bufh], a

                  # "brake spin" effect
                  start_and_wait_for extra_unspin

                  # convert the current simple rotate angle and zoom states to advanced control
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

                  # enable advanced rotate/zoom (no panning yet)
                  ld   hl, dvar.rotate_flags
                  ld   [hl], 0

                  # "write text" effect (the text_cursor should be at title_text)
                  start_and_wait_for extra_text

                  wait_frames 80

                  # start auto panning
                  ld   hl, dvar.rotate_flags
                  set  B_RND_PATTERN, [hl]

                  # set the target zoom magnitude
                  set_target_zoom 16, frames:256

                  # ensure the pattern cells' ink color = cells' paper color
                  start_and_wait_for extra_hide2
  
                  # create the pixel grid
                  halt
                  ld   a, 0b01010101
                  call alt_clear_scr

                  set_target_rotation_delta -127, frames:256

                  # destroy the pattern with ink & paper color 0
                  ld   a, 0b00011111
                  ld   [dvar.fgcolor], a
                  start_and_wait_for extra_destroy2

                  set_target_rotation_delta 127, frames:128
                  # set the target zoom magnitude
                  set_target_zoom 255, frames:256

                  # swap cells to pattern2 and set ink color to 2
                  ld   a, 0b01011111
                  ld   [dvar.fgcolor], a
                  ld   hl, pattern2
                  ld   [dvar.pattern], hl
                  start_and_wait_for extra_swap2

                  # wait for music
                  wait_for_music 1429

                  # "cycle ink and border colors to the rhythm" effect
                  ld   a, 0b00011111           # start from 0.9
                  ld   [dvar.fgcolor], a
                  start_and_wait_for extra_colors

                  wait_frames 24
                  # set patterns' ink color to 3
                  ld   a, 3
                  call extra_colors.set_fg_color

                  # swap cells to pattern3 and set ink color to 5
                  ld   a, 0b10111111
                  ld   [dvar.fgcolor], a
                  ld   hl, pattern3
                  ld   [dvar.pattern], hl
                  start_and_wait_for extra_swap2

                  wait_for_music 1801

                  set_target_zoom 128, frames:256

                  # "cycle ink and border colors to the rhythm" effect
                  ld   a, 0b00011111           # start from 0.9
                  ld   [dvar.fgcolor], a
                  start_and_wait_for extra_colors

                  wait_frames 24
                  # set patterns' ink color to 6
                  ld   a, 6
                  call extra_colors.set_fg_color

                  wait_frames 24

                  set_target_zoom 0, frames:256

                  # destroy the pattern with ink color 6 and paper color 2
                  ld   a, 0b11011111
                  ld   [dvar.fgcolor], a
                  ld   a, 0b00010000
                  ld   [dvar.bgcolor], a
                  start_and_wait_for extra_destroy2

                  # stop auto panning
                  ld   hl, dvar.rotate_flags
                  res  B_RND_PATTERN, [hl]
                  # reset panning axes
                  ld   hl, 0x0000
                  ld   [dvar.pattx_control.value], hl
                  ld   hl, 0xC000
                  ld   [dvar.patty_control.value], hl

                  set_target_zoom 176, frames:256
                  set_target_rotation_delta 0, frames:256

                  # "spectrum analyzer" effect
                  start_and_wait_for extra_spectrum, counter_sync: 3444

                  set_target_rotation_delta 32, frames:240

                  ld   hl, 3959 - 168
                  ld   [dvar.counter_sync], hl
                  # continue "spectrum analyzer"
                  call wait_for_next

                  # zoom in
                  set_target_zoom 0, frames:256
                  # start auto panning
                  ld   hl, dvar.rotate_flags
                  set  B_RND_PATTERN, [hl]

                  ld   hl, 3959
                  ld   [dvar.counter_sync], hl
                  # continue "spectrum analyzer"
                  call wait_for_next

                  # zoom out
                  set_target_zoom 255, frames:256

                  # show pattern3
                  memcpy pattern_buf, pattern3, 256

                  # set border color and clear pattern cells' ink to 0
                  xor  a
                  call extra_colors.set_fg_clrbrd
                  # "random ink color stripes" effect.
                  start_and_wait_for extra_random
                  call wait_for_next

                  # swap cells to pattern6 and set cells' ink to cells' paper
                  ld   hl, pattern6
                  ld   [dvar.pattern], hl
                  start_and_wait_for extra_swap_hide2

                  set_target_zoom 16, frames:128

                  # "snake" effect
                  ld   a, 1
                  ld   [dvar.snake_control.counter], a
                  start_and_wait_for extra_snake, counter_sync: 5608

                  # ensure the pattern cells' ink color = cells' paper color
                  set_target_rotation_delta 80, frames:256
                  start_and_wait_for extra_hide2

                  # stop auto panning
                  ld   hl, dvar.rotate_flags
                  res  B_RND_PATTERN, [hl]
                  set_target_zoom 128, frames:256
                  set_target_rotation_delta -8, frames:256
                  # adjust panning axes
                  xor  a
                  ld   [dvar.pattx_control.vlo], a
                  ld   [dvar.patty_control.vlo], a

                  # copy rendered pattern cells to buffers: pattern_ani1, pattern_ani2 and pattern_ani3
                  memcpy pattern_ani1, pattern_buf, 256*3, reverse: false
                  # slightly delay the text progression
                  ld   hl, dvar.scroll_ctrl.bits
                  ld   [hl], 24
                  # set text for extra_scroll, dvar.text_cursor should be at scroll_text
                  ld   hl, scroll_text
                  ld   [dvar.scroll_ctrl.text_cursor], hl
                  # "scroll text" effect
                  start_and_wait_for extra_scroll, counter_sync: 6328

                  # start auto panning
                  ld   hl, dvar.rotate_flags
                  set  B_RND_PATTERN, [hl]

                  set_target_rotation_delta 10, frames:256

                  ld   hl, 6834
                  ld   [dvar.counter_sync], hl
                  # continue "scroll text"
                  call wait_for_next

                  # set the rendering pattern adress to main buffer
                  ld   a, pattern_buf >> 8
                  ld   [dvar.pattern_bufh], a
                  # restore background pattern
                  memcpy pattern_buf, pattern_ani1, 256

                  # swap cells to pattern1 and set cells' ink to cells' paper
                  ld   hl, pattern1
                  ld   [dvar.pattern], hl
                  start_and_wait_for extra_swap_hide

                  # clear the pixel grid
                  call clearscr
                  # restore the original pattern1 ink color
                  memcpy pattern_buf, pattern1, 256

                  # "write text" effect
                  ld   hl, greetz_text
                  ld   [dvar.text_cursor], hl
                  start_and_wait_for extra_text

                  wait_for_music 7990

                  # "write text" effect
                  start_and_wait_for extra_text

                  wait_for_music 8326

                  # "write text" effect
                  start_and_wait_for extra_text

                  set_target_zoom 16, frames:256
                  set_target_rotation_delta 0, frames:256

                  wait_for_music 8588

                  set_target_zoom 255, frames:256
                  set_target_rotation_delta -128, frames:256
                  # destroy the pattern with ink color 7 and paper color 0
                  xor  a
                  ld   [dvar.bgcolor], a
                  dec  a
                  ld   [dvar.fgcolor], a
                  start_and_wait_for extra_destroy

                  wait_frames 50

    demo_exit     di
                  call music.mute
                  ld   a, 0b00111000
                  call clear_screen
    save_sp_a     ld   sp, 0                # restore sp
    save_sp_p     save_sp_a + 1

                  restore_rom_interrupt_handler
                  pop  hl                   # restore hl'
                  exx
                  ld   bc, [vars.seed]
                  ret
  end # :start

  ###############
  # Subroutines #
  ###############

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

  import        GDCRenderer, override: { music: music, next_rnd: next_rnd, animation:animation }
  import        GDCEffects,  override: { music: music, next_rnd2:next_rnd2 }
  import        GDCBuilders

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

  # Animation data: pattern MSB, no. frames delay, ... , 0
  ludek_anim1   db pattern_ani1>>8, 6, pattern_ani2>>8, 6, pattern_ani3>>8, 6, pattern_ani2>>8, 0
  ludek_anim2   db pattern_ani4>>8, 6, pattern_ani5>>8, 6, pattern_ani6>>8, 6, pattern_ani5>>8, 0
  ludek_anim1a  db [pattern_ani1>>8, 1, pattern_ani4>>8, 1]*3,
                   [pattern_ani2>>8, 1, pattern_ani5>>8, 1]*3,
                   [pattern_ani3>>8, 1, pattern_ani6>>8, 1]*3,
                   [pattern_ani2>>8, 1, pattern_ani5>>8, 1]*2,
                   pattern_ani2>>8, 1, pattern_ani5>>8, 0

  # This must be last, workspace required after Music
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

  GDC = ::GDC.new 48000, override: { 'music.io_ay': io_ay }

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
render_task +render_task
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
] + GDCLayout::DemoVars.members_of_struct.keys.map{|n| 'dvar.'+n }

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

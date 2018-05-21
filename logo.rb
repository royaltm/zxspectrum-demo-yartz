# -*- coding: BINARY -*-
here = File.expand_path('..', __dir__)
$:.unshift(here) unless $:.include?(here)

require 'z80'
require 'z80/stdlib'
require 'z80/math_i'
require 'zxlib/gfx'

class Program
  include Z80
  include Z80::TAP

  macro_import ZXGfx
  macro_import Z80Lib
  macro_import Z80MathInt

  logo_shadow addr 0x4000

                  exx
                  push hl
                  ld   hl, logo_data
                  ld   bc, (62 << 8) | 18
                  call prepare_logo
                  pop  hl
                  exx
                  ret

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
                ret
  end

  logo_data     import_file 'gdc/gdc_logo2.bin'

end

prog = Program.new 0x8000
prog.save_tap 'gdclogo'
puts prog.debug
puts prog[:logo_data] - prog.org

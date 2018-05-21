# -*- coding: BINARY -*-
require 'z80'
require 'zxlib/gfx'
require 'zxlib/sys'

class BigFont
  include Z80

  ###########
  # Exports #
  ###########

  export print_c

  ###########
  # Imports #
  ###########

  macro_import  ZXGfx
  label_import  ZXSys

  ##########
  # Macros #
  ##########

  module Macros
    def wide_pixels(f1, f2, unroll:true)
      raise ArgumentError unless [f1, f2].all?{|r| register?(r)} and f1 != f2
      isolate do
        if unroll
          4.times do
                      rrca
                      rr  f2
                      sra f2
          end
          4.times do
                      rrca
                      rr  f1
                      sra f1
          end
        else
                      ld   b, 4
          wideloop1   rrca
                      rr   f2
                      sra  f2
                      djnz wideloop1
                      ld   b, 4
          wideloop2   rrca
                      rr   f1
                      sra  f1
                      djnz wideloop2
        end
      end
    end

    def mix_pixels(f1, f2, unroll:true, &block)
      isolate do
        if unroll
          4.times do
                    sla  f1
                    rla
                    sla  f2
                    rla
          end
                    ns(&block)
          4.times do
                    sla  f1
                    rla
                    sla  f2
                    rla
          end
        else
                    ld   b, 4
          mixloop1  sla  f1
                    rla
                    sla  f2
                    rla
                    djnz mixloop1
                    ns(&block)
                    ld   b, 4
          mixloop2  sla  f1
                    rla
                    sla  f2
                    rla
                    djnz mixloop2
        end
      end
    end

    # a - 1st char font line
    # b - 2nd char font line (preserved)
    # t1, t2 - temporary registers
    # o - output register: 1st byte  02468ACE
    # a - output register: 2nd byte  13579BDF
    #     for output pixels: 01234567 89ABCDEF
    def antialiased_line(b, o, t1, t2)
      raise ArgumentError if [a, b, o, t1, t2].uniq.size != 5
      isolate do
                  # a1 = a | (a>>1) & 0xff
                  # a2 = a | (a<<1) & 0xff
                  # b1 = b | (b>>1) & 0xff
                  # b2 = b | (b<<1) & 0xff
                  # o, a = b1&a1&(a|b), b2&a2&(a|b)
                  ld   t1, a   # a
                  ora  b       # a|b, clears CF=0
                  ld   t2, a   # a|b
                  ld   a, t1
                  rra          # (a >> 1) CF==0
                  ora  t1      # (a >> 1) | a, clears CF=0
                  ld   o, a    # a1 = (a >> 1) | a
                  ld   a, b    # b
                  rra          # (b >> 1) CF==0
                  ora  b       # b1 = (b >> 1) | b
                  anda o       # b1&=a1
                  anda t2      # b1&a1&=(a|b)
                  ld   o, a    # b1&a1&(a|b)

                  ld   a, t1   # a
                  add  a       # (a << 1)
                  ora  t1      # (a << 1) | a
                  ld   t1, a   # a2 = a | (a << 1)
                  ld   a, b    # b
                  add  a       # (b << 1)
                  ora  b       # b2 = (b << 1) | b
                  anda t1      # b2&=a2
                  anda t2      # b2&a2&=(a|b)
      end
    end

    # calculate character font address
    # a - printable ascii character
    # th, tl - temporary pair of registers
    # chars - font address: hl, address, or label or a label pointer
    # hl - output address of the 1st font byte
    # Modifies: af, th, tl, hl
    def char_font_ptr(chars, th, tl)
      raise ArgumentError unless ((register?(chars) and chars == hl) or address?(chars)) and th|tl != hl
      isolate do
                  ld  hl, chars unless chars == hl
                  3.times { rlca }
                  ld  tl, a
                  anda 0b00000111
                  ld  th, a
                  xor tl
                  ld  tl, a
                  add hl, th|tl
      end
    end

    ##
    # Outputs 16x16 antialiased printable character.
    #
    # a - character to print
    # d - a vertical row (0-191) to start printing at
    # e - a byte column (0-31) to start printing at
    def print_char(chars, compact:true, over:false)
      isolate do |eoc|
                  ex   af, af
                  ytoscr d, h, l, b, e
                  ex   af, af
                  ld   c, 8
                  exx
                  char_font_ptr chars, d, e # font in hl'
                  ld   a, [hl] # font 1st line
                  inc  l

        tloop     exx
                  wide_pixels d, e, unroll:!compact
                  ex   af, af
        if over
                  ld   a, d
                  ora  [hl]
                  ld   [hl], a # put on screen over
                  inc  l
                  ld   a, e
                  ora  [hl]
                  ld   [hl], a # put on screen over (leave hl at 2nd half)
        else
                  ld   [hl], d # put on screen
                  inc  l
                  ld   [hl], e # put on screen (leave hl at 2nd half)
        end
        if compact
                  call next_line
        else
                  nextline h, l, eoc
        end
                  dec  c
                  jr   Z, eoc
                  ex   af, af
                  exx

                  ld   c, [hl] # b <- font next line
                  inc  l

                  antialiased_line c, e, b, d
                  ld   d, a    # 2nd byte

                  mix_pixels(e, d, unroll:!compact) do
                    ex af, af  # save 1st half
                  end
                  exx
        if over
                  ora  [hl]
                  ld   [hl], a # put on screen 2nd half over
                  dec  l
                  ex   af, af
                  ora  [hl]
                  ld   [hl], a # put on screen 1st half over
        else
                  ld   [hl], a # put on screen 2nd half
                  dec  l
                  ex   af, af
                  ld   [hl], a # put on screen 1st half
        end
        if compact
                  call next_line
        else
                  nextline h, l, eoc
        end
                  exx
                  ld   a, c    # 2nd line
                  jp   tloop
        if compact
        next_line label
                  nextline h, l do
                    pop af
                    jr  eoc
                  end
                  ret
        end
      end
    end
  end
  extend Macros

  ##############
  # PRINT CHAR #
  ##############

  # ZX Spectrum's ROM compatible CHAN output routine
  ns :print_c do
    with_saved bc, de, hl, :exx, bc, de, hl, merge: true do
                  ld   de, [cursor]
                  ld   hl, c_flags
                  bit  0, [hl]
                  jp   NZ, at_control

                  cp   0x20
                  jp   C, control_char
                  ex   af, af

                  ld   a, d
                  cp   192
                  jp   NC, rom.error_5

                  ex   af, af

                  push de

                  print_char [vars.chars], compact:true

                  pop  de
                  inc  e
                  inc  e

    check_col     ld   a, e
                  cp   0x1f
                  jr   C, exit_save
    next_line     ld   e, 0
                  ld   a, 16
                  add  d
                  ld   d, a

    exit_save     ld   [cursor], de
    end # with_saved
                  ret

    control_char  cp   ?\r.ord
                  jr   NZ, skip_eol
                  ld   e, 0x20
                  jr   check_col
    skip_eol      cp   0x16         # AT (y, x)
                  jr   NZ, exit_save
                  ld   [hl], 0x03   # c_flags = AT_ROW
                  jr   exit_save

    at_control    bit  1, [hl]
                  jr   Z, at_col_ctrl
                  ld   d, a         # set row
                  ld   [hl], 0x01   # c_flags = AT_COL
                  jr   exit_save
    at_col_ctrl   ld   e, a         # set col
                  ld   [hl], 0x00   # c_flags = NONE
                  jr   check_col

    cursor        words 1
    c_flags       bytes 1
  end
end

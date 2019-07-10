require 'z80'
require_relative 'gdc_layout'
require_relative 'gdc_patterns'

class GDCBuilders
  include Z80

  macro_import    Stdlib
  label_import    GDCLayout

  export :auto

  # Forward to +ix+. Call it to emulate: +call ix+.
  forward_ix      jp   (ix)

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

  import          GDCPatterns
end

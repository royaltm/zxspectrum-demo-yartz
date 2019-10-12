# Copyright © 2019 r-type/GDC (Rafał Michalski) <royal@yeondir.com>
# This work is free. You can redistribute it and/or modify it under the
# terms of the Do What The Fuck You Want To Public License, Version 2,
# as published by Sam Hocevar. See the COPYING file for more details.
require 'z80'

class GDCPatterns
  include Z80

  export :auto

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

end

# Copyright © 2019 r-type/GDC (Rafał Michalski) <royal@yeondir.com>
# This work is free. You can redistribute it and/or modify it under the
# terms of the Do What The Fuck You Want To Public License, Version 2,
# as published by Sam Hocevar. See the COPYING file for more details.
require 'z80'
require 'z80/utils/sincos'
require 'zxlib/sys'

class GDCLayout
  include Z80

  module Flags
    # rotate_flags bit constants
    B_ROTATE_SIMPLY = 0 # if set simple rotator is enabled
    B_ENABLE_ZOOM   = 1 # if set simple rotator also simple zooms back and forth
    B_RND_PATTERN   = 1 # if B_ROTATE_SIMPLY is unset and this is set, the advanced control moves the pattern around
    B_EFFECT_OVER   = 7 # is set when some extra effect is over
  end

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

  # Control structure of the simple rotate'n'zoom.
  class RotateState < Label
    angle byte    # only for simple rotating when B_ROTATE_SIMPLY is set
    scale byte    # only for simple zooming when B_ENABLE_ZOOM and B_ROTATE_SIMPLY is set
    state angle word # union as word
  end

  # Control structure of the auto random rotate'n'zoom & pan.
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
    bits_view   word, 8   # 16x8 pixel bit view of the scroll (bits being painted onto pattern cells)
    bits        byte      # counter of bits to shift: 0..8
    char_data   byte, 8   # a copy of the next text character shape being scrolled into bits_view
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
    pattern         pattern_lo word    # target pattern address in the process of replacing the current one
    fgcolor         byte               # pixel grid's current fg color on the 3 most significant bits
    bgcolor         byte               # pixel grid's current bg color on the paper bits (3-5), used by extra_destroy
    at_position     ZXLib::Sys::Cursor # text screen cursor
    general_delay   byte               # general purpose delay counter
    text_delay      byte               # text delay counter
    text_cursor     word               # pointer to the next character to print
    colors_delay    byte               # colors delay counter
    shuffle_state   byte               # current shuffle index
    rotate_flags    byte               # rotation control with B_* flags
    scale_control   ValueControl       # auto scale control
    angle_control   ValueControl       # auto angle control
    pattx_control   ValueControl       # auto pan x control
    patty_control   ValueControl       # auto pan y control
    snake_control   SnakeControl       # snake control
    rotate_state    RotateState        # simple zoom & scale control
    rotator         Rotator, 2         # 2 rotator matrixes: 1st for left to right and 2nd for right to left
    x1              word               # normalized pan x shift for current iteration
    move_x          word               # simple move delta x
    move_y          word               # simple move delta y
    rotate_delay    byte               # a delay for rotate delta
    rotate_delta    byte               # simple rotate delta
    pattern_bufh    byte               # address (MSB) of the currently rendered pattern
    anim_wait       byte               # animation slowdown counter
    anim_frames     word               # current animation frames address; no animation if 0
    anim_start      word               # restart animation frames address
    seed1           word               # 1st seed for the auto random control
    seed2           word               # 2nd seed for extra tasks' randomizer
    counter_sync_lo byte               # music counter target (LSB)
    counter_sync_hi byte               # music counter target (MSB)
    counter_sync    counter_sync_lo word
    scroll_ctrl     ScrollControl      # scroll text control
    spectrum        SpectrumControl    # spectrum analyzer control
    # chan_a          WaveControl
    # chan_b          WaveControl
    # chan_c          WaveControl
  end

  ##########
  # Layout #
  ##########

  export :auto

  sincos        addr 0xE700, Utils::SinCos::SinCos
  pattern1      addr sincos[256]
  pattern2      addr pattern1[256]
  pattern3      addr pattern2[256]
  pattern4      addr pattern3[256]
  pattern6      addr pattern4[256]

  dvar          addr 0xF000, DemoVars
  dvar_end      addr :next, 0
  intr_stk_end  addr 0xF600, 2
  mini_stk_end  addr intr_stk_end[128], 2
  patt_shuffle  addr mini_stk_end[0]        # shuffle pattern indexes
  pattern_buf   addr patt_shuffle[256]      # main pattern data
  pattern_ani1  addr pattern_buf[256]       # animation pattern data
  pattern_ani2  addr pattern_ani1[256]      # animation pattern data
  pattern_ani3  addr pattern_ani2[256]      # animation pattern data
  pattern_ani4  addr pattern_ani3[256]      # animation pattern data
  pattern_ani5  addr pattern_ani4[256]      # animation pattern data
  pattern_ani6  addr pattern_ani5[256]      # animation pattern data
  # wave_control  addr 0, WaveControl
end

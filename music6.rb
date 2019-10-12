# Copyright © 2019 r-type/GDC (Rafał Michalski) <royal@yeondir.com>
# This work is free. You can redistribute it and/or modify it under the
# terms of the Do What The Fuck You Want To Public License, Version 2,
# as published by Sam Hocevar. See the COPYING file for more details.
require 'zxutils/music_box'

class Mouvement
  include ZXUtils::MusicBox::Song

  ##########
  # TRACKS #
  ##########

  tempo 128

  all_ch do
    n0
    i :instr1_quiet
  end

  # let channels desync only by a tiny bit, prevent default auto-synchronization
  synchronize_channels a: 3...3, b: 1...1, c: 2...2

  ch_a do
    32.times { p 32, 32, 32 }
  end

  ch_b do
    w 2
    rpt(8) do
      i :instr1_normal; c  3, 32, 32, 32
      i :instr1_quiet; rpt(3) { c  3, 32, 32, 32 }
    end
  end

  ch_c do
    rpt(8) do
      i :instr1_normal; g  3, 32, 32, 32
      i :instr1_quiet; rpt(3) { g  3, 32, 32, 32 }
    end
    w 1
  end

  #######################
  mark :parts1_6

  sub :track_parts1_6

  #######################
  mark :part_7

  ch_a do
    i :instr1_loud;
    c 3, 8, 16
    m2; veo; mn :mask_thrr2
    rpt(6) { d  3, 32; e  3, 32; f  3, 32; }
    p 32
  end

  ch_b do
    i :instr1_loud;
    f  0, 16, 32; g  0, 16, 32; g  0,  4, 32; f  0,  8, 16;
    i :instr1_normal; g  0, 16; i :instr1_quiet; g  0, 16
  end

  ch_c do
    i :instr1_loud;
    f  1, 16, 32; g  1, 16, 32; g  1,  4, 32; f  1,  8, 16;
    i :instr1_normal; g  1, 16, 32; i :instr1_quiet; g  1, 32
  end

  #######################
  mark :part_8

  ch_a do
    p 16, 32, 32
    mno;
    rpt(5) { d  3, 32; e  3, 32; f  3, 32; }
    v 9
    rpt(2) { g  3, 32; a 4, 32; b  4, 32; }
    v 8
    d  3, 32; e  3, 32; f  3, 32; g  3, 16, 32
    ve :env_vol_silent_slow2
    m1; rpt(2) { c 3, 16, 32 }
    m2; veo; rpt(5) { d  3, 32; e  3, 32; f  3, 32; }
  end

  ch_b do
    p 32
    p 64; i :instr4_normal; d  2, 16, 32, 64; i :instr4_loud; g  2, 16, 32; i :instr4_quiet; f  2,  4,  8, 32, 64;
    i :instr4_normal; b  3, 16, 32; i :instr4_loud; g  2, 16, 32; i :instr4_quiet; g  0, 16, 32, 64
    i :instr4_normal; d  2, 16, 32; :instr3_normal; g  2, 16, 32; i :instr1_normal; f  2, 4, 8, 16, 32
  end

  ch_c do
    p 32
    i :instr4_quiet; c  3, 16, 32, 32;
    i :instr4_loud;  b  3, 16, 32; i :instr4_normal; a  3,  4, 32, 32, 64, 64; i :instr4_loud; c  3, 16, 32;
    i :instr4_normal;  d  3, 16, 32; b  3, 8; i :instr1_loud; g  1, 16
    p 16, 32
    i :instr4_normal;  b  3, 16, 32; i :instr1_loud; a  3, 4, 8; i :instr1_normal; c  3, 16, 32
  end

  #######################
  mark :part_9

  ch_a do # part_9
    p 32
    m1; i :instr1_loud;
    f  3, 16, 32; b  4, 16; e  4, 16, 32; a  5, 16; d  5, 16, 32; g  5, 16, 32;
    i :instr3_loud;
    c  6, 16, 32; i :instr3_normal; g  5, 32; c  5, 16;
    i :instr3_quiet;
    rpt(9) { c  6, 32; g  5, 32; c  5, 32; }
    i :instr1_quiet;
    rpt(2) { g  5, 32; d  5, 32; g  4, 32; }
    rpt(2) { c  5, 32; g  4, 32; c  4, 32; }
    rpt(2) { g  4, 32; d  4, 32; g  3, 32; }
    veo; m2
    rpt(10) { c  5, 32; g  4, 32; c  4, 32; }
    rpt(2) { g  4, 32; d  4, 32; g  3, 32; }
    rpt(2) { c  4, 32; g  3, 32; c  3, 32; }
    rpt(2) { g  4, 32; d  4, 32; g  3, 32; }
    rpt(2) { c  5, 32; g  4, 32; c  4, 32; }
    rpt(2) { g  4, 32; d  4, 32; g  3, 32; }
    rpt(2) { c  4, 32; g  3, 32; c  3, 32; }
    rpt(2) { g  3, 32; d  3, 32; g  2, 32; }
  end

  ch_b do # part_9
    p 32
    i :instr1_loud;
    g  3, 16, 32, 32; c  4, 16; f  4, 32; f  4, 16; b  5, 16; e  5, 16, 64; a  6, 16, 64;
    i :instr3_loud;
    c  0, 8, 32, 32;
    ce :chord_note12; g  2, 16, 32; g  2, 16; f  2, 16; e  2, 16; d  2, 16, 32; c  2,  16, 32; c  2, 4, 8
    i :instr2_normal;
    ceo; d  0, 8, 16; e  0, 8, 16; f  0, 8, 16;
    i :instr1_loud;
    e  0, 16, 32;
    ce :chord_note12; g  2, 16, 32; g  2, 16; f  2, 16; e  2, 16; d  2, 16, 32; c  2,  16, 32; c  2, 4, 8
    i :instr2_normal;
    ceo; f  0, 8, 16; g  0, 8, 16; rpt(2) { f  0, 8, 16; e  0, 8, 16; }; f  0, 8, 16;
  end

  ch_c do # part_9
    i :instr1_loud;
    p 16, 32; a  4, 16; d  4, 16, 32; g  4, 16, 32; c  5, 16; f  5, 32, -64; f  5, 16; b  6, 16, -64;
    i :instr3_loud;
    c  1, 16, 32, 64, 32; i :instr1_loud; d  5, 16, -64;
    i :instr2_loud; d  3, 16, 32; d  3, 16; c  3, 16; b  3, 16;
    i :instr1_loud; a  3, 16, 32; g  2,  16, 32; g  2, 4, 8
    i :instr2_normal;
    d  1, 8, 16; e  1, 8, 16; f  1, 8, 16;
    i :instr1_loud;
    e  1, 16, 32;
    d  3, 16, 32; d  3, 16; c  3, 16; b  3, 16;
    a  3, 16, 32; g  2,  16, 32; g  2, 4, 8
    i :instr2_normal;
    f  1, 8, 16; g  1, 8, 16; rpt(2) { f  1, 8, 16; e  1, 8, 16; }; f  1, 8, 16;
  end

  #######################
  mark :part_10

  ch_a do # part_10
    ve :env_vol_silent_sl_saw
    g  3, 32, 64; d  3, 32, 64; g  2, 32, 64;
    rpt(15) { g  3, 32; d  3, 32; g  2, 32; }
    veo; v 7
  end

  ch_b do # part_10
    i :instr1_loud; f! 0, 16, 32, 32, 64;
    i :instr3_quiet; e  2, 1, 4, 8, 32
  end

  ch_c do # part_10
    i :instr1_loud;
    f! 1, 8, 32, 64; i :instr3_normal; a! 3, 32; c! 3, 32; i :instr3_quiet; a! 3, 1, 4, 16;
  end

  #######################
  mark :part_11

  ch_a do # part_11
    g  3, 32; d  3, 32; g  2, 32;
    m1; i :instr3_quiet
    a  4, 32; e  3, 32; a  3, 32; 
    rpt(4) { c  4, 32; g  3, 32; c  3, 32; }
    rpt(2) { d  4, 32; a  4, 32; d  3, 32; }
    f  4, 32; c  4, 32; f  3, 32; g  4, 32; d  4, 32; p 32
  end

  ch_b do # part_11
    i :instr3_quiet;
    e  2, 16, 32; f! 2, 16, 32; rpt(4) { a  3, 16, 32; }
    rpt(2) { b  3, 16, 32; }; d  3, 16, 32; e  3, 16, 32;
  end

  ch_c do # part_11
    i :instr3_quiet;
    p  32; a! 3, 32; c! 3, 16; c  3, 32; d! 3, 32;
    rpt(4) { p 32; d! 3, 32; f! 3, 32; }
    rpt(2) { p 32; f  3, 32; g! 3, 32; };
    p 32; g! 3, 32; b  4, 32;
    p 32; a! 4, 32; c! 4, 32;
  end

  #######################
  mark :part_12

  ch_a do # part_12
    rpt(4) { e  4, 32; b  4, 32; e  3, 32; }
    rpt(2) { d  4, 32; a  4, 32; d  3, 32; }
    c  4, 32; g  3, 32; c  3, 32;
    d  4, 32; a  4, 32; d  3, 32;
    rpt(4) { b  4, 32; f! 3, 32; b  3, 32; }
    a  4, 32; e  3, 32; a  3, 32;
    b  4, 32; f! 3, 32, 64; b  3, 32, 64;
  end

  ch_b do # part_12
    rpt(4) { c! 3, 16, 32; }
    b  3, 16, 32; b  3, 16, 32; a  3, 16, 32; b  3, 16, 32;
    rpt(4) { g! 2, 16, 32; }; f! 2, 16, 32; g! 2, 8;
  end

  ch_c do # part_12
    rpt(4) { p 32; g  3, 32; a! 4, 32; }
    rpt(2) { p 32; f  3, 32; g! 3, 32; }
    p 32; d! 3, 32; f! 3, 32;
    p 32; f  3, 32; g! 3, 32;
    p 32; rpt(2) { d  3, 32; f  3, 16; d  3, 16, 32; }; c  3, 32; d! 3, 16; d  3, 32; f  3, 16;
  end

  #######################
  mark :part_13

  ch_a do # part_13 (similar to part 10)
    veo; m2
    g  3, 32, 32; d  3, 32, 64; g  2, 32, 64
    rpt(7) { g  3, 32; d  3, 32; g  2, 32; }
  end

  ch_b do # part_13 (similar to part 10)
    i :instr2_normal; f! 0, 2, 4, 16;
    i :instr1_quiet;
  end

  ch_c do # part_13 (similar to part 10)
    i :instr2_normal; f! 1, 8, 32
    i :instr1_normal; e  2, 32; i :instr1_loud; a! 3, 32; c! 3, 32; a! 3, 2, 16;
    i :instr1_quiet;
  end

  #######################
  mark :part_14

  ch_a do # part_14 (similar to part 11)
    g  3, 32; d  3, 32; g  2, 32;
    m1
    a  4, 32; e  3, 32; a  3, 32; 
    rpt(4) { c  4, 32; g  3, 32; c  3, 32; }
    rpt(2) { d  4, 32; a  4, 32; d  3, 32; }
    f  4, 32; c  4, 32; f  3, 32; g  4, 32; d  4, 32; g  3, 32
  end

  ch_b do # part_14 (similar to part 11)
    e  2, 16, 32; f! 2, 16, 32; rpt(4) { a  3, 16, 32; }
    rpt(2) { b  3, 16, 32; }; d  3, 16, 32; e  3, 16, 32;
  end

  ch_c do # part_14 (similar to part 11)
    p  32; a! 3, 32; c! 3, 16; c  3, 32; d! 3, 32;
    rpt(4) { p 32; d! 3, 32; f! 3, 32; }
    rpt(2) { p 32; f  3, 32; g! 3, 32; };
    p 32; g! 3, 32; b  4, 32;
    p 32; a! 4, 32; c! 4, 32;
  end

  #######################
  mark :part_15

  ch_a do # part_15
    m2; veo; v 8
    rpt(10) { b  5, 32; f! 4, 32; b  4, 32, 128; }
    v 9
    rpt(8) { b  5, 32; f! 4, 32; b  4, 32, 128; }
    rpt(4) { c  5, 32; g  4, 32; c  4, 32, 128; }

    rpt(2) { b  5, 32; f! 4, 32; b  4, 32, 128; }
    rpt(2) { c  5, 32; g  4, 32; c  4, 32, 128; }
    rpt(2) { f  4, 32; c  4, 32; f  3, 32, 128; }
    rpt(2) { f! 4, 32; b  4, 32; f! 3, 32, 128; }
    rpt(2) { a! 4, 32; f  3, 32; a! 3, 32, 128; }
    rpt(2) { b  4, 32; f! 3, 32; b  3, 32, 128; }
    rpt(2) { e  3, 32; b  3, 32; e  2, 32, 128; }
  end

  ch_b do # part_15
    rpt(7) { g! 3, 16, 32, 128 }
    f! 3, 16, 32, 128; d! 3, 16, 32, 128; g! 3, 16, 32, 128; g! 3, 8, 16, 128, 128;
    d! 3, 16, 32, 128; f! 3, 16, 32, 128;
    rpt(8) { g! 3, 16, 32, 128; }

    rpt(1) { g! 3, 16, 32, 128; }
    f! 3, 16, 32, 128; d! 3, 16, 32, 128;
    d! 3, 16, 32, 128; d  3, 16, 32, 128; c  3, 16, 32, 128;
    a  3, 16, 32, 128; a  3, 16, 32, 128; g  2, 16, 32, 128; f  2, 16, 32, 128; d  2, 16, 32, 128;
    d  2, 16, 32, 128; c! 2, 16, 32, 128; b  2, 16, 32, 128;
  end

  ch_c do # part_15
    rpt(7) { p 32, 128; c! 4, 32; e 4, 32; }
    p 32, 64, 128; e  3, 32, 64; p 16, 32, 128;
    rpt(2) { p 32, 128; c! 4, 32; e  4, 32; }
    c! 3, 8, 16, 32, 128, 128, 128;
    rpt(5) { c! 4, 32; e  4, 16, 128; }
    rpt(4) { a! 4, 32; f  4, 16, 128; }

    c! 4, 32; e  4, 32;
    p 16, 128; e  3, 16; rpt(2) { g  3, 32; c! 4, 16, 128; }
    g  3, 32; a! 4, 32, 128; 
    p  32, 64, 128; a! 3, 32, 64;
    p  32, 128; rpt(2) { c! 3, 32; g  3, 16, 128; }
    c  3, 32; d! 3, 32;
    p  32, 128; d! 2, 16, 32, 128; rpt(2) { f! 2, 32; c  3, 16, 128; }
    f! 2, 32; a  3, 16, 32; a  2, 32, 128; 
  end

  #######################
  mark :part_16

  ch_a do # part_16
    rpt(6) { f  3, 32; c 3, 32, 128; f! 2, 32, 128; }
    rpt(4) { f! 3, 32, 128; c 3, 32, 128; f! 2, 32, 64; }
  end

  ch_b do # part_16
    rpt(6) { g! 1, 16, 32, 64; }
    rpt(4) { g! 1, 16, 32, 32; }
  end

  ch_c do # part_16
    m2; veo
    rpt(6) { p 32; d! 2, 32, 128; a! 3, 32, 128; }
    rpt(4) { p 32, 128; d! 2, 32, 128; a! 3, 32, 64; }
  end

  #######################
  mark :part_17

  ch_a do # part_17
    i :instr3_quiet; m1; f 3, 4, 8;
    i :instr_progress1;
    # rpt(3) do
    #   p 32; f  3, 8, 16; f  4, 8, 16; f  2, 8, 32; p 8, 16
    #   p 32; f  1, 8, 16; f  2, 8, 16; c  2, 8, 32; p 8, 16
    #   p 32; f  0, 8, 16; f  1, 8, 16; b  1, 8, 32; p 8, 16
    #   p 32; f  1, 8, 16; f  0, 8, 16; a  1, 8, 32; p 8, 16
    # end
    # v 0; p 2;

    # p(*([16, 32]*114));

    p 32, 16;# p     32; b  2, 16;
    p 32, 16;# f  3, 32; g  2, 16;
    p 32, 16; # g  3, 16# e  3, 32, 64; g  3, 32, 64;
    p 32; e  2, 16;#e  2, 32, 64; e  3, 32, 64;
    p  4, 8;

    # e  3, 16, 32; # ce :chord_note12;
    # p 16, 32;
    # p 16, 32;
    # b  3, 16, 32; # g  3, 16, 32
    # p 16, 32;#p 32, 64; a! 3, 32, 64 # e  3, 32, 64; a  4, 32, 64;
    # p 16, 32;
    # c  3, 16, 32;
    # p  4, 8;

    c  3, 16, 32;
    p 16, 32;
    p 16, 32;
    c! 4, 16, 32;
    p 32, 64; b  3, 32, 64 # f 2, 32, 64; # b 3; e 3
    p     16; g  2, 32; #e  2, 32; # g 2; a 3;
    p 4, 8, 16, 32;

    # d! 2, 16, 32;
    # p 16, 32; #p      16; d! 3, 32; #g! 2, 32; # d! 3
    # p  16, 32;
    # a  3, 16, 32; # e  2, 16, 32; # g  2; a  3;
    # p  16, 32;
    # p  16, 32;
    # p  16, 32;
    # p  16, 32;
    # p      16; b  3, 32;
    # p  16, 32;

    p  16, 32;
    p  16, 32;
    p  16, 32;
    p  16, 32;#p      16; b  2, 32;
    p  16, 32;
    a! 3, 16, 32;
    p  32, 64; e  2, 32, 64
    p  16, 32;
    p  16, 32;
    p  16, 32;

    # p  16, 32;
    # p      16; e  3, 32;
    # p  16, 32;
    # p  16, 32;
    # p      64; g! 3, 16, 64;
    # p  32, 64; a! 4, 32, 64;
    # p      16; a! 3, 32;
    # p  16; f! 4, 32;
    # p  16, 32;
    # p  16, 32;
    # p  16, 32;

    e  3, 16, 32;
    p  16, 32;
    p      32; d! 3, 16;
    p      16; d  3, 32;
    p      16; c! 3, 32;
    p  16, 32;
    p  16, 32;
    p  16, 32;
    p  16, 32;
    p  32, 64; a! 3, 32, 64;

    p  32, 64; b  2, 32, 64;
    p      16; c  2, 32; # e  2; g! 2
    p  16, 32;
    p  16, 32;
    p  16, 32;
    p  16, 32;
    p  16, 32;
    p      16; c! 3, 32;
    p  16, 32;
    d  2, 16, 32; # a! 3;

    b  2, 16, 32;
    p  32, 64; g! 2, 32, 64
    p  16, 32;
    p  16, 32;
    p  16, 32;
    p  16, 32;
    p  16, 32;
    p  32, 64; c! 3, 32, 64;
    p      16; d  2, 32; # a! 3;
    p      16; b  2, 32;
    p  16, 32;

    c   2, 16, 32;
    p  16, 32;
    c   3, 16, 32;
    p  32, 64; e  3, 32, 64;
    p  16, 32;
    p  16, 32;
    p  16, 32;
    p  16, 32;
    g!  2, 16, 32;
    p  16, 32;
    p      32; a!  3, 16; # d 4;

    # i :instr3_normal
    p  16, 32;
    g! 2, 16, 32; #ce :chord_note12;
    p  16, 32;
    p  16, 32;
    p  16, 32;
    p  16, 32;
    p  16, 32;#g! 2, 16, 32; #ce :chord_note12;
    p  16, 32;
    p  16, 32;
    p  16, 32;
    p  16, 32;

    m1; ceo
    i :instr1_normal_reduced
    rpt(16) { f! 4, 16, 32; }
  end

  ch_b do # part_17
    i :instr3_normal; m1; p 32; f! 0, 4, 8, -32;
    # i :instr_progress1;
    i :instr3_quiet_short;
    # rpt(3) do
    #   p 64; f! 0, 8, 16; a! 0, 8, 16; c! 0, 16, 8, -64; p 8, 16
    #   p 64; f! 1, 8, 16; a! 1, 8, 16; c! 1, 16, 8, -64; p 8, 16
    #   p 64; f! 2, 8, 16; a! 2, 8, 16; c! 2, 16, 8, -64; p 8, 16
    #   p 64; f! 3, 8, 16; a! 3, 8, 16; c! 3, 16, 8, -64; p 8, 16
    # end
    # f! 3, 2;

    p 16, 32;
    p 32; c! 2, 16;
    p 16, 32;
    p 16, 32; # c! 3, 16, 32;
    f! 3, 16, 32;
    f! 0, 16, 32;
    p  16, 32;
    f! 2, 16; p 32; #f! 2, 32;

    # c! 3, 16, 32;
    # f! 3, 16, 32;
    # p  16, 32;
    # p  16, 32;
    # p  16; c! 3, 32;
    # p  16, 32;
    # f! 3, 16; f! 3, 32;
    # p  32; f! 0, 16;
    # p  16, 32;
    # p  16; f! 2, 32;
    # p  16; f! 2, 32;

    a! 3, 16; p 32; # f! 3, 32;
    p  16, 32
    p  16, 32;
    f! 2, 16, 32;
    p 32, 64; g! 2, 32, 64;
    p     16; c! 3, 32;
    p  16, 32;
    p  32; f! 0, 16;
    p  16, 32;
    p  16; f! 2, 32;
    p  16; f! 2, 32;

    # f! 2, 16, 32;
    # p 16, 32;
    # p 16, 32;
    # c! 2, 16, 32;
    # f! 2, 16, 32;
    # f! 0, 16, 32;
    # p 16, 32;
    # p 32, 64; f! 2, 32, 64;
    # f! 2, 16; f! 2, 32;
    # p 32, 64; f! 2, 32, 64;

    f! 0, 16, 32;
    p 16, 32; #f! 0, 16, 32;
    p 16, 32; #p     32; f! 2, 16;
    f! 2, 16, 32;
    p 16, 32;
    p 16, 32;
    p 16, 32;
    p 16, 32;
    f! 0, 16, 32;
    p 16, 32;

    # p 16; f! 2, 32;
    # p 32; f! 2, 16;
    # p 16, 32;
    # p 16, 32;
    # p 16, 32;
    # p 16, 32;
    # p 16, 32;
    # p 16, 32;
    # p 32; f! 0, 16;
    # p 16, 32;
    # p 32; f! 2, 32; f! 2, 32;

    p 16, 32;
    p 16, 32;
    p 32; f! 2, 16;
    p 16, 32;
    p 16, 32;
    p 16, 32;
    p 32; f! 0, 16;
    p 16, 32;
    p 16, 32; #p 64; f! 2, 32, 64; f! 2, 32; 
    p 32, 64; f! 2, 32, 64;

    p 16, 32;
    p 16, 32;
    p     16; f! 2, 32;
    p     16; f! 0, 32;
    p 16, 32;
    p     16; f! 2, 32;
    p 32, 64; f! 2, 32, 64;
    p 16, 32;
    p 16, 32;
    f! 2, 16, 32;

    p 16, 32;
    p 16, 32;
    p 64; f! 2, 16, 64;
    f! 0, 16, 32;
    p 16, 32;
    p 32; f! 2, 16;
    f! 2, 16, 32;
    p 16, 32;
    p 16; f! 2, 32;
    p 16, 32;
    p 16, 32;

    g! 2, 16, 32;
    p 16, 32;
    g! 2, 16, 32;
    p  32, 64; g! 2, 32, 64;
    p 16, 32;
    p 32, 64; f! 0, 32, 64;
    p 16, 32;
    p 16, 32;
    p 16, 32;
    p 16, 32;
    p 32; f! 3, 16;

    i :instr3_quiet; vo;
    p 16, 32;
    p 16, 32;
    f! 0, 16, 32;
    p     16; f! 3, 32;
    p     64; f! 1, 16, 64;
    p 16, 32;
    p     16; f! 2, 32;
    p 16, 32;
    p     32; f! 3, 16;
    f! 3, 16, 32; 
    p 32, 64; f! 3, 32, 64;

    i :instr1_normal_reduced
    # mt :mask_thrr1
    rpt(16) { p 32; f! 3, 32; f! 3, 32; }
    mto;
  end

  ch_c do # part_17
    i :instr3_normal; m1; p 16; f! 1, 4, 8, -16;
    # i :instr3_normal; 
    i :instr3_quiet_short;
    # rpt(3) do
    #   f! 1, 8, 16; f! 0, 8, 16; g! 0, 8, 16; p 8, 16
    #   f! 2, 8, 16; f! 1, 8, 16; g! 1, 8, 16; p 8, 16
    #   f! 3, 8, 16; f! 2, 8, 16; g! 2, 8, 16; p 8, 16
    #   f! 4, 8, 16; f! 3, 8, 16; g! 3, 8, 16; p 8, 16
    # end
    # f! 4, 2;

    p  16, 32;
    p  16, 32;
    c! 3, 16, 32;
    p  32; c! 4, 16;
    p  32; f! 4, 32; p 32; #f! 4, 32;
    f! 5, 16; f! 4, 32;
    f! 1, 32; p 16; #f! 4, 32; f! 3, 32;
    p     32; f! 3, 16;

    # c! 4, 16, 32;
    # f! 4, 16; f! 4, 32;
    # f! 5, 32; f! 4, 16;
    # p 16, 32;
    # p     16; c! 4, 32;
    # p 16, 32;
    # f! 4, 16, 32;
    # f! 4, 16; f! 4, 32;
    # f! 5, 32; f! 4, 32; f! 1, 32;
    # f! 4, 32; f! 3, 16;
    # f! 3, 16, 32;

    a! 4, 16, 32;
    p 32; f! 5, 16; #f! 4, 32; f! 4, 32; f! 5, 32;
    f! 4, 16, 32;
    f! 3, 16, 32;
    p 32, 64; g! 3, 32, 64;
    p     16; c! 3, 32;
    p 32, 64; f! 3, 32, 64;
    f! 4, 32, 64; f! 4, 32, 64; 
    f! 5, 32; p 16; #f! 4, 32; f! 1, 32;
    f! 4, 32; f! 3, 16;
    f! 3, 32; p 16;

    # f! 3, 16, 32;
    # p 16, 32;
    # p 16, 32;
    # c! 3, 16, 32;
    # p     16; f! 3, 32;
    # p     16; f! 5, 32;
    # f! 4, 32; f! 1, 32; f! 4, 32;
    # f! 3, 16; f! 3, 32;
    # p     16; f! 3, 32;
    # p     16; f! 3, 32;

    p     16; f! 5, 32;
    f! 4, 32; f! 1, 32; p 32; #f! 4, 32;
    f! 3, 16; p 32; #f! 3, 32;
    p 16, 32;
    p 16, 32;
    p 16, 32;
    p 16, 32;
    p     32; f! 3, 32; f! 4, 32;
    p     64; f! 4, 32, 64; f! 5, 32;
    f! 4, 32; p 16; #f! 1, 32; f! 4, 32;

    # p     32; f! 3, 16;
    # f! 3, 16, 32;
    # p     32; f! 3, 32; f! 4, 32;
    # f! 4, 32; f! 5, 32; f! 4, 32;
    # p 16, 32;
    # p 16, 32;
    # p     16; f! 4, 32;
    # p 16, 32;
    # f! 4, 32; f! 4, 32; f! 5, 32;
    # f! 4, 32; f! 1, 32; f! 4, 32;
    # f! 3, 16; f! 3, 32;

    p     16; f! 3, 32;
    f! 4, 32; f! 4, 32; f! 5, 32;
    f! 4, 32, 64; f! 3, 32, 64;
    p 16, 32;
    p 16, 32;
    p     32; f! 3, 32; f! 4, 32;
    p 32; f! 5, 16; #p     32; f! 4, 32; f! 5, 32;
    p 32; f! 1, 16; #f! 4, 32; f! 1, 32; f! 4, 32;
    f! 3, 16, 32; #f! 3, 32;
    p 32, 16; #p 32, 64; f! 3, 32, 64;

    p 16, 32;
    p 16, 32;
    p 16, 32;
    f! 3, 16, 32;
    f! 5, 16; f! 1, 32; # f! 5, 32; f! 4, 32; f! 1, 32;
    p 64; f! 4, 32; f! 3, 32, 64;
    p 16, 32; #f! 3, 32, 64; f! 3, 32, 64;
    f! 4, 32, 16; #f! 3, 16;
    p 16, 32;
    f! 3, 16, 32;

    p 16, 32;
    p 16, 32;
    p     16; f! 3, 32;
    p     16; f! 5, 32;
    f! 4, 32; f! 1, 32; f! 4, 32;
    p  32, 16; #f! 3, 16; f! 3, 32;
    p  32, 16; #p     32; f! 3, 32; f! 4, 32;
    f! 3, 16, 32;
    p 32, 64; f! 3, 32, 64;
    p 16, 32;
    p 16, 32;

    g! 3, 16, 32;
    p 16, 32;
    g! 3, 16, 32;
    p  32, 64; g! 3, 32, 64;
    p     16; f! 3, 32;
    p  32, 16; #f! 4, 32, 64; f! 4, 32, 64;
    f! 5, 32; f! 4, 32; f! 1, 32;
    p  32, 16; #f! 4, 32; f! 3, 16;
    p 32, 64; f! 3, 32, 64;
    f! 4, 32; f! 5, 32; f! 4, 32;
    p     32; f! 4, 16;

    i :instr3_quiet; vo
    p 16, 32;
    p 16, 32;
    p 32; f! 4, 16; # p     32; f! 4, 32; f! 4, 32;
    f! 5, 32, 16; #f! 4, 16;
    p  32; f! 4, 16; #f! 4, 16; f! 4, 32;
    f! 5, 32, 16; #f! 4, 16;
    p 16, 32;
    f! 4, 32, 16; #f! 4, 32; f! 5, 32;
    p  32, 16; #f! 4, 16; f! 4, 32;
    f! 5, 32, 16;#p     32; f! 4, 32; f! 5, 32;
    f! 4, 16, 32; #f! 4, 32;

    # i :instr4_normal
    # f! 0
    t0; n1; n 31; ne :noise_env_down; v 0; ve :env_vol_silent_slow_u
    p 1; mn :mask_thrr4; p 2; t1; n0; veo; mno;
  end

  #######################
  mark :parts_pre_18

  sub :track_parts1_6

  #######################
  mark :part_18

  ch_a do # part_18
    i :instr3_normal;
    c 3, 8; #16, 32;
    i :instr3_quiet;
    rpt(2) { d  3, 32; e  3, 32; f! 3, 32; }
    e  3, 32; f! 3, 32; g! 3, 32; 
    f! 3, 32; g! 3, 32; a! 4, 32;
    g! 3, 32; a! 4, 32; c  4, 32;
    a! 4, 32; c  4, 32; d  4, 32;
    c  4, 32; d  4, 32; e  4, 32;
    d  4, 32; e  4, 32; f! 4, 32;
    e  4, 32; f! 4, 32; g! 4, 32;
    f! 4, 32; g! 4, 32; a! 5, 32;
    g! 4, 32; a! 5, 32; c  5, 32;
    a! 5, 32; c  5, 32; d  5, 32;
    c  5, 32; d  5, 32; e  5, 32;
    d  5, 32; e  5, 32; f! 5, 32;
    e  5, 32; f! 5, 32; g! 5, 32;
  end

  ch_b do # part_18
    i :instr2_normal
    f! 0, 8, 2, 8, 32
    i :instr1_loud
    # ce :chord_note12; 
    e  0, 4, 8; d  0, 4, 8;
  end

  ch_c do # part_18
    i :instr2_normal
    f! 1, 8
    i :instr1_quiet
    rpt(2) { c  3, 16, 32; }; d  3, 16, 32; e  3, 16, 32;
    f! 3, 16, 32; g! 3, 16, 32; a! 4, 16, 32; c  4, 16, 32; d  4, 16, 32; e  4, 16, 32;
    f! 4, 16, 32; g! 4, 16, 32; a! 5, 16, 32; c  5, 16, 32; d  5, 16, 32;
  end

  #######################
  mark :part_19

  ch_a do # part_19
    m2; veo
    rpt(24) { f! 5, 32; g! 5, 32; a! 6, 32; }
    m1; i :instr1_quiet;
    rpt(2) { g! 5, 32; a! 6, 32; c  6, 32; }
    rpt(2) { a! 6, 32; c  6, 32; d  6, 32; }
  end

  ch_b do # part_19
    i :instr1_normal; c! 0, 2, 4
    i :instr1_quiet;
    # ceo;
    e  2, 16, 32; f! 2, 16, 32; a! 3, 4, 8; d  3, 8, 16; f! 3, 16, 32; g! 3, 16, 32;
    e  3, 2, 4, 8, 16;
  end

  ch_c do # part_19
    rpt(24) { e  5, 16, 32; }
    rpt(2) { f! 5, 16, 32; } 
    rpt(2) { g! 5, 16, 32; }
  end

  #######################
  mark :part_20

  ch_a do # part_20
    m1; i :instr1_normal;
    ce :chord_note2_4_6; a! 6, 8, 16;
    m2; veo; v 7; ceo
    rpt(38) { c  6, 32; d  6, 32; e  6, 32; }
    ve :env_vol_silent_slow2
    p 4, 32
    veo; v 0
  end

  ch_b do # part_20
    c! 0,  8, 16;
    vs 45; i :instr1_quiet_vib
    e  2, 16, 32; f! 2, 16, 32; a! 3, 4, 8; d  3, 8, 16;
    f! 3, 16, 32; g! 3, 16, 32; a! 4, 16, 32; c  4, 16, 32;
    e  4,  4,  8; g! 4,  8, 16; c  5, 16, 32; d  5, 16, 32;
    a! 5,  2, 16; a! 4,  4,  8; a! 3,  4,  8; a! 2,  4,  8
    i :instr3_quiet; vo
    c  0, 8, 16, 16, 32;
    veo; v 0
  end

  ch_c do # part_20
    i :instr1_normal
    c! 1,  8, 16;
    i :instr1_silencio
    rpt(38) { a! 6, 16, 32; }
    ve :env_vol_silent_slow2
    p 4, 32
    veo; v 0
  end

  #############
  # SUBTRACKS #
  #############

  multitrack :track_parts1_6 do
    # no synchronization allowed, channels must be perfectly synced manually
    synchronize_channels a: 0...0, b: 0...0, c: 0...0

    all_ch { m1; n0; mto; mno; ceo; i :instr1_quiet }

    #######################
    mark :part_1

    ch_a do
      rpt(2) do
        i :instr3_quiet;
        rpt(7) { d  3, 32; veo; m2; e  3, 32; f  3, 32 }
        i :instr1_normal_reduced; m1
        d!  3, 32; f!  3, 32; a  4, 32
      end
    end

    ch_b do
      rpt(1) do
        p  32, 32, 32
        rpt(15) { c  3, 32, 32, 32 }
      end
    end

    ch_c do
      rpt(16) { g  3, 32, 32, 32 }
    end

    #######################
    mark :part_1to2

    ch_a do
      i :instr1_quiet;
      rpt(2) do
        a  4, 32; veo; m2; f  3, 32; g  3, 32; a  4, 32; g  3, 32; f  3, 32;
        a  4, 32; f  3, 32; g  3, 32; b  4, 32; g  3, 32; f  3, 32;
      end
      m1;
      a  4, 32; veo; m2; f  3, 32; g  3, 32; a  4, 32; g  3, 32; f  3, 32;
      g  3, 32; e  3, 32; f  3, 32; g  3, 32; f  3, 32; e  3, 32;
    end

    ch_b do
      rpt(5) {  i :instr1_quiet; c  3, 32, 32, 32; i :instr1_normal; d  4, 32, 32, 32 }
      i :instr1_quiet
      b  3, 32, 32, 32; c  4, 32, 32, 32;
    end
  
    ch_c do
      rpt(2) {  rpt(3) { d  3, 32, 32, 32 }; e  3, 32, 32, 32 }
      d  3, 32, 32, 32; d  3, 32, 32, 32
      c  3, 32, 32, 32; c  3, 32, 32, 32
    end

    #######################
    mark :part_2

    ch_a do
      rpt(8) do
        m1
        g  3, 32; veo; m2; d! 3, 32; f! 3, 32; g  3, 32; f! 3, 32; d! 3, 32;
      end
    end

    ch_b do
      # part 2
      i :instr1_normal; a! 3, 32, 32, 32; i :instr1_quiet; c  4, 32, 32, 32;
      i :instr1_normal; a  3, 32, 32, 32; i :instr1_quiet; c  4, 32, 32, 32;
      i :instr1_normal; a! 3, 32, 32, 32; i :instr1_quiet; c  4, 32, 32, 32;
      i :instr1_normal; g  2, 32, 32, 32; i :instr1_quiet; c  4, 32, 32, 32;
      i :instr1_normal; a! 3, 32, 32, 32; i :instr1_quiet; c  4, 32, 32, 32;
      i :instr1_normal; a  3, 32, 32, 32; i :instr1_quiet; c  4, 32, 32, 32;
      i :instr1_normal; a! 3, 32, 32, 32; i :instr1_quiet; p     32, 32, 32;
      i :instr1_normal; g  2, 32, 32, 32; i :instr1_quiet; c  4, 32, 32, 32;
      i :instr1_quiet;
    end

    ch_c do
      rpt(16) { c  3, 32, 32, 32 }
    end

    mark :part_3 #######################

    ch_a do
      rpt(2) do
        i :instr3_quiet;
        rpt(7) { c  3, 32; veo; m2; d  3, 32; d! 3, 32; }
        i :instr1_normal_reduced; m1;
        c! 3, 32; e  3, 32; g  3, 32
      end
    end

    ch_b do
      rpt(1) { rpt(15) { a! 3, 32, 32, 32; }; p 32, 32, 32; }
    end

    ch_c do
      rpt(1) { rpt(10) { f  3, 32, 32, 32 }; p 32, 32, 32; rpt(5) { f  3, 32, 32, 32 } }
    end

    mark :part_4 #######################

    ch_a do
      i :instr1_quiet;
      rpt(4) do
        g  3, 32; veo; m2; d! 3, 32; f  3, 32; g  3, 32; f  3, 32; d! 3, 32;
        g  3, 32; d! 3, 32; f  3, 32; a  4, 32; f  3, 32; d! 3, 32;
      end
      m1
      rpt(4) do
        g  3, 32; veo; m2; d! 3, 32; f  3, 32; a  4, 32; f  3, 32; d! 3, 32;
      end
    end

    ch_b do
      rpt(3) do
        i :instr1_normal; a! 3, 32, 32, 32; i :instr1_quiet; c  4, 32, 32, 32;
        i :instr1_normal; a  3, 32, 32, 32; i :instr1_quiet; c  4, 32, 32, 32;
        i :instr1_normal; a! 3, 32, 32, 32; i :instr1_quiet; c  4, 32, 32, 32;
        i :instr1_normal; g  2, 32, 32, 32; i :instr1_quiet; c  4, 32, 32, 32;
      end
    end

    ch_c do
      rpt(4) { rpt(3) { c  3, 32, 32, 32 }; d  3, 32, 32, 32 }
      i :instr1_loud_reduced
      rpt(4) { c  3, 32, 32, 32 ; d  3, 32, 32, 32 }
    end

    mark :part_5 #######################

    ch_a do # part_5
      p 64
      i :instr1_loud
      g  3
      p 8, 16
      # i :instr1_quiet
      rpt(2) do
        p 8, 16;
        m2; veo; n 31
        mt :mask_thrr1; mn :mask_thrr2; ne :noise_env1
        rpt(5) { d  3, 32; e  3, 32; f  3, 32; }
        d! 3, 32; f! 3, 32; a  4, 32;
        rpt(7) { d  3, 32; e  3, 32; f  3, 32; }
        d! 3, 32; f! 3, 32; a  4, 32;
        rpt(16) { d  3, 32; e  3, 32; f  3, 32; }
        m1; mto; mno;
        f  3
      end
    end

    ch_b do # part_5
      i :instr2_loud
      np 1; c  0, 64
      np 16; c 1; vs 4; va 0.2
      p 8, 16
      rpt(2) do
        p 1,2,16,32, -32; np 0; vo; mno
        ceo; i :instr1_normal
        d  5, 32, 32, 32, 32; d  5, 32, 32; c  5, 32, 32; b  5, 32, 32; a  5, 32, 32, 32
        i :instr1_loud
        ce :chord_note5;  d  4, 32, 32, 32
        ceo;             g  4, 32, 32, 32; d  4, 32, 32, 32; g  3, 32, 32, 32
        i :instr1_normal
        d  2, 32, 32, 32; d  2, 32, 32; c  2, 32, 32; b  2, 32, 32; a  2, 32, 32, 32
        i :instr1_loud
        g  1, 32, 32, 32; g  1, 32, 32, 32; 
        ce :chord_note12; g  0, 32, 32, 32;
        i :instr2_normal; np 1; c  1; np 4; mn :mask_thrr3; c  0
      end
    end

    ch_c do # part_5
      p 64
      i :instr2_normal
      c  3
      p 8, 16
      rpt(2) do
        ce :chord_note7; p 32, 32, 32;
        m2;
        rpt(8) do
          c  4, 32, 32, 32; c  3, 32, 32, 32;
        end
        m1; i :instr1_quiet;
        ce :chord_note12; g  4, 32, 32, 32; g  4, 32, 32; f  4, 32, 32; e  4, 32, 32; 
        i :instr1_normal;
        ceo;             d  5, 32, 32, 32;
        ce :chord_note12; c  4, 32, 32, 32; c  4, 32, 32, 32; i :instr1_loud; g  3, 32, 32, 32
        i :instr1_normal;
        ceo;             c  3, 32, 32, 32; 
        i :instr1_quiet;
        ce :chord_note12; g  1, 32, 32, 32; g  1, 32, 32; f  1, 32, 32; e  1, 32, 32; i :instr1_normal; d  1, 32, 32, 32;
        c  1, 32, 32, 32; c  1, 32, 32, 32, 32, 32, 32;
        i :instr2_normal;
        ce :chord_note7;  c  3
        ceo
      end
    end

    mark :part_6 #######################

    ch_a do
      i :instr1_loud;
      c 3, 8, 16
      m2; veo; mn :mask_thrr2;
      rpt(14) { d  3, 32; e  3, 32; f  3, 32; }
      m1; mno; neo
    end

    ch_b do
      vo; np 1; ceo; n0; mno; i :instr3_loud
      rpt(2) do
        a! 1, 8, 16; a! 2, 4, 32; g  1, 8, 16; g  0, 16, 32; 
      end
    end

    ch_c do
      i :instr1_loud;
      rpt(2) do
        a! 2, 8, 16; a! 3, 4, 32; g  2, 8, 16; g  1, 16, 32; 
      end
    end

  end # Multitrack :track_parts1_6

  #############
  # ENVELOPES #
  #############

  envelope :noise_env1           , [128, -1.0], [128, 1.0]
  envelope :noise_env_down       , [255, -1.0], :loop, [255, 0]
  # chord    :chord_note2          , [1, 0], [1, 2]
  chord    :chord_note2_4_6      , [4, 0], :loop, [4, 2], [4, 4], [4, 6]
  # chord    :chord_note3          , [1, 0], [1, 3]
  # chord    :chord_note3_5        , [1, 0], [1, 3], [1, 5]
  # chord    :chord_note3_7        , [1, 0], [1, 3], [1, 7]
  chord    :chord_note5          , [1, 0], [1, 5]
  chord    :chord_note7          , [1, 0], [1, 7]
  chord    :chord_note12         , [1, 0], [1, 12]
  chord    :chord_progress_1     , [4, 0], [4, 12], [4, 0], [4, 24], :loop, [4, 12], [4, 24]
  envelope :env_vol_progress_1   , [6, 0.5], [12, -0.4], [18, 0.3], :loop, [255, 0]
  envelope :env_vol_piano1       , [1, 0], [7, -0.2], [10, -0.3], :loop, [8, 0.2], [8, -0.2]
  envelope :env_vol_piano2       , [1, 0], [3, -0.1], [32, -0.3], :loop, [8, 0.1], [8, -0.1]
  envelope :env_vol_piano2_short , [1, 0], [3, -0.1], :loop, [32, -0.3], [64, -1.0]
  envelope :env_vol_piano3       , [4, 1.0/3.0], [24, -0.1], :loop, [128, -0.5]
  envelope :env_vol_piano4       , [24, -0.1], [64, 0], :loop, [255, -0.5]
  envelope :env_vol_piano5       , [4, 0.25], [16, -0.3], :loop, [128, -0.5]
  # envelope :env_vol_silent       , [10, -1.0]
  envelope :env_vol_silent_slow2 , [255, -1.0]
  envelope :env_vol_silent_sl_saw, [64, -0.3], :loop, [48, 0.2], [48, -0.2]
  envelope :env_vol_silent_slow_u, [128, 1.0], :loop, [48, -0.2], [48, 0.2]
  # envelope :env_vol_silent_wave  , [255, 0.5], [255, -0.5]
  # mask     :mask_noise_1         , [8, 0b01111111], :loop, [8, 0b11111111]
  mask     :mask_thrr1           , [8, 0b00110011]
  mask     :mask_thrr2           , [8, 0b01110111]
  mask     :mask_thrr3           , [8, 0b11111111], [8, 0b00000000]
  mask     :mask_thrr4           , [8, 0b00110011],  [8, 0b00110011], :loop, [8, 0b01010101]
  # mask     :mask_envelope1       , [32, 0b11111111], :loop, [255, 0]

  ###############
  # INSTRUMENTS #
  ###############

  instrument :instr1_loud do
    v 15; ve :env_vol_piano1
  end

  instrument :instr1_loud_reduced do
    v 14; ve :env_vol_piano1
  end

  instrument :instr1_normal do
    v 13; ve :env_vol_piano1
  end

  instrument :instr1_normal_reduced do
    v 12; ve :env_vol_piano1
  end

  instrument :instr1_quiet do
    v 11; ve :env_vol_piano1
  end

  instrument :instr1_quiet_vib do
    sub :instr4_quiet; v 6; vo; w 24; vg 0; va 0.3
  end

  instrument :instr1_silencio do
    v 8;  ve :env_vol_piano1
  end

  instrument :instr2_loud do
    v 12; ve :env_vol_piano3
  end

  instrument :instr2_normal do
    v 12; ve :env_vol_piano4
  end

  instrument :instr3_loud do
    v 15; ve :env_vol_piano2
  end

  instrument :instr3_normal do
    v 13; ve :env_vol_piano2
  end

  instrument :instr3_quiet do
    v 11; ve :env_vol_piano2
  end

  instrument :instr3_quiet_short do
    v 10; ve :env_vol_piano2_short; vs 60; va 0.2; #w 128/32; veo; v 0
  end

  instrument :instr4_loud do
    v 12; ve :env_vol_piano5
  end

  instrument :instr4_normal do
    v 10; ve :env_vol_piano5
  end

  instrument :instr4_quiet do
    v 8; ve :env_vol_piano5
  end

  instrument :instr_progress1 do
    v  3
    ce :chord_progress_1
    ve :env_vol_progress_1
  end
end # Mouvement


if __FILE__ == $0
  require 'z80'

  music = Mouvement.new
  musmod = music.to_module
  puts musmod.to_program.new(0x8000).debug
  puts "Recursion depth max: #{music.validate_recursion_depth!}"
  puts music.channel_tracks.map.with_index {|t, ch| "channel: #{ch} ticks: #{t.ticks_counter}" }
  puts "Index lookup table items: #{musmod.index_offsets.length}"
  puts "By type:"
  musmod.index_items.sort_by {|item| item.type}.chunk {|item| item.type}.
  each do |type, items|
    puts " - #{type}s".to_s.ljust(15) + ": #{items.length.to_s.rjust(3)}"
  end
  puts "Unused items:"
  music.unused_item_names.each do |category, names|
    unless names.empty?
      puts "  #{category}:"
      puts names.map {|name| "   - :#{name}" }
    end
  end
  name = music.class.name.downcase
  musmod.to_player_module.save_tap name
  Z80::TAP.parse_file("#{name}.tap") do |hb|
      puts hb.to_s
  end
end

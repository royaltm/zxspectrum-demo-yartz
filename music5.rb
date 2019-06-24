require 'z80'
require 'zxutils/ay_music/music_box'
require 'zxutils/ay_music'

class Music
  include Z80
  # include AYSound::Registers
  include AYSound::EnvelopeControl
  extend ::MusicBox::Helpers

  # Boundary
  export start
  # API
  export init
  export play
  export mute
  # AYMusic engine
  export music

  # Data for debug
  export notes
  export instrument_table

  # re-export AYMusic play
  play                music.play

  label_import        ZXSys
  macro_import        AYSound
  macro_import        AYMusic
  macro_import        Z80MathInt

  export :auto

  ministack           addr 0xF500, 2
  track_stack_end     addr ministack[-8], AYMusic::TrackStackEntry
  empty_instrument    addr track_stack_end[-1]
  fine_tones          addr 0xD000, 2 # count 256
  note_to_cursor      addr fine_tones[256], 2 # max count 96
  music_control       addr 0xF100, AYMusic::MusicControl

  export :noauto

  AY_MUSIC_OVERRIDE = { instrument_table: instrument_table, notes: notes,
                        note_to_cursor: note_to_cursor, fine_tones: fine_tones,
                        track_stack_end: track_stack_end,
                        empty_instrument: empty_instrument,
                        music_control: music_control, ministack: ministack }

  start               label

  ns :init, use: :io128 do
    ns :extend_notes do
                      ay_extend_notes(music.notes, octaves:8, save_sp:true, disable_intr:false, enable_intr:false)
    end
    ns :tone_progress_table_factory do
                      ay_tone_progress_table_factory(fine_tones, hz: 440)
    end
    ns :note_to_fine_tone_cursor_table_factory do
                      ay_note_to_fine_tone_cursor_table_factory(note_to_cursor, play: music.play)
    end
                      call music.init
                      dw   track_a, track_b, track_c
                      ret
  end

  ns :mute, use: :io128 do
                      ay_init
                      ret
  end


  import            AYMusic, :music, override: AY_MUSIC_OVERRIDE
  music_end         label

  instrument_table  instruments(
                      track_a_part1_6,
                      track_b_part1_6,
                      track_c_part1_6,
                      env_vol_piano1,
                      env_vol_piano2,
                      env_vol_piano3,
                      env_vol_piano4,
                      env_vol_piano5,
                      env_vol_silent,
                      env_vol_silent_slow_u,
                      env_vol_silent_slow2,
                      env_vol_silent_sl_saw,
                      env_vol_silent_wave,
                      instr1_loud,
                      instr1_normal,
                      instr1_quiet,
                      instr3_loud,
                      instr3_normal,
                      instr3_quiet,
                      instr4_loud,
                      instr4_normal,
                      instr4_quiet,
                      instr1_quiet_vib,
                      instr1_silencio,
                      instr2_loud,
                      instr2_normal,
                      chord_note2,
                      chord_note2_4_6,
                      chord_note3,
                      chord_note3_5,
                      chord_note3_7,
                      chord_note7,
                      chord_note5,
                      chord_note12,
                      mask_noise_1,
                      mask_thrr1,
                      mask_thrr2,
                      mask_thrr3,
                      mask_thrr4,
                      mask_envelope1,
                      noise_env1,
                      noise_env_down,
                    )

  # $random = Random.new 1

  # $chord_note = ->(*notes) do
  #   notes[$random.rand notes.length]
  # end

# https://www.youtube.com/watch?v=SO7iYa94N-M Debussy: Mouvement (L.110/3)
  music_track :track_a_part1_6 do
    m1; n0; mt 0; mn 0; ce 0; i :instr1_quiet
    # part 1
    rpt(2) do
      i :instr3_quiet;
      rpt(7) { d  3, 32; e  3, 32; f  3, 32 }
      i :instr1_quiet;
      d!  3, 32; f!  3, 32; a  4, 32
    end
    # part 1->2
    i :instr1_quiet;
    rpt(2) do
      a  4, 32; f  3, 32; g  3, 32; a  4, 32; g  3, 32; f  3, 32;
      a  4, 32; f  3, 32; g  3, 32; b  4, 32; g  3, 32; f  3, 32;
    end
    a  4, 32; f  3, 32; g  3, 32; a  4, 32; g  3, 32; f  3, 32;
    g  3, 32; e  3, 32; f  3, 32; g  3, 32; f  3, 32; e  3, 32;
    # part 2
    rpt(8) do
      g  3, 32; d! 3, 32; f! 3, 32; g  3, 32; f! 3, 32; d! 3, 32;
    end
    # part 3
    rpt(2) do
      i :instr3_quiet;
      rpt(7) { c  3, 32; d  3, 32; d! 3, 32; }
      i :instr1_quiet;
      c! 3, 32; e  3, 32; g  3, 32
    end
    # part 4
    i :instr1_quiet;
    rpt(4) do
      g  3, 32; d! 3, 32; f  3, 32; g  3, 32; f  3, 32; d! 3, 32;
      g  3, 32; d! 3, 32; f  3, 32; a  4, 32; f  3, 32; d! 3, 32;
    end
    rpt(4) do
      g  3, 32; d! 3, 32; f  3, 32; a  4, 32; f  3, 32; d! 3, 32;
    end
    # part 5
    p 64
    i :instr1_loud
    g  3
    p 8, 16
    # i :instr1_quiet
    rpt(2) do
      p 8, 16;
      m2; ve 0; n 31
      mt :mask_thrr1; mn :mask_thrr2; ne :noise_env1
      rpt(5) { d  3, 32; e  3, 32; f  3, 32; }
      d! 3, 32; f! 3, 32; a  4, 32;
      rpt(7) { d  3, 32; e  3, 32; f  3, 32; }
      d! 3, 32; f! 3, 32; a  4, 32;
      rpt(16) { d  3, 32; e  3, 32; f  3, 32; }
      m1; mt 0; mn 0;
      f  3
    end
    # part 6
    i :instr1_loud;
    c 3, 8, 16
    m2; ve 0; mn :mask_thrr2;
    rpt(14) { d  3, 32; e  3, 32; f  3, 32; }
    m1; mn 0; ne 0
  end

  music_track :track_a do
    tempo 128
    n0
    i :instr1_quiet
    rpt(32) { p 32, 32, 32 }

    # part 1-6
    sub :track_a_part1_6

    # part 7
    i :instr1_loud;
    c 3, 8, 16
    m2; ve 0; mn :mask_thrr2
    rpt(6) { d  3, 32; e  3, 32; f  3, 32; }
    p 32
    # part 8
    p 16, 32, 32
    mn 0;
    rpt(5) { d  3, 32; e  3, 32; f  3, 32; }
    v 9
    rpt(2) { g  3, 32; a 4, 32; b  4, 32; }
    v 8
    d  3, 32; e  3, 32; f  3, 32; g  3, 16, 32
    ve :env_vol_silent_slow2
    m1; rpt(2) { c 3, 16, 32 }
    m2; ve 0; rpt(5) { d  3, 32; e  3, 32; f  3, 32; }
    # part 9
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
    ve 0; m2
    rpt(10) { c  5, 32; g  4, 32; c  4, 32; }
    rpt(2) { g  4, 32; d  4, 32; g  3, 32; }
    rpt(2) { c  4, 32; g  3, 32; c  3, 32; }
    rpt(2) { g  4, 32; d  4, 32; g  3, 32; }
    rpt(2) { c  5, 32; g  4, 32; c  4, 32; }
    rpt(2) { g  4, 32; d  4, 32; g  3, 32; }
    rpt(2) { c  4, 32; g  3, 32; c  3, 32; }
    rpt(2) { g  3, 32; d  3, 32; g  2, 32; }
    # part 10
    ve :env_vol_silent_sl_saw
    g  3, 32, 64; d  3, 32, 64; g  2, 32, 64;
    rpt(15) { g  3, 32; d  3, 32; g  2, 32; }
    ve 0; v 7
    # part 11
    g  3, 32; d  3, 32; g  2, 32;
    m1; i :instr3_quiet
    a  4, 32; e  3, 32; a  3, 32; 
    rpt(4) { c  4, 32; g  3, 32; c  3, 32; }
    rpt(2) { d  4, 32; a  4, 32; d  3, 32; }
    f  4, 32; c  4, 32; f  3, 32; g  4, 32; d  4, 32; p 32
    # part 12
    rpt(4) { e  4, 32; b  4, 32; e  3, 32; }
    rpt(2) { d  4, 32; a  4, 32; d  3, 32; }
    c  4, 32; g  3, 32; c  3, 32;
    d  4, 32; a  4, 32; d  3, 32;
    rpt(4) { b  4, 32; f! 3, 32; b  3, 32; }
    a  4, 32; e  3, 32; a  3, 32;
    b  4, 32; f! 3, 32, 64; b  3, 32, 64;
    # part 13 (similar to part 10)
    ve 0; m2
    g  3, 32, 32; d  3, 32, 64; g  2, 32, 64
    rpt(7) { g  3, 32; d  3, 32; g  2, 32; }
    # part 14 (similar to part 11)
    g  3, 32; d  3, 32; g  2, 32;
    m1
    a  4, 32; e  3, 32; a  3, 32; 
    rpt(4) { c  4, 32; g  3, 32; c  3, 32; }
    rpt(2) { d  4, 32; a  4, 32; d  3, 32; }
    f  4, 32; c  4, 32; f  3, 32; g  4, 32; d  4, 32; g  3, 32
    puts "counter1: #{tick_counter}"
    # part 15
    m2; ve 0; v 8
    rpt(10) { b  5, 32; f! 4, 32; b  4, 32, 128; }
    v 9
    rpt(8) { b  5, 32; f! 4, 32; b  4, 32, 128; }
    rpt(4) { c  5, 32; g  4, 32; c  4, 32, 128; }
    puts "counter1: #{tick_counter}"
    rpt(2) { b  5, 32; f! 4, 32; b  4, 32, 128; }
    rpt(2) { c  5, 32; g  4, 32; c  4, 32, 128; }
    rpt(2) { f  4, 32; c  4, 32; f  3, 32, 128; }
    rpt(2) { f! 4, 32; b  4, 32; f! 3, 32, 128; }
    rpt(2) { a! 4, 32; f  3, 32; a! 3, 32, 128; }
    rpt(2) { b  4, 32; f! 3, 32; b  3, 32, 128; }
    rpt(2) { e  3, 32; b  3, 32; e  2, 32, 128; }
    # part 16
    rpt(6) { f  3, 32; c 3, 32, 128; f! 2, 32, 128; }
    rpt(4) { f! 3, 32, 128; c 3, 32, 128; f! 2, 32, 64; }
    puts "counter1: #{tick_counter}"
    # part 17
    i :instr3_normal; m1
    ce :chord_note2; f  3, 16, 32;
    ce :chord_note3; p     32; b  3, 16;
    ce :chord_note2; f  3, 32; g  2, 16;
    ce 0;            e  3, 32, 64; ce :chord_note2; g  3, 32, 64;
    ce :chord_note3; e  2, 32, 64; e  3, 32, 64;
    p  4, 8;

    ce :chord_note12; e  3, 16, 32;
    p 16, 32;
    p 16, 32;
    b  3, 16, 32; # g  3, 16, 32
    p 32, 64; a! 3, 32, 64 # e  3, 32, 64; a  4, 32, 64;
    p 16, 32;
    c  3, 16, 32;
    p  4, 8;

    c  3, 16, 32;
    p 16, 32;
    p 16, 32;
    ce 0; c! 4, 16, 32;
    ce :chord_note12; p 32, 64; f 2, 32, 64; # b 3; e 3
    p     16; e  2, 32; # g 2; a 3;
    p 4, 8, 16, 32;

    d! 2, 16, 32;
    p      16; g! 2, 32; # d! 3
    p  16, 32;
    e  2, 16, 32; # g  2; a  3;
    p  16, 32;
    p  16, 32;
    p  16, 32;
    p  16, 32;
    p      16; b  3, 32;
    p  16, 32;

    p  16, 32;
    p  16, 32;
    p  16, 32;
    p      16; b  2, 32;
    p  16, 32;
    a! 3, 16, 32;
    p  32, 64; e  2, 32, 64
    p  16, 32;
    p  16, 32;
    p  16, 32;

    p  16, 32;
    p      16; e  3, 32;
    p  16, 32;
    p  16, 32;
    p      64; g! 3, 16, 64;
    p  32, 64; a! 4, 32, 64;
    p      16; a! 3, 32;
    ce 0; p 16; f! 4, 32;
    p  16, 32;
    p  16, 32;
    p  16, 32;

    ce :chord_note12; e  3, 16, 32;
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
    p      32; d  3, 16; # a! 4;

    ce 0
    p  16, 32;
    ce :chord_note12; g! 3, 16, 32;
    p  16, 32;
    p  16, 32;
    p  16, 32;
    p  16, 32;
    ce :chord_note12; g! 3, 16, 32;
    p  16, 32;
    p  16, 32;
    p  16, 32;
    p  16, 32;

    puts "counter1: #{tick_counter}"
    m1; ce 0
    i :instr1_loud
    rpt(16) { f! 4, 16, 32; }
    puts "counter1: #{tick_counter}"

    sub :track_a_part1_6

    # part 18
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
    # part 19
    m2; ve 0
    rpt(24) { f! 5, 32; g! 5, 32; a! 6, 32; }
    m1; i :instr1_quiet;
    rpt(2) { g! 5, 32; a! 6, 32; c  6, 32; }
    rpt(2) { a! 6, 32; c  6, 32; d  6, 32; }
    # part 20
    m1; i :instr1_normal;
    ce :chord_note2_4_6; a! 6, 8, 16;
    m2; ve 0; v 7; ce 0
    rpt(38) { c  6, 32; d  6, 32; e  6, 32; }
    ve :env_vol_silent_slow2
    p 4, 32
    ve 0; v 0
    puts "counter1: #{tick_counter}"
    # lt :mloop
  end

  music_track :track_b_part1_6 do # blue
    m1; n0; mt 0; mn 0; ce 0; i :instr1_quiet
    # part 1
    rpt(1) do
      p  32, 32, 32
      rpt(15) { c  3, 32, 32, 32 }
    end
    # part 1->2
    rpt(5) {  i :instr1_quiet; c  3, 32, 32, 32; i :instr1_normal; d  4, 32, 32, 32 }
    i :instr1_quiet
    b  3, 32, 32, 32; c  4, 32, 32, 32;
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
    # part 3
    rpt(1) { rpt(15) { a! 3, 32, 32, 32; }; p 32, 32, 32; }
    # part 4
    rpt(3) do
      i :instr1_normal; a! 3, 32, 32, 32; i :instr1_quiet; c  4, 32, 32, 32;
      i :instr1_normal; a  3, 32, 32, 32; i :instr1_quiet; c  4, 32, 32, 32;
      i :instr1_normal; a! 3, 32, 32, 32; i :instr1_quiet; c  4, 32, 32, 32;
      i :instr1_normal; g  2, 32, 32, 32; i :instr1_quiet; c  4, 32, 32, 32;
    end
    # part 5
    i :instr2_loud
    np 1; c  0, 64
    np 16; c 1; vs 4; va 0.3
    p 8, 16
    rpt(2) do
      p 1,2,16,32, -32; np 0; vo; mn 0
      ce 0; i :instr1_normal
      d  5, 32, 32, 32, 32; d  5, 32, 32; c  5, 32, 32; b  5, 32, 32; a  5, 32, 32, 32
      i :instr1_loud
      ce :chord_note5;  d  4, 32, 32, 32
      ce 0;             g  4, 32, 32, 32; d  4, 32, 32, 32; g  3, 32, 32, 32
      i :instr1_normal
      d  2, 32, 32, 32; d  2, 32, 32; c  2, 32, 32; b  2, 32, 32; a  2, 32, 32, 32
      i :instr1_loud
      g  1, 32, 32, 32; g  1, 32, 32, 32; 
      ce :chord_note12; g  0, 32, 32, 32;
      i :instr2_normal; np 1; c  1; np 4; mn :mask_thrr3; c  0
    end
    # part 6
    vo; np 1; ce 0; n0; mn 0; i :instr3_loud
    rpt(2) do
      a! 1, 8, 16; a! 2, 4, 32; g  1, 8, 16; g  0, 16, 32; 
    end
  end

  music_track :track_b do # blue
    tempo 128
    n0
    w 2
    i :instr1_quiet
    rpt(8) do
      i :instr1_normal; c  3, 32, 32, 32
      i :instr1_quiet; rpt(3) { c  3, 32, 32, 32 }
    end

    # part 1-6
    sub :track_b_part1_6

    # part 7
    i :instr1_loud;
    f  0, 16, 32; g  0, 16, 32; g  0,  4, 32; f  0,  8, 16;
    i :instr1_normal; g  0, 16; i :instr1_quiet; g  0, 16
    # part 8
    p 32
    p 64; i :instr4_normal; d  2, 16, 32, 64; i :instr4_loud; g  2, 16, 32; i :instr4_quiet; f  2,  4,  8, 32, 64;
    i :instr4_normal; b  3, 16, 32; i :instr4_loud; g  2, 16, 32; i :instr4_quiet; g  0, 16, 32, 64
    i :instr4_normal; d  2, 16, 32; :instr3_normal; g  2, 16, 32; i :instr1_normal; f  2, 4, 8, 16, 32
    # part 9
    p 32
    i :instr1_loud;
    g  3, 16, 32, 32; c  4, 16; f  4, 32; f  4, 16; b  5, 16; e  5, 16, 64; a  6, 16, 64;
    i :instr3_loud;
    c  0, 8, 32, 32;
    ce :chord_note12; g  2, 16, 32; g  2, 16; f  2, 16; e  2, 16; d  2, 16, 32; c  2,  16, 32; c  2, 4, 8
    i :instr2_normal;
    ce 0; d  0, 8, 16; e  0, 8, 16; f  0, 8, 16;
    i :instr1_loud;
    e  0, 16, 32;
    ce :chord_note12; g  2, 16, 32; g  2, 16; f  2, 16; e  2, 16; d  2, 16, 32; c  2,  16, 32; c  2, 4, 8
    i :instr2_normal;
    ce 0; f  0, 8, 16; g  0, 8, 16; rpt(2) { f  0, 8, 16; e  0, 8, 16; }; f  0, 8, 16;
    # part 10
    i :instr1_loud; f! 0, 16, 32, 32, 64;
    i :instr3_quiet; e  2, 1, 4, 8, 32
    # part 11
    i :instr3_quiet;
    e  2, 16, 32; f! 2, 16, 32; rpt(4) { a  3, 16, 32; }
    rpt(2) { b  3, 16, 32; }; d  3, 16, 32; e  3, 16, 32;
    # part 12
    rpt(4) { c! 3, 16, 32; }
    b  3, 16, 32; b  3, 16, 32; a  3, 16, 32; b  3, 16, 32;
    rpt(4) { g! 2, 16, 32; }; f! 2, 16, 32; g! 2, 8;
    # part 13 (similar to part 10)
    i :instr2_normal; f! 0, 2, 4, 16;
    i :instr1_quiet;
    # part 14 (similar to part 11)
    e  2, 16, 32; f! 2, 16, 32; rpt(4) { a  3, 16, 32; }
    rpt(2) { b  3, 16, 32; }; d  3, 16, 32; e  3, 16, 32;
    puts "counter2: #{tick_counter}"
    # part 15
    rpt(7) { g! 3, 16, 32, 128 }
    f! 3, 16, 32, 128; d! 3, 16, 32, 128; g! 3, 16, 32, 128; g! 3, 8, 16, 128, 128;
    d! 3, 16, 32, 128; f! 3, 16, 32, 128;
    rpt(8) { g! 3, 16, 32, 128; }
    puts "counter2: #{tick_counter}"
    rpt(1) { g! 3, 16, 32, 128; }
    f! 3, 16, 32, 128; d! 3, 16, 32, 128;
    d! 3, 16, 32, 128; d  3, 16, 32, 128; c  3, 16, 32, 128;
    a  3, 16, 32, 128; a  3, 16, 32, 128; g  2, 16, 32, 128; f  2, 16, 32, 128; d  2, 16, 32, 128;
    d  2, 16, 32, 128; c! 2, 16, 32, 128; b  2, 16, 32, 128;
    # part 16
    rpt(6) { g! 1, 16, 32, 64; }
    rpt(4) { g! 1, 16, 32, 32; }
    puts "counter2: #{tick_counter}"
    # part 17
    i :instr3_normal; m1
    f! 0, 16, 32;
    p 16, 32;
    p 32; c! 2, 16;
    p 16, 32;
    c! 3, 16, 32;
    f! 3, 16, 32;
    f! 0, 16, 32;
    p  16, 32;
    f! 2, 16; f! 2, 32;

    c! 3, 16, 32;
    f! 3, 16, 32;
    p  16, 32;
    p  16, 32;
    p  16; c! 3, 32;
    p  16, 32;
    f! 3, 16; f! 3, 32;
    p  32; f! 0, 16;
    p  16, 32;
    p  16; f! 2, 32;
    p  16; f! 2, 32;

    a! 3, 16; f! 3, 32;
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

    f! 2, 16, 32;
    p 16, 32;
    p 16, 32;
    c! 2, 16, 32;
    f! 2, 16, 32;
    f! 0, 16, 32;
    p 16, 32;
    p 32, 64; f! 2, 32, 64;
    f! 2, 16; f! 2, 32;
    p 32, 64; f! 2, 32, 64;

    f! 0, 16, 32;
    f! 0, 16, 32;
    p     32; f! 2, 16;
    f! 2, 16, 32;
    p 16, 32;
    p 16, 32;
    p 16, 32;
    p 16, 32;
    f! 0, 16, 32;
    p 16, 32;

    p 16; f! 2, 32;
    p 32; f! 2, 16;
    p 16, 32;
    p 16, 32;
    p 16, 32;
    p 16, 32;
    p 16, 32;
    p 16, 32;
    p 32; f! 0, 16;
    p 16, 32;
    p 32; f! 2, 32; f! 2, 32;

    p 16, 32;
    p 16, 32;
    p 32; f! 2, 16;
    p 16, 32;
    p 16, 32;
    p 16, 32;
    p 32; f! 0, 16;
    p 16, 32;
    p 64; f! 2, 32, 64; f! 2, 32; 
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

    p 16, 32;
    p 16, 32;
    f! 3, 16, 32;
    p     16; f! 3, 32;
    p     64; f! 3, 16, 64;
    p 16, 32;
    p     16; f! 3, 32;
    p 16, 32;
    p     32; f! 3, 16;
    f! 3, 16, 32; 
    p 32, 64; f! 3, 32, 64;

    puts "counter2: #{tick_counter}"
    i :instr1_loud
    mt :mask_thrr1
    rpt(16) { p 32; f! 3, 32; f! 3, 32; }
    mt 0;
    puts "counter2: #{tick_counter}"

    sub :track_b_part1_6

    # part 18
    i :instr2_normal
    f! 0, 8, 2, 8, 32
    i :instr1_loud
    # ce :chord_note12; 
    e  0, 4, 8; d  0, 4, 8;
    # part 19
    i :instr1_normal; c! 0, 2, 4
    i :instr1_quiet;
    # ce 0;
    e  2, 16, 32; f! 2, 16, 32; a! 3, 4, 8; d  3, 8, 16; f! 3, 16, 32; g! 3, 16, 32;
    e  3, 2, 4, 8, 16;
    # part 20
    c! 0,  8, 16;
    vs 45; i :instr1_quiet_vib
    e  2, 16, 32; f! 2, 16, 32; a! 3, 4, 8; d  3, 8, 16;
    f! 3, 16, 32; g! 3, 16, 32; a! 4, 16, 32; c  4, 16, 32;
    e  4,  4,  8; g! 4,  8, 16; c  5, 16, 32; d  5, 16, 32;
    a! 5,  2, 16; a! 4,  4,  8; a! 3,  4,  8; a! 2,  4,  8
    i :instr3_quiet; vo
    c  0, 8, 16, 16, 32;
    ve 0; v 0
    puts "counter2: #{tick_counter}"
    # lt :mloop
  end

  music_track :track_c_part1_6 do # pink
    m1; n0; mt 0; mn 0; ce 0; i :instr1_quiet
    # part 1
    rpt(16) { g  3, 32, 32, 32 }
    # part 1->2
    rpt(2) {  rpt(3) { d  3, 32, 32, 32 }; e  3, 32, 32, 32 }
    d  3, 32, 32, 32; d  3, 32, 32, 32
    c  3, 32, 32, 32; c  3, 32, 32, 32
    # part 2
    rpt(16) { c  3, 32, 32, 32 }
    # part 3
    rpt(1) { rpt(10) { f  3, 32, 32, 32 }; p 32, 32, 32; rpt(5) { f  3, 32, 32, 32 } }
    # part 4
    rpt(4) { rpt(3) { c  3, 32, 32, 32 }; d  3, 32, 32, 32 }
    i :instr1_normal
    rpt(4) { c  3, 32, 32, 32 ; d  3, 32, 32, 32 }
    # part 5
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
      ce 0;             d  5, 32, 32, 32;
      ce :chord_note12; c  4, 32, 32, 32; c  4, 32, 32, 32; i :instr1_loud; g  3, 32, 32, 32
      i :instr1_normal;
      ce 0;             c  3, 32, 32, 32; 
      i :instr1_quiet;
      ce :chord_note12; g  1, 32, 32, 32; g  1, 32, 32; f  1, 32, 32; e  1, 32, 32; i :instr1_normal; d  1, 32, 32, 32;
      c  1, 32, 32, 32; c  1, 32, 32, 32, 32, 32, 32;
      i :instr2_normal;
      ce :chord_note7;  c  3
      ce 0
    end
    # part 6
    i :instr1_loud;
    rpt(2) do
      a! 2, 8, 16; a! 3, 4, 32; g  2, 8, 16; g  1, 16, 32; 
    end
  end

  music_track :track_c do # pink
    tempo 128
    n0
    i :instr1_quiet
    rpt(8) do
      i :instr1_normal; g  3, 32, 32, 32
      i :instr1_quiet; rpt(3) { g  3, 32, 32, 32 }
    end
    w 1

    # part 1-6
    sub :track_c_part1_6

    # part 7
    i :instr1_loud;
    f  1, 16, 32; g  1, 16, 32; g  1,  4, 32; f  1,  8, 16;
    i :instr1_normal; g  1, 16, 32; i :instr1_quiet; g  1, 32
    # part 8
    p 32
    i :instr4_quiet; c  3, 16, 32, 32;
    i :instr4_loud;  b  3, 16, 32; i :instr4_normal; a  3,  4, 32, 32, 64, 64; i :instr4_loud; c  3, 16, 32;
    i :instr4_normal;  d  3, 16, 32; b  3, 8; i :instr1_loud; g  1, 16
    p 16, 32
    i :instr4_normal;  b  3, 16, 32; i :instr1_loud; a  3, 4, 8; i :instr1_normal; c  3, 16, 32
    # part 9
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
    # part 10
    i :instr1_loud;
    f! 1, 8, 32, 64; i :instr3_normal; a! 3, 32; c! 3, 32; i :instr3_quiet; a! 3, 1, 4, 16;
    # part 11
    i :instr3_quiet;
    p  32; a! 3, 32; c! 3, 16; c  3, 32; d! 3, 32;
    rpt(4) { p 32; d! 3, 32; f! 3, 32; }
    rpt(2) { p 32; f  3, 32; g! 3, 32; };
    p 32; g! 3, 32; b  4, 32;
    p 32; a! 4, 32; c! 4, 32;
    # part 12
    rpt(4) { p 32; g  3, 32; a! 4, 32; }
    rpt(2) { p 32; f  3, 32; g! 3, 32; }
    p 32; d! 3, 32; f! 3, 32;
    p 32; f  3, 32; g! 3, 32;
    p 32; rpt(2) { d  3, 32; f  3, 16; d  3, 16, 32; }; c  3, 32; d! 3, 16; d  3, 32; f  3, 16;
    # part 13 (similar to part 10)
    i :instr2_normal; f! 1, 8, 32
    i :instr1_normal; e  2, 32; i :instr1_loud; a! 3, 32; c! 3, 32; a! 3, 2, 16;
    i :instr1_quiet;
    # part 14 (similar to part 11)
    p  32; a! 3, 32; c! 3, 16; c  3, 32; d! 3, 32;
    rpt(4) { p 32; d! 3, 32; f! 3, 32; }
    rpt(2) { p 32; f  3, 32; g! 3, 32; };
    p 32; g! 3, 32; b  4, 32;
    p 32; a! 4, 32; c! 4, 32;
    puts "counter3: #{tick_counter}"
    # part 15
    rpt(7) { p 32, 128; c! 4, 32; e 4, 32; }
    p 32, 64, 128; e  3, 32, 64; p 16, 32, 128;
    rpt(2) { p 32, 128; c! 4, 32; e  4, 32; }
    c! 3, 8, 16, 32, 128, 128, 128;
    rpt(5) { c! 4, 32; e  4, 16, 128; }
    rpt(4) { a! 4, 32; f  4, 16, 128; }
    puts "counter3: #{tick_counter}"
    c! 4, 32; e  4, 32;
    p 16, 128; e  3, 16; rpt(2) { g  3, 32; c! 4, 16, 128; }
    g  3, 32; a! 4, 32, 128; 
    p  32, 64, 128; a! 3, 32, 64;
    p  32, 128; rpt(2) { c! 3, 32; g  3, 16, 128; }
    c  3, 32; d! 3, 32;
    p  32, 128; d! 2, 16, 32, 128; rpt(2) { f! 2, 32; c  3, 16, 128; }
    f! 2, 32; a  3, 16, 32; a  2, 32, 128; 
    # part 16
    m2; ve 0
    rpt(6) { p 32; d! 2, 32, 128; a! 3, 32, 128; }
    rpt(4) { p 32, 128; d! 2, 32, 128; a! 3, 32, 64; }
    puts "counter3: #{tick_counter}"
    # part 17
    i :instr3_normal; m1
    f! 1, 16, 32;
    p  16, 32;
    p  16, 32;
    c! 3, 16, 32;
    p  32; c! 4, 16;
    p  32; f! 4, 32; f! 4, 32;
    f! 5, 16; f! 4, 32;
    f! 1, 32; f! 4, 32; f! 3, 32;
    p     32; f! 3, 16;

    c! 4, 16, 32;
    f! 4, 16; f! 4, 32;
    f! 5, 32; f! 4, 16;
    p 16, 32;
    p     16; c! 4, 32;
    p 16, 32;
    f! 4, 16, 32;
    f! 4, 16; f! 4, 32;
    f! 5, 32; f! 4, 32; f! 1, 32;
    f! 4, 32; f! 3, 16;
    f! 3, 16, 32;

    a! 4, 16, 32;
    f! 4, 32; f! 4, 32; f! 5, 32;
    f! 4, 16, 32;
    f! 3, 16, 32;
    p 32, 64; g! 3, 32, 64;
    p     16; c! 3, 32;
    p 32, 64; f! 3, 32, 64;
    f! 4, 32, 64; f! 4, 32, 64; 
    f! 5, 32; f! 4, 32; f! 1, 32;
    f! 4, 32; f! 3, 16;
    f! 3, 32; p 16;

    f! 3, 16, 32;
    p 16, 32;
    p 16, 32;
    c! 3, 16, 32;
    p     16; f! 3, 32;
    p     16; f! 5, 32;
    f! 4, 32; f! 1, 32; f! 4, 32;
    f! 3, 16; f! 3, 32;
    p     16; f! 3, 32;
    p     16; f! 3, 32;

    p     16; f! 5, 32;
    f! 4, 32; f! 1, 32; f! 4, 32;
    f! 3, 16; f! 3, 32;
    p 16, 32;
    p 16, 32;
    p 16, 32;
    p 16, 32;
    p     32; f! 3, 32; f! 4, 32;
    p     64; f! 4, 32, 64; f! 5, 32;
    f! 4, 32; f! 1, 32; f! 4, 32;

    p     32; f! 3, 16;
    f! 3, 16, 32;
    p     32; f! 3, 32; f! 4, 32;
    f! 4, 32; f! 5, 32; f! 4, 32;
    p 16, 32;
    p 16, 32;
    p     16; f! 4, 32;
    p 16, 32;
    f! 4, 32; f! 4, 32; f! 5, 32;
    f! 4, 32; f! 1, 32; f! 4, 32;
    f! 3, 16; f! 3, 32;

    p     16; f! 3, 32;
    f! 4, 32; f! 4, 32; f! 5, 32;
    f! 4, 32, 64; f! 3, 32, 64;
    p 16, 32;
    p 16, 32;
    p     32; f! 3, 32; f! 4, 32;
    p     32; f! 4, 32; f! 5, 32;
    f! 4, 32; f! 1, 32; f! 4, 32;
    f! 3, 16; f! 3, 32;
    p 32, 64; f! 3, 32, 64;

    p 16, 32;
    p 16, 32;
    p 16, 32;
    f! 3, 16, 32;
    f! 5, 32; f! 4, 32; f! 1, 32;
    p 64; f! 4, 32; f! 3, 32, 64;
    f! 3, 32, 64; f! 3, 32, 64;
    f! 4, 32; f! 3, 16;
    p 16, 32;
    f! 3, 16, 32;

    p 16, 32;
    p 16, 32;
    p     16; f! 3, 32;
    p     16; f! 5, 32;
    f! 4, 32; f! 1, 32; f! 4, 32;
    f! 3, 16; f! 3, 32;
    p     32; f! 3, 32; f! 4, 32;
    f! 3, 16, 32;
    p 32, 64; f! 3, 32, 64;
    p 16, 32;
    p 16, 32;

    g! 3, 16, 32;
    p 16, 32;
    g! 3, 16, 32;
    p  32, 64; g! 3, 32, 64;
    p     16; f! 3, 32;
    f! 4, 32, 64; f! 4, 32, 64;
    f! 5, 32; f! 4, 32; f! 1, 32;
    f! 4, 32; f! 3, 16;
    p 32, 64; f! 3, 32, 64;
    f! 4, 32; f! 5, 32; f! 4, 32;
    p     32; f! 4, 16;

    p 16, 32;
    p 16, 32;
    p     32; f! 4, 32; f! 4, 32;
    f! 5, 32; f! 4, 16;
    f! 4, 16; f! 4, 32;
    f! 5, 32; f! 4, 16;
    p 16, 32;
    f! 4, 32; f! 4, 32; f! 5, 32;
    f! 4, 16; f! 4, 32;
    p     32; f! 4, 32; f! 5, 32;
    f! 4, 16; f! 4, 32;

    puts "counter3: #{tick_counter}"
    # i :instr4_normal
    # f! 0
    t0; n1; n 31; ne :noise_env_down; v 0; ve :env_vol_silent_slow_u
    p 1; mn :mask_thrr4; p 2; t1; n0; ve 0; mn 0;
    puts "counter3: #{tick_counter}"

    sub :track_c_part1_6

    # part 18
    i :instr2_normal
    f! 1, 8
    i :instr1_quiet
    rpt(2) { c  3, 16, 32; }; d  3, 16, 32; e  3, 16, 32;
    f! 3, 16, 32; g! 3, 16, 32; a! 4, 16, 32; c  4, 16, 32; d  4, 16, 32; e  4, 16, 32;
    f! 4, 16, 32; g! 4, 16, 32; a! 5, 16, 32; c  5, 16, 32; d  5, 16, 32;
    # part 19
    rpt(24) { e  5, 16, 32; }
    rpt(2) { f! 5, 16, 32; } 
    rpt(2) { g! 5, 16, 32; }
    # part 20
    i :instr1_normal
    c! 1,  8, 16;
    i :instr1_silencio
    rpt(38) { a! 6, 16, 32; }
    ve :env_vol_silent_slow2
    p 4, 32
    ve 0; v 0
    puts "counter3: #{tick_counter}"
    # lt :mloop
  end

  noise_env1            music_envelope_data :all, [128, -1.0], [128, 1.0]
  noise_env_down        music_envelope_data -1, [255, -1.0], [255, 0]

  chord_note2           music_chord_data :all, [1, 0], [1, 2]
  chord_note2_4_6       music_chord_data -3, [4, 0], [4, 2], [4, 4], [4, 6]
  chord_note3           music_chord_data :all, [1, 0], [1, 3]
  chord_note3_5         music_chord_data :all, [1, 0], [1, 3], [1, 5]
  chord_note3_7         music_chord_data :all, [1, 0], [1, 3], [1, 7]
  chord_note5           music_chord_data :all, [1, 0], [1, 5]
  chord_note7           music_chord_data :all, [1, 0], [1, 7]
  chord_note12          music_chord_data :all, [1, 0], [1, 12]

  env_vol_piano1        music_envelope_data -2, [1, 0], [7, -0.2], [10, -0.3], [8, 0.2], [8, -0.2]
  env_vol_piano2        music_envelope_data -2, [1, 0], [3, -0.1], [32, -0.3], [8, 0.1], [8, -0.1]
  env_vol_piano3        music_envelope_data :last, [4, 1.0/3.0], [24, -0.1], [128, -0.5]
  env_vol_piano4        music_envelope_data :last, [24, -0.1], [64, 0], [255, -0.5]
  env_vol_piano5        music_envelope_data :last, [4, 0.25], [16, -0.3], [128, -0.5]
  env_vol_silent        music_envelope_data :last, [10, -1.0]
  env_vol_silent_slow2  music_envelope_data :last, [255, -1.0]
  env_vol_silent_sl_saw music_envelope_data -2, [64, -0.3], [48, 0.2], [48, -0.2]
  env_vol_silent_slow_u music_envelope_data -2, [128, 1.0], [48, -0.2], [48, 0.2]
  env_vol_silent_wave   music_envelope_data :all, [255, 0.5], [255, -0.5]
  mask_noise_1          music_mask_data :last, 8, 0b01111111, 8, 0b11111111
  mask_thrr1            music_mask_data :last, 8, 0b00110011
  mask_thrr2            music_mask_data :last, 8, 0b01110111
  mask_thrr3            music_mask_data :all,  8, 0b11111111, 8, 0b00000000
  mask_thrr4            music_mask_data :last,  8, 0b00110011,  8, 0b00110011, 8, 0b01010101
  mask_envelope1        music_mask_data :last, 32, 0b11111111, 255, 0

  music_track :instr1_loud do
    v 15; ve :env_vol_piano1
  end

  music_track :instr1_normal do
    v 13; ve :env_vol_piano1
  end

  music_track :instr1_quiet do
    v 11; ve :env_vol_piano1
  end

  music_track :instr1_quiet_vib do
    sub :instr4_quiet; v 6; vo; w 24; vg 0; va 0.3
  end

  music_track :instr1_silencio do
    v 8;  ve :env_vol_piano1
  end

  music_track :instr2_loud do
    v 12; ve :env_vol_piano3
  end

  music_track :instr2_normal do
    v 12; ve :env_vol_piano4
  end

  music_track :instr3_loud do
    v 15; ve :env_vol_piano2
  end

  music_track :instr3_normal do
    v 13; ve :env_vol_piano2
  end

  music_track :instr3_quiet do
    v 11; ve :env_vol_piano2
  end

  music_track :instr4_loud do
    v 12; ve :env_vol_piano5
  end

  music_track :instr4_normal do
    v 10; ve :env_vol_piano5
  end

  music_track :instr4_quiet do
    v 8; ve :env_vol_piano5
  end

  export music_data_len

  music_data_len      notes - 1 - instrument_table

  NOTES = ay_tone_periods(min_octave:0, max_octave:7)

  # (1...NOTES.length).each do |i|
  #   puts "#{NOTES[i-1].to_s.rjust(4)}-#{NOTES[i].to_s.rjust(4)} #{NOTES[i-1]-NOTES[i]} #{(NOTES[i-1].to_f/NOTES[i])}"
  # end

                    dw NOTES[11]*2
  notes             dw NOTES[0...12]
end

if __FILE__ == $0

  require 'utils/zx7'
  require 'zxlib/basic'

  class MusicTest
    include Z80
    include Z80::TAP

    import              ZXSys, macros: true, code: false
    macro_import        AYSound
    macro_import        Z80SinCos

    sincos              addr 0xF500, AYMusic::SinCos


    with_saved :demo, :exx, hl, ret: true, use: [:io128, :io] do
                        di
                        call make_sincos
                        call music.init
      forever           ei
                        halt
                        di
                        push iy
                        xor  a
                        out  (io.ula), a
                        call music.play
                        ld   a, 6
                        out  (io.ula), a
                        pop  iy
                        key_pressed?
                        jp  Z, forever
                        call music.mute
                        ei
    end

    import            Music, :music, override: {'music.sincos': sincos}
    music_end         label
                      words 7*12

    make_sincos       create_sincos_from_sintable sincos, sintable:sintable

    sintable          bytes   neg_sintable256_pi_half_no_zero_lo
    sincos_end        label
  end

  music = MusicTest.new 0x8000
  # puts music.debug
  puts "music size: #{music[:music_end] - music[:music]}"
  puts "TRACK_STACK_TOTAL: #{AYMusic::TRACK_STACK_TOTAL}"
  puts "TRACK_STACK_SIZE : #{AYMusic::TRACK_STACK_SIZE}"
  puts "TRACK_STACK_DEPTH: #{AYMusic::TRACK_STACK_DEPTH}"
  %w[
    +music.init.extend_notes +music.init.tone_progress_table_factory +music.init.note_to_fine_tone_cursor_table_factory
    music.instrument_table
    music.notes
    music.ministack
    sincos
    music.note_to_cursor
    music.fine_tones
    music.track_stack_end music.empty_instrument
    music.music_control music.music.music_control
    +music.music_control
    music.init music.music.init
    music.play music.music.play music.music.play.play_note
    make_sincos
    music.mute
    demo
    music.music_data_len
  ].each do |label|
    puts "#{label.ljust(30)}: 0x#{'%04x'%music[label]} - #{music[label]}"
  end

  ZX7.compress music.code[(music[:music]-music.org),(music[:music_end] - music[:music])]
  program = Basic.parse_source <<-EOC
    10 RANDOMIZE USR #{music[:demo]}
  9998 STOP: GO TO 10
  9999 CLEAR #{music.org-1}: LOAD ""CODE: RUN
  EOC
  puts program.to_source escape_keywords: true
  program.save_tap "music", line: 9999
  music.save_tap "music", append: true
  puts "TAP: music.tap:"
  Z80::TAP.parse_file('music.tap') do |hb|
      puts hb.to_s
  end
end

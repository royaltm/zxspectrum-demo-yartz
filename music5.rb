require 'z80'
require 'utils/ay_music/music_box'
require 'utils/ay_music'

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
                      env_vol_piano1,
                      env_vol_piano2,
                      env_vol_piano3,
                      env_vol_piano4,
                      env_vol_silent,
                      env_vol_silent_slow,
                      env_vol_silent_slow2,
                      instr1_loud,
                      instr1_normal,
                      instr1_quiet,
                      instr2_loud,
                      instr2_normal,
                      instr3_loud,
                      chord_note2,
                      chord_note7,
                      chord_note5,
                      chord_note12,
                      mask_noise_1,
                      mask_thrr1,
                      mask_thrr2,
                      mask_thrr3,
                      mask_envelope1,
                      noise_env1,
                    )

  # $random = Random.new 1

  # $chord_note = ->(*notes) do
  #   notes[$random.rand notes.length]
  # end

# https://www.youtube.com/watch?v=SO7iYa94N-M Debussy: Mouvement (L.110/3)
  music_track :track_a do
    tempo 128
    n0
    i :instr1_quiet
    rpt(32) { p 32, 32, 32 }

    l :mloop
    # part 1
    rpt(4) do
      rpt(7) { d  3, 32; e  3, 32; f  3, 32 }
      d!  3, 32; f!  3, 32; a  4, 32
    end
    # part 1->2
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
    rpt(4) do
      rpt(7) { c  3, 32; d  3, 32; d! 3, 32; }
      c! 3, 32; e  3, 32; g  3, 32
    end
    # part 4
    rpt(8) do
      g  3, 32; d! 3, 32; f  3, 32; g  3, 32; f  3, 32; d! 3, 32;
      g  3, 32; d! 3, 32; f  3, 32; a  4, 32; f  3, 32; d! 3, 32;
    end
    rpt(8) do
      g  3, 32; d! 3, 32; f  3, 32; a  4, 32; f  3, 32; d! 3, 32;
    end
    # part 5
    i :instr1_loud
    g  3
    # i :instr1_quiet
    rpt(2) do
      p 8, 16;
      m2; ve 0; n 31
      mt :mask_thrr1; mn :mask_thrr2; ne :noise_env1
      rpt(5) { d  3, 32; e 3, 32; f  3, 32; }
      d! 3, 32; f! 3, 32; a  4, 32;
      rpt(7) { d  3, 32; e 3, 32; f  3, 32; }
      d! 3, 32; f! 3, 32; a  4, 32;
      rpt(16) { d  3, 32; e 3, 32; f  3, 32; }
      m1; mt 0; mn 0;
      f  3
    end
    # part 6
    i :instr1_loud;
    c 3, 8, 16
    m2; ve 0; mn :mask_thrr2;
    rpt(14) { d  3, 32; e 3, 32; f  3, 32; }
    m1; mt 0; 
    # part 7
    i :instr1_loud;
    c 3, 8, 16
    m2; ve 0; mn :mask_thrr2
    rpt(14) { d  3, 32; e 3, 32; f  3, 32; }
    m1; mt 0; 
    # puts "counter1: #{counter}"
    # lt :mloop
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
    l :mloop
    # part 1
    rpt(2) do
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
    rpt(2) { rpt(15) { a! 3, 32, 32, 32; }; p 32, 32, 32; }
    # part 4
    rpt(6) do
      i :instr1_normal; a! 3, 32, 32, 32; i :instr1_quiet; c  4, 32, 32, 32;
      i :instr1_normal; a  3, 32, 32, 32; i :instr1_quiet; c  4, 32, 32, 32;
      i :instr1_normal; a! 3, 32, 32, 32; i :instr1_quiet; c  4, 32, 32, 32;
      i :instr1_normal; g  2, 32, 32, 32; i :instr1_quiet; c  4, 32, 32, 32;
    end
    # part 5
    i :instr2_loud
    np 1; c  0; np 16; c 1; vs 5; va 0.2
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
    vo; np 1; ce 0; n0; mn 0; i :instr1_loud
    rpt(2) do
      a! 1, 8, 16; a! 2, 4, 32; g  1, 8, 16; g  0, 16, 32; 
    end
    # part 7
    f 0, 16, 32; g  0, 16, 32; g  0, 4, 32; f 0, 8, 16; g  0, 16; g 0, 32
    # puts "counter2: #{counter}"
    # lt :mloop
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
    l :mloop
    # part 1
    rpt(32) { g  3, 32, 32, 32 }
    # part 1->2
    rpt(2) {  rpt(3) { d  3, 32, 32, 32 }; e  3, 32, 32, 32 }
    d  3, 32, 32, 32; d  3, 32, 32, 32
    c  3, 32, 32, 32; c  3, 32, 32, 32
    # part 2
    rpt(16) { c  3, 32, 32, 32 }
    # part 3
    rpt(2) { rpt(10) { f  3, 32, 32, 32 }; p 32, 32, 32; rpt(5) { f  3, 32, 32, 32 } }
    # part 4
    rpt(8) { rpt(3) { c  3, 32, 32, 32 }; d  3, 32, 32, 32 }
    i :instr1_normal
    rpt(8) { c  3, 32, 32, 32 ; d  3, 32, 32, 32 }
    # part 5
    i :instr1_loud
    c  3
    rpt(2) do
      ce :chord_note7; p 32, 32, 32;
      rpt(8) do
        i :instr1_normal; c  4, 32, 32, 32; i :instr1_quiet; c  3, 32, 32, 32;
      end
      i :instr1_quiet;
      ce :chord_note12; g  4, 32, 32, 32; g  4, 32, 32; f  4, 32, 32; e  4, 32, 32; 
      i :instr1_normal;
      ce 0;             d  5, 32, 32, 32;
      ce :chord_note12; c  4, 32, 32, 32; c  4, 32, 32, 32; i :instr1_loud; g  3, 32, 32, 32
      i :instr1_normal;
      ce 0;             c  3, 32, 32, 32; 
      i :instr1_quiet;
      ce :chord_note12; g  1, 32, 32, 32; g  1, 32, 32; f  1, 32, 32; e  1, 32, 32; i :instr1_normal; d  1, 32, 32, 32;
      c  1, 32, 32, 32; c  1, 32, 32, 32, 32, 32, 32;
      i :instr1_normal;
      ce :chord_note7;  c  3
      ce 0
    end
    # part 6
    i :instr1_loud;
    rpt(2) do
      a! 2, 8, 16; a! 3, 4, 32; g  2, 8, 16; g  1, 16, 32; 
    end
    # part 7
    f 1, 16, 32; g  1, 16, 32; g  1, 4, 32; f 1, 8, 16; g  1, 16, 32; g 1
    # puts "counter3: #{counter}"
    # lt :mloop
  end

  # volenv_clap1        music_envelope_data :all, [2, 0.999], [2, -0.999], [4, 0], [1, 0.499], [1, -0.5], [15-10, 0]
  # volenv_down1        music_envelope_data :all, [50, -1]
  # volenv_bass1        music_envelope_data :last, [5, 1.0], [100, -0.5], [255, -0.5]
  # volenv_chord1       music_envelope_data :last, [50, 0.6], [50, -0.5], [50, 0]
  # noienv_wave         music_envelope_data :all, [100, -1], [100, 1]
  # chord_data_major1   music_chord_data :all, [2, 0], [1, 4], [1, 7]
  # chord_data_minor1   music_chord_data :all, [2, 0], [1, 3], [1, 7]
  # chord_data_minor_d1 music_chord_data :all, [2, 0], [1, 3], [1, 6]
  # chord_data_7        music_chord_data :all, [1, 0], [1, 4], [1, 7], [1, 10]
  # chord_data_7_min    music_chord_data :all, [1, 0], [1, 3], [1, 7], [1, 10]
  # chord_data_7_maj    music_chord_data :all, [1, 0], [1, 4], [1, 7], [1, 11]
  # mask_noise_cha      music_mask_data :last, 8, 0b01111110, 8, 0b11011011, 128, 0b01010101
  # mask_data_swap      music_mask_data :all, 8, 0b0001111, 8, 0b11111100
  # chord_octave1         music_chord_data -2, [2, 0], [2, 12], [1, 0], [1, 12]
  # chord_note8           music_chord_data -2, [2, 0], [2, 8], [1, 0], [1, 8]
  # mask_noise_thrrr      music_mask_data :all, 8, 0b01010101, 8, 0b01010101
  # mask_noise_thr2       music_mask_data :all, 8, 0b01001000, 8, 0b00000000
  # mask_noise_hihat      music_mask_data :all, 8, 0b00000011, 8, 0b11001111, 8, 0b11110011, 8, 0b11111100, 8, 0b11111111
  noise_env1            music_envelope_data :all, [128, -1.0], [128, 1.0]
  # env1_down             music_envelope_data :last, [2, 0], [7, -1.0], [255, 0]
  # env1_slowdown         music_envelope_data :last, [100, -1.0], [255, 0]
  chord_note2           music_chord_data :all, [1, 0], [1, 2]
  chord_note5           music_chord_data :all, [1, 0], [1, 5]
  chord_note7           music_chord_data :all, [1, 0], [1, 7]
  chord_note12          music_chord_data :all, [1, 0], [1, 12]
  env_vol_piano1        music_envelope_data -2, [6, -0.2], [10, -0.3], [6, 0.2], [6, -0.2]
  env_vol_piano2        music_envelope_data -2, [3, 0.5], [12, -0.6], [6, 0.2], [6, -0.2]
  env_vol_piano3        music_envelope_data :last, [4, 1.0/3.0], [20, -0.1], [128, -0.5]
  env_vol_piano4        music_envelope_data :last, [24, -0.1], [64, 0], [255, -0.5]
  env_vol_silent        music_envelope_data :last, [10, -1.0]
  env_vol_silent_slow2  music_envelope_data :last, [255, -1.0]
  env_vol_silent_slow   music_envelope_data :last, [255, -0.1]
  mask_noise_1          music_mask_data :last, 8, 0b01111111, 8, 0b11111111
  mask_thrr1            music_mask_data :last, 8, 0b01010101
  mask_thrr2            music_mask_data :last, 8, 0b01110111
  mask_thrr3            music_mask_data :all,  8, 0b00000000, 8, 0b11111111
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

  music_track :instr2_loud do
    v 12; ve :env_vol_piano3
  end

  music_track :instr2_normal do
    v 12; ve :env_vol_piano4
  end

  music_track :instr3_loud do
    envd 16; envs 10; me :mask_envelope1; w 32; me 0; v 15; ve :env_vol_piano4
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

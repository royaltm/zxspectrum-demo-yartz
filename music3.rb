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
                      env_vol_piano1,
                      env_vol_piano2,
                      env_vol_silent,
                      env_vol_silent_slow,
                      env_vol_silent_slow2,
                      instr1_loud,
                      instr1_normal,
                      instr1_quiet,
                      instr2_normal,
                      instr2_quiet,
                      instr3_normal,
                      chord_note2,
                      chord_note7,
                      chord_note5,
                      chord_note12,
                      mask_noise_1,
                    )

  # $random = Random.new 1

  # $chord_note = ->(*notes) do
  #   notes[$random.rand notes.length]
  # end

# https://www.youtube.com/watch?v=oPMRG-UbN_0
# https://www.youtube.com/watch?v=wrOTpJK2cK0
# https://www.youtube.com/watch?v=AEMgNMNeBr4
# https://www.youtube.com/watch?v=ACN4jBNuHNU Debussy: 
# https://www.youtube.com/watch?v=UcIRjTYiRPU Debussy: Toccata
# https://www.youtube.com/watch?v=tNi5iTlKr_A Debussy: Pagodes / Estamples (L.100/1)
# https://www.youtube.com/watch?v=SO7iYa94N-M Debussy: Mouvement (L.110/3)
# https://www.youtube.com/watch?v=wXJW0TAeP3s Debussy: The Snow Is Dancing (L.113/4)
# https://www.youtube.com/watch?v=1EIE78D0m1g
# https://www.youtube.com/watch?v=4HTWyhqY0Hc
# https://www.youtube.com/watch?v=XiDtLscGnn8
  music_track :track_a do
    tempo 96
    n0
    i :instr1_loud
    # vs 30; vg 0.25
    p  32, 64
    rpt(2) do
      a  4, 8, 16     ; a  4, 16; a  4, 16; c  4, 16; b  4, 16; a  4, 16
      e  4, 8, 16     ; e  3, 16; e  3, 16; g! 3, 16; f! 3, 16; e  3, 16
      a  4, 8, 16     ; a  4, 16; a  4, 16; c  4, 16; b  4, 16; a  4, 16
      e  4, 4                             ; e  3, 8 ; ve :env_vol_silent; p 8
      i :instr1_normal
    end

    i :instr1_loud
    a  4, 8, 16     ; a  4, 16; a  4, 16; a! 4, 16; a  4, 16; g  3, 16
    f  3, 8, 16     ; d  3, 16; d  3, 16; f  3, 16; e  3, 16; d  3, 16
    g  3, 8, 16     ; g  3, 16; g  3, 16; a  4, 16; g  3, 16; f  3, 16
    e  3, 8, 16     ; c  3, 16; c  3, 16; e  3, 16; d  3, 16; c  3, 16
    f  3, 8, 16     ; b  3, 16; b  3, 16; d  3, 16; c  3, 16; b  3, 16
    tempo 112
    e  3, 8, 16     ; a  3, 16; a  3, 16; c  3, 16; b  3, 16; a  3, 16
    # f  2, 8         ; b  3, 8 ; b  3, 16; e  3, 16; d  3, 16; b  3, 16
    tempo 128
    i :instr1_normal
    f  2, 8         ; a  3; ce :chord_note2; p 16; ce 0                    # b  3, 8;
                      e  2, 16; 
                      b  3, 16;
                      b  3; ce :chord_note5; p 32 ; ce 0; m2; e  3, 32; m1 # e  3, 16;
                                                  ; d  3, 16; b  3, 16
    a  3, 4;
    p  32; #c  3, 32;
    e  3, 32; 
    p  16; #a  4, 16;
    ve :env_vol_silent; p  8

    sync 0

    # part #3
    tempo 128+64
    i :instr3_normal
    a  3, 16;
    rpt(2) do
      e  3, 16; a  4, 16; g! 3, 16;     a  4, 16; e  3, 16, 64; f! 3, 8, 64; a  3, 16,-64
      e  3, 16; a  4, 16; g! 3, 16, 64; a  4, 16; e  3, 16;     f! 3, 8, 64; g! 2, 16
      d! 3, 16; g! 3, 16; f! 3, 16;     g! 3, 16; d! 3, 16, 64; e  3, 8;     e  2, 16
      b  3, 16; e  3, 16; d! 3, 16, 64; e  3, 16; b  3, 16;     d  3, 8;     a  3, 16
    end
    rpt(2) do
      e  3, 16;     a  4, 16; g! 3, 16;     a  4, 16; e  3, 16, 64; g  3,  8, 32; d  2, 32
      a  3, 16;     d  3, 16; f! 3, 16;     e  3, 16; d  3, 16, 64; c! 3,  8, 64; g! 2, 16
      d! 3, 16;     g! 3, 16; g  3, 16;     g! 3, 16; d! 3, 16, 64; f! 3,  8, 32; c! 2, 32
      g! 2, 16, 64; c! 3, 16; e  3, 16;     d! 3, 16; c! 3, 16, 64; b  3,  8;     f! 2, 16
      c! 3, 16;     f! 3, 16; f  3, 16;     f! 3, 16; d  3, 16;     c! 3, 16, 64; b  3, 16; e  2, 16
      b  3, 16;     e  3, 16; d! 3, 16, 64; e  3, 16; c! 3, 16;     b  3, 16;     a  3, 16, 64; d  2, 16
      a  3, 16;     d  3, 16; a  3, 16, 64; e  2, 16; b  3, 16;     e  3, 16;     d  3, 16, 64; a  3, 16; e  3, 16
      a  4, 16;     g! 3, 16; a  4, 16;     c! 3, 16, 64; e  3, 8;  a  3, 16;
    end
    ve :env_vol_silent_slow2
  end

  music_track :track_b do
    tempo 96
    n0
    i :instr1_loud
    # vs 30
    p  32, 64
    w  1
    rpt(2) do
      a  3, 8, 16     ; a  3, 16; a  3, 16; c  3, 16; b  3, 16; a  3, 16
      e  3, 8, 16     ; e  2, 16; e  2, 16; g! 2, 16; f! 2, 16; e  2, 16
      a  3, 8, 16     ; a  3, 16; a  3, 16; c  3, 16; b  3, 16; a  3, 16
      e  3, 4                             ; e  2, 8 ; ve :env_vol_silent; p 8
      i :instr1_normal
    end

    i :instr1_normal
    a  3, 8, 16     ; a  3, 16; a  3, 16; a! 3, 16; a  3, 16; g  2, 16
    f  2, 8, 16     ; d  2, 16; d  2, 16; f  2, 16; e  2, 16; d  2, 16
    g  2, 8, 16     ; g  2, 16; g  2, 16; a  3, 16; g  2, 16; f  2, 16
    e  2, 8, 16     ; c  2, 16; c  2, 16; e  2, 16; d  2, 16; c  2, 16
    f  2, 8, 16     ; b  2, 16; b  2, 16; d  2, 16; c  2, 16; b  2, 16
    tempo 112
    e  2, 8, 16     ; a  2, 16; a  2, 16; c  2, 16; b  2, 16; a  2, 16
    # f  1, 8         ; b  2, 8 ; b  2, 16; e  2, 16; d  2, 16; b  2, 16
    tempo 128
    f  1, 8         ; a  2; ce :chord_note2; p 16; ce 0                    # b  2, 8;
                      e  1, 16, 32; 
                      b  2, 16, -32;
                      b  2; ce :chord_note5; p 32 ; ce 0; m2; e  2, 32; m1 # e  2, 16;
                                                  ; d  2, 16; b  2, 16
    a  2, 8, 4; ve :env_vol_silent; p  8

    sync 0

    # part 2
    tempo 128+64
    p 16
    i :instr1_normal
    rpt(2) do
      p 16;               c! 4, 8;      c! 5, 8;             a  5, 8, -64;             f! 4, 16, 32
      p 16, 64;           c  4, 8;      c  5, 8;             a  5, 8, -64;             f! 4, 16, 32
      p 16;               b  4, 8;      b  5, 8;             g! 4, 8;                  e  4, 16, 64
      p 16;               g! 3, 8;      g! 4, 8;             e  4, 8, -64;             d  4, 16, 32
    end
    rpt(2) do
      p 16;             c! 4, 8;      c! 5, 8;             a  5, 8, 64;              
      i :instr3_normal; g  4, 16; vo; i :instr1_normal
      p 16;             a  4, 8;      a  5, 16, 64; f! 4, 32, 64; e  4, 16, 32; d  4, 16; c! 4, 16
      p 16;             c  4, 8;      c  5, 8;      g! 4,  8, 32; f! 4, 32, 64
      p 16;             g! 3, 8, 64;  g! 4, 8;      d! 4, 16, 64; c! 4, 16;     b  4, 16
      p 16;             a! 4, 8;      a! 5, 8;      f! 4, 16, 64; d  4, 32, 64; c! 4, 16, 64
      p 64;             b  4, 32, 64; g! 3, 8, 64;  g! 4, 8;      e  4, 16, 64; c! 4, 32, 64; b  4, 16, 64
      p 64;             a  4, 32, 64; f  3, 8, 64;  f  4, 8;      g! 3, 8;      g! 4, 8, 64
      c! 4, 8;          c! 5, 8;      a  5, 8;      e  4, 16, 64;
    end
    ve :env_vol_silent_slow2
  end

  music_track :track_c do
    tempo 96
    n0
    vs 30
    i :instr2_normal
    rpt(2) do
      a  5, 32; e 4, 16 ; a 4; ve :env_vol_silent_slow; p 2, -32, -16
      e  5, 32; b 5, 16 ; e 4; ve :env_vol_silent_slow; p 2, -32, -16
      a  5, 32; e 4, 16 ; a 4; ve :env_vol_silent_slow; p 1, -32, -16
      i :instr2_quiet
    end

    vs 60
    i :instr2_normal
    a  5, 32; e  4, 16; a 4; ve :env_vol_silent_slow; p 2, -32, -16
    f  4, 32; a  4, 16; f 3; ve :env_vol_silent_slow; p 2, -32, -16
    g  4, 32; d  4, 16; g 3; ve :env_vol_silent_slow; p 2, -32, -16
    e  4, 32; g  3, 16; e 3; ve :env_vol_silent_slow; p 2, -32, -16
    f  4, 32; b  4, 16; f 3; ve :env_vol_silent_slow; p 2, -32, -16
    tempo 112
    e  3, 32; a  3, 16; e 2; ve :env_vol_silent_slow; p 2, -32, -16
    tempo 128
    p  8, 32, 64      ; d! 2, 16; ce :chord_note12; ve :env_vol_silent_slow; p 16
                      ; g! 1, 8; ve :env_vol_silent_slow; p 8; ce 0
    vo; v 0; i :instr1_normal
    p  4; #a  3, 4;
    c  3, 32;
    p  32; #e  3, 32; 
    a  4, 16;
    ve :env_vol_silent; p  8, -32, -64

    sync 0

    # part 3
    tempo 128+64
    p 16
    i :instr1_normal
    rpt(2) do
      p 16, 32; a  5, 32, 64; e  5, 16, 32; c! 6, 32, 64; g! 5, 16, 64; a  6, 32;     e  5, 16; f! 5, 16
      p  8,-64; a  5, 32, 64; e  5, 16, 64; c  6, 32, 64; g! 5, 16, 32; a  6, 32;     e  5, 16; f! 5, 16
      p 16, 32; g! 4, 32, 64; d! 5, 16, 64; b  6, 32, 64; f! 5, 16, 32; g! 5, 32;     d! 5, 16; e  5, 16
      p 16, 32; e  4, 32, 64; b  5, 16, 64; g! 5, 32, 64; d! 5, 16, 64; e  5, 32, 64; b  5, 16; d  5, 16
    end
    rpt(2) do
      p 16, 32; a  5, 32, 64; e  5, 16, 64; c! 6, 32, 64; g! 5, 16, 64; a  6, 32, 64; e  5, 16;
      i :instr3_normal; g  5, 16; vo; i :instr1_normal
      p 16, 32; d  4, 32, 64; a  5, 16, 64; a  6, 32, 64; f! 5, 16, 32; e  5, 32, 64; d  5, 16; c! 5, 16
      p 16, 32; g! 4, 32, 64; d! 5, 16, 32; c  6, 32;     g  5, 16, 32; g! 5, 32, 64; d! 5, 16; f! 5, 16,-64
      p  8,-64; c! 4, 32, 64; g! 4, 16, 64; g! 5, 32, 64; e  5, 16, 64; d! 5, 32, 64; c! 5, 16; b  5, 16
      p 16, 32; f! 4, 32, 64; c! 5, 16, 64; a! 6, 32, 64; f  5, 16, 64; f! 5, 32, 64; d  5, 16, 32; c! 5, 32
      p 64; b  5, 16, 64; c! 4, 16; b  5, 16, 64; g! 5, 32, 64; d! 5, 16, 64; e  5, 32, 64; c! 5, 16, 32; b  5, 32
      p 64; a  5, 16, 64; d  4, 32, 64; b  5, 16, 32; f  5, 32, 64; a  5, 16, 64; e  4, 32, 64; b  5, 16, 32; g! 5, 32, 64; d  5, 32, 64
      p 32; a  5, 32, 64; e  5, 16, 32; c! 6, 32;     g! 5, 16, 32; a  6, 32;     e  5, 16;     e  5, 16;
    end
    ve :env_vol_silent_slow2
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
  # noise_env1            music_envelope_data :last, [60, -1.0], [255, 0]
  # env1_down             music_envelope_data :last, [2, 0], [7, -1.0], [255, 0]
  # env1_slowdown         music_envelope_data :last, [100, -1.0], [255, 0]
  chord_note2           music_chord_data :all, [1, 0], [1, 2]
  chord_note5           music_chord_data :all, [1, 0], [1, 5]
  chord_note7           music_chord_data :all, [1, 0], [1, 7]
  chord_note12          music_chord_data :all, [1, 0], [1, 12]
  env_vol_piano1        music_envelope_data -2, [6, -0.2], [10, -0.3], [6, 0.2], [6, -0.2]
  env_vol_piano2        music_envelope_data -2, [3, 0.5], [12, -0.6], [6, 0.2], [6, -0.2]
  env_vol_silent        music_envelope_data :last, [10, -1.0]
  env_vol_silent_slow2  music_envelope_data :last, [255, -1.0]
  env_vol_silent_slow   music_envelope_data :last, [255, -0.1]
  mask_noise_1          music_mask_data :last, 8, 0b01111111, 8, 0b11111111

  music_track :instr1_loud do
    v 15; ve :env_vol_piano1
  end

  music_track :instr1_normal do
    v 13; ve :env_vol_piano1
  end

  music_track :instr1_quiet do
    v 11; ve :env_vol_piano1
  end

  music_track :instr2_normal do
    sub :instr1_normal; va 0.6
  end

  music_track :instr2_quiet do
    sub :instr1_quiet; va 0.6
  end

  music_track :instr3_normal do
    ve :env_vol_piano2; vo; w 5; vg 0; va 0.4; vs 30
  end

  export music_data_len

  music_data_len      notes - 1 - instrument_table

  NOTES = ay_tone_periods(min_octave:0, max_octave:7)

  (1...NOTES.length).each do |i|
    puts "#{NOTES[i-1].to_s.rjust(4)}-#{NOTES[i].to_s.rjust(4)} #{NOTES[i-1]-NOTES[i]} #{(NOTES[i-1].to_f/NOTES[i])}"
  end

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
  puts music.debug
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

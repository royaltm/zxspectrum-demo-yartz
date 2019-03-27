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
                      # volenv_clap1,
                      # volenv_down1,
                      # volenv_bass1,
                      # volenv_chord1,
                      # noienv_wave,
                      instrument1,
                      instrument2,
                      instrument3,
                      instrument4,
                      instrument5,
                      bass1,
                      bass3,
                      perc1,
                      hihat1,
                      chord_octave1,
                      chord_note8,
                      mask_noise_thrrr,
                      mask_noise_hihat,
                      mask_noise_thr2,
                      noise_env1,
                      env1_down,
                      env1_simple,
                      env1_slowdown,
                      # chord_data_major1,
                      # chord_data_minor1,
                      # chord_data_minor_d1,
                      # chord_data_7,
                      # chord_data_7_min,
                      # chord_data_7_maj,
                      # mask_noise_cha,
                      # mask_data_swap,
                    )

  # $random = Random.new 1

  # $chord_note = ->(*notes) do
  #   notes[$random.rand notes.length]
  # end

  tempo = 10

  music_track :track_a do
    n0
    rpt do
      i :instrument1
      g 2; w tempo; g 2; w tempo; a 3; w tempo*2;
      a 4; w tempo*2; g 3; w tempo*3; e 3; w tempo*2; e 3; w tempo*2;
      i :instrument2; c 3; w tempo*3
      i :instrument1
      g 2; w tempo; g 2; w tempo; a 3; w tempo*2;
      a 4; w tempo*2; g 3; w tempo*3; e 3; w tempo*2; e 3; w tempo*2;
      i :instrument2; g 3; w tempo*3
      i :instrument1
      g 2; w tempo; g 2; w tempo; a 4; w tempo*2
      a 4; w tempo*2; g 3; w tempo*3; e 3; w tempo*2; e 3; w tempo*2;
      c 3; w tempo;  i :instrument4; e 2; w tempo
      i :instrument1; e 2; w tempo
      i :instrument3; f 2; w tempo
      i :instrument1; f 2; w tempo*5; g 3; w tempo; a 4; w tempo; f 2; w tempo; f 2; w tempo*7
      # 640

      g 3; w tempo; g 3; w tempo; a 4; w tempo*2;
      a 4; w tempo*2; g 3; w tempo*3; e 3; w tempo*2; e 3; w tempo*2;
      i :instrument2; c 3; w tempo*3
      i :instrument1
      g 2; w tempo; g 2; w tempo; a 3; w tempo*2;
      a 4; w tempo*2; g 3; w tempo*3; e 3; w tempo*2; np 1; e 3; w tempo*2
      i :instrument2; np 4; g 3; w tempo*3
      #
      np 1
      g 2; w tempo; g 2; w tempo; a 4; w tempo*2
      a 4; w tempo*2; np 6; g 3; w tempo*3; e 3; w tempo*2; e 3; w tempo*2;
      c 3; w tempo;  np 1; i :instrument3; e 2; w tempo
      i :instrument1; e 2; w tempo
      #
      i :instrument3; f 2; w tempo
      i :instrument1; f 2; w tempo; a 4; w tempo*4; 
      g 3; w tempo; a 4; w tempo; f 2; w tempo; f 2; w tempo*3
      a 4; w tempo; f 3; w tempo; d 3; w tempo; a 3; w tempo;

    end
    # s 240
    # n1; np 1; a 6; tp -3*12, 50;
    # envd 1; envs 8; vv; a 3
    # w 50
    # envd 2; tp 3*12, 50; a 6
    # w 50
    # v 0; fv
  end

  music_track :track_b do
    n0
    rpt(2) { w 1; s 0}; s 128
    rpt do
      # 2
      i :instrument5
      e 3; w tempo*2; c 3; w tempo*7; a 4; w tempo*4; g 3; w tempo*2; c 3; w tempo
      # 3
      i :instrument1
      w tempo*3; g 3; w tempo*2;
      c 4; w tempo; b 4; w tempo; a 4; w tempo; g 3; w tempo*3; g 4; w tempo*2;
      i :instrument5; a 5; w tempo*3
      # 4
      i :instrument1
      w tempo*2; c 3; w tempo*4; e 3; w tempo*3; c 4; w tempo*2; g 3; w tempo*2; e 3; w tempo;
      i :instrument5; c 3; w tempo*2
      # 5
      i :instrument1
      d 3; w tempo; g 3; w tempo; c 4; w tempo; a 4; w tempo*3; 
      i :instrument5; e 3; w tempo*6
      w tempo*4
      # i :instrument4; a 4; w tempo; a 4; w tempo;
      # i :instrument4; f 3; w tempo; f 3; w tempo;
    end
    # s 240
    # t1; n 31; v 15; np 1; a 6; tp -6*12, 100; a 0; ne :noise_env1; w 40
    # ve :env1_slowdown; w 60; ve 0
    # n0; t0; v 0
  end

  # https://goo.gl/gV3nGg
  # https://goo.gl/tD8diu
  # https://goo.gl/wzMwRN

  music_track :track_c do
    t0; n1
    t0; rpt(3) { w 1; s 0}; w 14
    # 782
    n 1; v 15; mn :mask_noise_thrrr; w 40; mn 0; v 0
    w 18;
    t1; v 15; mn :mask_noise_hihat
    i :bass1
    g 0; w tempo*3; d 1; w tempo*3
    g 0; w tempo*2;
    d 0; w tempo*3; d 0; w tempo*1;

    i :bass1
    w tempo*2; d 0; w tempo*2; g 0; w tempo*3; d 1; w tempo*3
    g 0; w tempo*2;
    d 0; w tempo*3; d 0; w tempo*1;

    rpt do
      i :bass1
      w tempo*2; d 0; w tempo; d 0; w tempo; g 0; w tempo; g 0; w tempo*2;
      d 0; w tempo; d 1; w tempo; d 1; w tempo; 
      f 0; w tempo; f 0; w tempo*3;
      e 0; w tempo; e 0; w tempo; 

      rpt(3) do
        i :bass1
        w tempo*2; d 0; w tempo*2; g 0; w tempo*3; d 1; w tempo*3
        g 0; w tempo*2;
        # i :bass3
        # d 0; w tempo*4;
        d 0; w tempo*3; d 0; w tempo*1;
      end
    end
    # rpt do
    #   i :perc1; 
    #   c 1; w tempo; c 1; w tempo;
    #   i :hihat1;
    #   c 1; w tempo; c 1; w tempo;
    # end
    # s 240
    # n0; v 15; np 1; a 4; vs 80; va 1.0; tp -3, 100; w 40
    # g 3; va 1.0; ve :env1_slowdown; w 60; ve 0
    # t0; v 0
  end

  export music_data_len

  music_data_len      notes - 1 - instrument_table

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
  chord_octave1         music_chord_data -2, [2, 0], [2, 12], [1, 0], [1, 12]
  chord_note8           music_chord_data -2, [2, 0], [2, 8], [1, 0], [1, 8]
  mask_noise_thrrr      music_mask_data :all, 8, 0b01010101, 8, 0b01010101
  mask_noise_thr2       music_mask_data :all, 8, 0b01001000, 8, 0b00000000
  mask_noise_hihat      music_mask_data :all, 8, 0b00000011, 8, 0b11001111, 8, 0b11110011, 8, 0b11111100, 8, 0b11111111
  noise_env1            music_envelope_data :last, [60, -1.0], [255, 0]
  env1_down             music_envelope_data :last, [2, 0], [7, -1.0], [255, 0]
  env1_simple           music_envelope_data :last, [10, -0.2], [100, -0.5]
  env1_slowdown         music_envelope_data :last, [100, -1.0], [255, 0]

  music_track :perc1 do
    n 20; v 12; ve :env1_down; mn :mask_noise_thr2
    w tempo; ve 0; mn 0
  end

  music_track :hihat1 do
    n 1; v 12; w tempo - 1; v 0
  end

  music_track :bass1 do
    t1; vs 30; va 0.2; w tempo - 1; vo; t0
    # v 15; vs 30; va 0.2; w tempo - 1; vo; v 0
  end

  music_track :bass3 do
    t1; vs 30; va 0.2; w tempo*3 - 1; vo; t0
    # v 15; vs 30; va 0.2; w tempo*3 - 1; vo; v 0
  end

  music_track :instrument1 do
    v 15; ve :env1_simple; w tempo - 1; ve 0; v 0
  end

  music_track :instrument2 do
    v 15; ve :env1_simple; w tempo; vs 50; va 0.4; w tempo - 1; vo; ve 0; v 0
  end

  music_track :instrument3 do
    v 15; ve :env1_simple; ce :chord_octave1; w tempo - 1; ce 0; ve 0; v 0
  end

  music_track :instrument4 do
    v 15; ve :env1_simple; ce :chord_note8; w tempo - 1; ce 0; ve 0; v 0
  end

  music_track :instrument5 do
    v 15; ve :env1_simple; vs 64; va 0.3; w tempo*2; vo; ve 0; v 0
  end

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

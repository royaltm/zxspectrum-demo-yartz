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
                      volenv_clap1,
                      volenv_down1,
                      volenv_bass1,
                      volenv_chord1,
                      noienv_wave,
                      instrument1,
                      instrument2,
                      instrument3_major1,
                      instrument3_minor1,
                      instrument3_7,
                      instrument3_7_min,
                      instrument3_7_maj,
                      chord_data_major1,
                      chord_data_minor1,
                      chord_data_minor_d1,
                      chord_data_7,
                      chord_data_7_min,
                      chord_data_7_maj,
                      mask_noise_cha,
                    )

  # $random = Random.new 1

  # $chord_note = ->(*notes) do
  #   notes[$random.rand notes.length]
  # end

  tempo = 12

  music_track :track_a do
    # t0; n1;
    # sub :clap1
    n 31
    ne :noienv_wave
    v 8; n0; i :instrument1; vs 30
    # np 1; a 2; np 3
    l :mloop
    l :loop1
    a 2; w tempo
    c 3; w tempo
    d 3; w tempo
    c 3; w tempo
    e 3; w tempo
    c 3; w tempo
    d 3; w tempo
    c 3; w tempo
    lt :loop1, 2

    l :loop1
    b 2; w tempo
    d 3; w tempo
    e 3; w tempo
    d 3; w tempo
    f 3; w tempo
    d 3; w tempo
    e 3; w tempo
    c 3; w tempo
    lt :loop1, 2

    l :loop1
    c  2; w tempo
    e_ 3; w tempo
    f  3; w tempo
    e_ 3; w tempo
    g  3; w tempo
    e_ 3; w tempo
    f  3; w tempo
    e_ 3; w tempo
    lt :loop1, 2

    l :loop1
    d! 2; w tempo
    g  3; w tempo
    a  4; w tempo
    g  3; w tempo
    a! 4; w tempo
    g  3; w tempo
    a  4; w tempo
    g  3; w tempo
    lt :loop1, 2

    l :loop1
    d 2; w tempo
    f 3; w tempo
    g 3; w tempo
    f 3; w tempo
    a 4; w tempo
    f 3; w tempo
    g 3; w tempo
    f 3; w tempo
    lt :loop1, 2

    l :loop1
    e  2; w tempo
    g  3; w tempo
    a  4; w tempo
    g  3; w tempo
    b  4; w tempo
    g  3; w tempo
    a  4; w tempo
    g  3; w tempo
    lt :loop1, 2

    l :loop1
    f! 2; w tempo
    a  4; w tempo
    b  4; w tempo
    a  4; w tempo
    c! 4; w tempo
    a  4; w tempo
    b  4; w tempo
    a  4; w tempo
    lt :loop1, 2

    l :loop1
    f  2; w tempo
    a  4; w tempo
    b  4; w tempo
    a  4; w tempo
    c  4; w tempo
    a  4; w tempo
    b  4; w tempo
    a  4; w tempo
    lt :loop1, 2
    lt :mloop
  end

  music_track :track_b do
    n0; i :instrument2
    v 0
    vs 10; np 1
    l :bloop
    d 1; s tempo*16 - 10
    c 1; s tempo*16*2 - 10
    e 1; s tempo*16*3 - 10; np 20
    g 0; s tempo*16*4 - 10; np 1
    f 1; s tempo*16*5 - 10
    b 0; s tempo*16*6 - 10; np 20
    c! 1; s tempo*16*7 - 10; np 1
    c 1; s tempo*16*8 - 10
    lt :bloop
  end

  # https://goo.gl/gV3nGg
  # https://goo.gl/tD8diu https://goo.gl/wzMwRN

  music_track :track_c do
    n0; v 4
    l :cloop
    i :instrument3_major1
    c 4; s tempo*8*1; a 4; s tempo*8*2
    d 4; s tempo*8*3; b 4; s tempo*8*4
    i :instrument3_minor1
    e_ 4; s tempo*8*5; c 4; s tempo*8*6
    g 4; s tempo*8*7; d! 4; s tempo*8*8
    i :instrument3_7_maj
    f 4; s tempo*8*9; d 4; s tempo*8*10
    g 4; s tempo*8*11; e 4; s tempo*8*12
    i :instrument3_7_min
    a 4; s tempo*8*13; f! 4; s tempo*8*14
    i :instrument3_7
    a 4; s tempo*8*15; f 4; s tempo*8*16
    lt :cloop
  end

  export music_data_len

  music_data_len      notes - 1 - instrument_table

  volenv_clap1        music_envelope_data :all, [2, 0.999], [2, -0.999], [4, 0], [1, 0.499], [1, -0.5], [15-10, 0]
  volenv_down1        music_envelope_data :all, [50, -1]
  volenv_bass1        music_envelope_data :last, [5, 1.0], [100, -0.5], [255, -0.5]
  volenv_chord1       music_envelope_data :last, [50, 0.6], [50, -0.5], [50, 0]
  noienv_wave         music_envelope_data :all, [100, -1], [100, 1]
  chord_data_major1   music_chord_data :all, [2, 0], [1, 4], [1, 7]
  chord_data_minor1   music_chord_data :all, [2, 0], [1, 3], [1, 7]
  chord_data_minor_d1 music_chord_data :all, [2, 0], [1, 3], [1, 6]
  chord_data_7        music_chord_data :all, [1, 0], [1, 4], [1, 7], [1, 10]
  chord_data_7_min    music_chord_data :all, [1, 0], [1, 3], [1, 7], [1, 10]
  chord_data_7_maj    music_chord_data :all, [1, 0], [1, 4], [1, 7], [1, 11]
  mask_noise_cha      music_mask_data :last, 8, 0b01111110, 8, 0b11011011, 128, 0b01010101

  music_track :instrument1 do
    mn :mask_noise_cha
    va 0.4
    v 14
    ve :volenv_down1
  end

  music_track :instrument2 do
    ve :volenv_bass1; vo; w 20; vg 0; va 0.3
  end

  music_track :instrument3_major1 do
    ve :volenv_chord1; ce :chord_data_major1
  end
  music_track :instrument3_minor1 do
    ve :volenv_chord1; ce :chord_data_minor1
  end
  music_track :instrument3_7 do
    ve :volenv_chord1; ce :chord_data_7
  end
  music_track :instrument3_7_min do
    ve :volenv_chord1; ce :chord_data_7_min
  end
  music_track :instrument3_7_maj do
    ve :volenv_chord1; ce :chord_data_7_maj
  end


  # chord_data1       music_chord_data :all, [3, 0], [2, 4], [1, 7], [1, 10]
  # env_data1         music_envelope_data :all, [255, -1]
  # mask_data1        music_mask_data :all, 32, 0b10101010, 32, 0b11001100, 16, 0b11110000, 8, 0b11111111, 8, 0b00000000

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

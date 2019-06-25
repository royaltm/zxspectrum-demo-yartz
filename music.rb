require 'z80'
require 'zxutils/ay_music'

# Change at will
require_relative 'music6'
# Change accordingly
Song = Mouvement

class Music
  include Z80
  include ZXUtils

  ########
  # SONG #
  ########

  Song = ::Song

  MusicInstance = Song.new
  MusicData = MusicInstance.to_program

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
  export index_table
  export track_a
  export track_b
  export track_c
  export song
  export song_end

  # re-export AYMusic play
  play                music.play

  macro_import        MathInt
  label_import        ZXLib::Sys
  macro_import        ZXLib::AYSound
  macro_import        AYMusic

  export :auto

  ministack           addr 0xF500, 2
  track_stack_end     addr ministack[-AYMusic::MINISTACK_DEPTH], AYMusic::TrackStackEntry
  empty_instrument    addr track_stack_end[-1]
  music_control       addr 0xF100, AYMusic::MusicControl
  fine_tones          addr 0xE400, 2          # count 256
  note_to_cursor      addr fine_tones[256], 2 # max count 96

  export :noauto

  AY_MUSIC_OVERRIDE = { io128: io128,
                        index_table: index_table,
                        notes: notes, note_to_cursor: note_to_cursor, fine_tones: fine_tones,
                        track_stack_end: track_stack_end,
                        empty_instrument: empty_instrument,
                        music_control: music_control,
                        ministack: ministack }

  start               label

  ns :init do
    ns :extend_notes do
                      ay_extend_notes music.notes, octaves:8, save_sp:true, disable_intr:false, enable_intr:false
    end
    ns :tone_progress_table_factory do
                      ay_music_tone_progress_table_factory fine_tones
    end
    ns :note_to_fine_tone_cursor_table_factory do
                      ay_music_note_to_fine_tone_cursor_table_factory note_to_cursor, play: music.play
    end
                      call music.init
                      dw   track_a, track_b, track_c
                      ret
  end

  ns :mute do
                      ay_init io128:io128
                      ret
  end

  song                import MusicData
  song_end            label

  import              AYMusic, :music, override: AY_MUSIC_OVERRIDE
  music_end           label

  NOTES = ay_tone_periods(min_octave:0, max_octave:0)
                      dw NOTES[11]*2
  notes               dw NOTES
end # Music


if __FILE__ == $0

  require 'zxutils/zx7'
  require 'zxlib/basic'

  include ZXLib
  include ZXUtils

  class MusicTest
    include Z80
    include Z80::TAP

    import              Sys, macros: true, code: false
    macro_import        AYSound
    macro_import        AYMusic
    macro_import        Utils::SinCos

    sincos              addr 0xF500, AYMusic::SinCos

    with_saved :demo, :exx, hl, ret: true do
                        di
                        call make_sincos
                        call music.init
      forever           ei
                        halt
                        di
                        push iy
                        ld   a, 1
                        out  (io.ula), a
                        ay_music_preserve_io_ports_state(music.music_control, music.play, bc_const_loaded:false)
                        call music.play
                        ld   a, 6
                        out  (io.ula), a
                        pop  iy
                        ld   de, [music.music_control.counter]
                        cp16n d, e, Music::MusicInstance.channel_tracks.map(&:ticks_counter).max
                        jr   NC, quit
                        key_pressed?
                        jp  Z, forever
      quit              call music.mute
                        ei
    end

    make_sincos       create_sincos_from_sintable sincos, sintable:sintable

    sintable          bytes   neg_sintable256_pi_half_no_zero_lo
    sincos_end        label

    import            Music, :music, override: {'music.sincos': sincos, io128: io128 }
    music_end         label
  end

  io_ay = ZXSys.io128
  # io_ay = ZXSys.fuller_io
  # io_ay = ZXSys.ioT2k
  music = MusicTest.new 0x8000, override: { io128: io_ay }
  puts music.debug
  puts "music size: #{music[:music_end] - music[:music]}"
  puts "song size: #{music['music.song_end'] - music['music.song']}"
  %w[
    +music.init.extend_notes +music.init.tone_progress_table_factory +music.init.note_to_fine_tone_cursor_table_factory
    demo
    music.index_table
    music.music.notes
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
    music.song music.song_end +music.song
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

require 'zxutils/music_box'

class Music3
  include ZXUtils::MusicBox::Song
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

  # no synchronization allowed, channels must be perfectly synced manually
  synchronize_channels a: 2...2, b: 0...0, c: 7...7

  tempo 96

  all_ch { n0 }

  ch_a do
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
  end

  ch_b do
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
  end

  ch_c do
    vs 30
    i :instr2_normal
    rpt(2) do
      a  5, 32; e 4, 16 ; a 4; ve :env_vol_silent_slow; p 2, -32, -16
      e  5, 32; b 5, 16 ; e 4; ve :env_vol_silent_slow; p 2, -32, -16
      a  5, 32; e 4, 16 ; a 4; ve :env_vol_silent_slow; p 1, -32, -16
      i :instr2_quiet
    end
  end

  mark :part_2

  ch_a do
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
    f  2, 8         ; a  3; ce :chord_note2; p 16; ceo                    # b  3, 8;
                      e  2, 16; 
                      b  3, 16;
                      b  3; ce :chord_note5; p 32 ; ceo; m2; e  3, 32; m1 # e  3, 16;
                                                  ; d  3, 16; b  3, 16
    a  3, 4;
    p  32; #c  3, 32;
    e  3, 32; 
    p  16; #a  4, 16;
    ve :env_vol_silent; p  8
  end

  ch_b do
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
    f  1, 8         ; a  2; ce :chord_note2; p 16; ceo                    # b  2, 8;
                      e  1, 16, 32; 
                      b  2, 16, -32;
                      b  2; ce :chord_note5; p 32 ; ceo; m2; e  2, 32; m1 # e  2, 16;
                                                  ; d  2, 16; b  2, 16
    a  2, 8, 4; ve :env_vol_silent; p  8
  end

  ch_c do
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
                      ; g! 1, 8; ve :env_vol_silent_slow; p 8; ceo
    vo; v 0; i :instr1_normal
    p  4; #a  3, 4;
    c  3, 32;
    p  32; #e  3, 32; 
    a  4, 16;
    ve :env_vol_silent; p  8, -32, -64
  end

  chord    :chord_note2          , [1, 0], [1, 2]
  chord    :chord_note5          , [1, 0], [1, 5]
  chord    :chord_note12         , [1, 0], [1, 12]
  envelope :env_vol_piano1       , [6, -0.2], [10, -0.3], :loop, [6, 0.2], [6, -0.2]
  envelope :env_vol_silent       , [10, -1.0]
  envelope :env_vol_silent_slow  , [255, -0.1]

  instrument :instr1_loud do
    v 15; ve :env_vol_piano1
  end

  instrument :instr1_normal do
    v 13; ve :env_vol_piano1
  end

  instrument :instr1_quiet do
    v 11; ve :env_vol_piano1
  end

  instrument :instr2_normal do
    sub :instr1_normal; va 0.6
  end

  instrument :instr2_quiet do
    sub :instr1_quiet; va 0.6
  end

end # Music3


if __FILE__ == $0
  require 'z80'

  music = Music3.new
  musmod = music.to_module
  puts musmod.to_program.new(0x8000).debug
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

require 'zxutils/music_box'

class Music4
  include ZXUtils::MusicBox::Song

  # no synchronization allowed, channels must be perfectly synced manually
  synchronize_channels a: 0...0, b: 0...0, c: 0...0

  tempo 128+64

  # no synchronization allowed, channels must be perfectly synced manually
  synchronize_channels a: 0...0, b: 0...0, c: 0...0

# https://www.youtube.com/watch?v=oPMRG-UbN_0
# https://www.youtube.com/watch?v=wrOTpJK2cK0
# https://www.youtube.com/watch?v=AEMgNMNeBr4
# https://www.youtube.com/watch?v=1EIE78D0m1g
# https://www.youtube.com/watch?v=4HTWyhqY0Hc
  ch_a do
    n0
    i :instr3_normal
    a  3, 16;
  end

  for_ch :b, :c do
    n0
    p 16
    i :instr1_quiet
  end

  rpt(2) do
    ch_a do
      e  3, 16; a  4, 16; g! 3, 16;     a  4, 16; e  3, 16, 64; f! 3, 8, 64; a  3, 16,-64
      e  3, 16; a  4, 16; g! 3, 16, 64; a  4, 16; e  3, 16;     f! 3, 8, 64; g! 2, 16
      d! 3, 16; g! 3, 16; f! 3, 16;     g! 3, 16; d! 3, 16, 64; e  3, 8;     e  2, 16
      b  3, 16; e  3, 16; d! 3, 16, 64; e  3, 16; b  3, 16;     d  3, 8;     a  3, 16
    end

    ch_b do
      p 16;               c! 4, 8;      c! 5, 8;             a  5, 8, -64;             f! 4, 16, 32
      p 16, 64;           c  4, 8;      c  5, 8;             a  5, 8, -64;             f! 4, 16, 32
      p 16;               b  4, 8;      b  5, 8;             g! 4, 8;                  e  4, 16, 64
      p 16;               g! 3, 8;      g! 4, 8;             e  4, 8, -64;             d  4, 16, 32
      i :instr1_normal
    end

    ch_c do
      p 16, 32; a  5, 32, 64; e  5, 16, 32; c! 6, 32, 64; g! 5, 16, 64; a  6, 32;     e  5, 16; f! 5, 16
      p  8,-64; a  5, 32, 64; e  5, 16, 64; c  6, 32, 64; g! 5, 16, 32; a  6, 32;     e  5, 16; f! 5, 16
      p 16, 32; g! 4, 32, 64; d! 5, 16, 64; b  6, 32, 64; f! 5, 16, 32; g! 5, 32;     d! 5, 16; e  5, 16
      p 16, 32; e  4, 32, 64; b  5, 16, 64; g! 5, 32, 64; d! 5, 16, 64; e  5, 32, 64; b  5, 16; d  5, 16
      i :instr1_normal
    end
  end # rpt

  rpt(2) do
    ch_a do
      e  3, 16;     a  4, 16; g! 3, 16;     a  4, 16; e  3, 16, 64; g  3,  8, 32; d  2, 32
      a  3, 16;     d  3, 16; f! 3, 16;     e  3, 16; d  3, 16, 64; c! 3,  8, 64; g! 2, 16
      d! 3, 16;     g! 3, 16; g  3, 16;     g! 3, 16; d! 3, 16, 64; f! 3,  8, 32; c! 2, 32
      g! 2, 16, 64; c! 3, 16; e  3, 16;     d! 3, 16; c! 3, 16, 64; b  3,  8;     f! 2, 16
      c! 3, 16;     f! 3, 16; f  3, 16;     f! 3, 16; d  3, 16;     c! 3, 16, 64; b  3, 16; e  2, 16
      b  3, 16;     e  3, 16; d! 3, 16, 64; e  3, 16; c! 3, 16;     b  3, 16;     a  3, 16, 64; d  2, 16
      a  3, 16;     d  3, 16; a  3, 16, 64; e  2, 16; b  3, 16;     e  3, 16;     d  3, 16, 64; a  3, 16; e  3, 16
      a  4, 16;     g! 3, 16; a  4, 16;     c! 3, 16, 64; e  3, 8;  a  3, 16;
    end

    ch_b do
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

    ch_c do
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
  end # rpt

  all_ch do
    ve :env_vol_silent_slow2
    w 256
  end

  envelope :env_vol_piano1      , [6, -0.2], [10, -0.3], :loop, [6, 0.2], [6, -0.2]
  envelope :env_vol_piano2      , [3, 0.5], [12, -0.6], :loop, [6, 0.2], [6, -0.2]
  envelope :env_vol_silent_slow2, [255, -1.0]

  instrument :instr1_normal do
    v 13; ve :env_vol_piano1
  end

  instrument :instr1_quiet do
    v 11; ve :env_vol_piano1
  end

  instrument :instr3_normal do
    ve :env_vol_piano2; vo; w 5; vg 0; va 0.4; vs 30
  end

end # Music4


if __FILE__ == $0
  require 'z80'

  music = Music4.new
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

require 'zxutils/music_box'

class Music2
  include ZXUtils::MusicBox::Song

  tempo 10

  ch_a do
    n0
    rpt 2 do
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
  end

  ch_b do
    n0
    w 640
    rpt 3 do
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
  end

  # https://goo.gl/gV3nGg
  # https://goo.gl/tD8diu
  # https://goo.gl/wzMwRN

  ch_c do
    t0; n1
    w 782
    n 1; v 15; mn :mask_noise_thrrr; w 40; mno; v 0
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

    rpt 2 do
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
    rpt 4 do
      i :perc1; 
      c 1; w tempo; c 1; w tempo;
      i :hihat1;
      c 1; w tempo; c 1; w tempo;
    end
  end

  mark :part_2

  ch_a do
    n1; np 1; a 6; tp -3*12, 50;
    envd 1; envs 8; vv; a 3
    w 50
    envd 2; tp 3*12, 50; a 6
    w 50
    v 0; fv
  end

  ch_b do
    t1; n 31; v 15; np 1; a 6; tp -6*12, 100; a 0; ne :noise_env1; w 40
    ve :env1_slowdown; w 60; veo
    n0; t0; v 0
  end

  ch_c do
    n0; v 15; np 1; a 4; vs 80; va 1.0; tp -3, 100; w 40
    g 3; va 1.0; ve :env1_slowdown; w 60; veo
    t0; v 0
  end

  chord    :chord_octave1 , [2, 0], [2, 12], :loop, [1, 0], [1, 12]
  chord    :chord_note8 , [2, 0], [2, 8], :loop, [1, 0], [1, 8]
  mask     :mask_noise_thrrr , [8, 0b01010101], [8, 0b01010101]
  mask     :mask_noise_thr2 , [8, 0b01001000], [8, 0b00000000]
  mask     :mask_noise_hihat , [8, 0b00000011], [8, 0b11001111], [8, 0b11110011], [8, 0b11111100], [8, 0b11111111]
  envelope :noise_env1 , [60, -1.0], :loop, [255, 0]
  envelope :env1_down , [2, 0], [7, -1.0], :loop, [255, 0]
  envelope :env1_simple , [10, -0.2], :loop, [100, -0.5]
  envelope :env1_slowdown , [100, -1.0], :loop, [255, 0]

  instrument :perc1 do
    n 20; v 12; ve :env1_down; mn :mask_noise_thr2
    w tempo; veo; mno
  end

  instrument :hihat1 do
    n 1; v 12; w tempo - 1; v 0
  end

  instrument :bass1 do
    t1; vs 30; va 0.2; w tempo - 1; vo; t0
    # v 15; vs 30; va 0.2; w tempo - 1; vo; v 0
  end

  instrument :bass3 do
    t1; vs 30; va 0.2; w tempo*3 - 1; vo; t0
    # v 15; vs 30; va 0.2; w tempo*3 - 1; vo; v 0
  end

  instrument :instrument1 do
    v 15; ve :env1_simple; w tempo - 1; veo; v 0
  end

  instrument :instrument2 do
    v 15; ve :env1_simple; w tempo; vs 50; va 0.4; w tempo - 1; vo; veo; v 0
  end

  instrument :instrument3 do
    v 15; ve :env1_simple; ce :chord_octave1; w tempo - 1; ceo; veo; v 0
  end

  instrument :instrument4 do
    v 15; ve :env1_simple; ce :chord_note8; w tempo - 1; ceo; veo; v 0
  end

  instrument :instrument5 do
    v 15; ve :env1_simple; vs 64; va 0.3; w tempo*2; vo; veo; v 0
  end
end


if __FILE__ == $0
  require 'z80'

  music = Music2.new
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

require 'zxutils/music_box'

class Music1
  include ZXUtils::MusicBox::Song

  tempo 12

  ch_a do
    # t0; n1;
    # sub :clap1
    n 31
    ne :noienv_wave
    v 8; n0; i :instrument1; vs 30
    # np 1; a 2; np 3
    m :mloop
    rpt 2 do
      a 2; w tempo
      c 3; w tempo
      d 3; w tempo
      c 3; w tempo
      e 3; w tempo
      c 3; w tempo
      d 3; w tempo
      c 3; w tempo
    end

    rpt 2 do
      b 2; w tempo
      d 3; w tempo
      e 3; w tempo
      d 3; w tempo
      f 3; w tempo
      d 3; w tempo
      e 3; w tempo
      c 3; w tempo
    end

    rpt 2 do
      c  2; w tempo
      e_ 3; w tempo
      f  3; w tempo
      e_ 3; w tempo
      g  3; w tempo
      e_ 3; w tempo
      f  3; w tempo
      e_ 3; w tempo
    end

    rpt 2 do
      d! 2; w tempo
      g  3; w tempo
      a  4; w tempo
      g  3; w tempo
      a! 4; w tempo
      g  3; w tempo
      a  4; w tempo
      g  3; w tempo
    end

    rpt 2 do
      d 2; w tempo
      f 3; w tempo
      g 3; w tempo
      f 3; w tempo
      a 4; w tempo
      f 3; w tempo
      g 3; w tempo
      f 3; w tempo
    end

    rpt 2 do
      e  2; w tempo
      g  3; w tempo
      a  4; w tempo
      g  3; w tempo
      b  4; w tempo
      g  3; w tempo
      a  4; w tempo
      g  3; w tempo
    end

    rpt 2 do
      f! 2; w tempo
      a  4; w tempo
      b  4; w tempo
      a  4; w tempo
      c! 4; w tempo
      a  4; w tempo
      b  4; w tempo
      a  4; w tempo
    end

    rpt 2 do
      f  2; w tempo
      a  4; w tempo
      b  4; w tempo
      a  4; w tempo
      c  4; w tempo
      a  4; w tempo
      b  4; w tempo
      a  4; w tempo
    end
    lt :mloop
  end

  ch_b do
    n0; i :instrument2
    v 0
    vs 10; np 1
    m :bloop
    d 1; w tempo*16 - 10
    c 1; w tempo*16
    e 1; w tempo*16; np 20
    g 0; w tempo*16; np 1
    f 1; w tempo*16
    b 0; w tempo*16; np 20
    c! 1; w tempo*16; np 1
    c 1; w tempo*16 + 10
    lt :bloop
  end

  # https://goo.gl/gV3nGg
  # https://goo.gl/tD8diu https://goo.gl/wzMwRN

  ch_c do
    n0; v 4
    m :cloop
    i :instrument3_major1
    c 4; w tempo*8; a 4; w tempo*8
    d 4; w tempo*8; b 4; w tempo*8
    i :instrument3_minor1
    e_ 4; w tempo*8; c 4; w tempo*8
    g 4; w tempo*8; d! 4; w tempo*8
    i :instrument3_7_maj
    f 4; w tempo*8; d 4; w tempo*8
    g 4; w tempo*8; e 4; w tempo*8
    i :instrument3_7_min
    a 4; w tempo*8; f! 4; w tempo*8
    i :instrument3_7
    a 4; w tempo*8; f 4; w tempo*8
    lt :cloop
  end

  envelope :volenv_clap1        , [2, 0.999], [2, -0.999], [4, 0], [1, 0.499], [1, -0.5], [15-10, 0]
  envelope :volenv_down1        , [50, -1]
  envelope :volenv_bass1        , [5, 1.0], [100, -0.5], :loop, [255, -0.5]
  envelope :volenv_chord1       , [50, 0.6], [50, -0.5], :loop, [50, 0]
  envelope :noienv_wave         , [100, -1], [100, 1]
  chord    :chord_data_major1   , [2, 0], [1, 4], [1, 7]
  chord    :chord_data_minor1   , [2, 0], [1, 3], [1, 7]
  chord    :chord_data_minor_d1 , [2, 0], [1, 3], [1, 6]
  chord    :chord_data_7        , [1, 0], [1, 4], [1, 7], [1, 10]
  chord    :chord_data_7_min    , [1, 0], [1, 3], [1, 7], [1, 10]
  chord    :chord_data_7_maj    , [1, 0], [1, 4], [1, 7], [1, 11]
  mask     :mask_noise_cha      , [8, 0b01111110], [8, 0b11011011], :loop, [128, 0b01010101]

  instrument :instrument1 do
    mn :mask_noise_cha
    va 0.4
    v 14
    ve :volenv_down1
  end

  instrument :instrument2 do
    ve :volenv_bass1; vo; w 20; vg 0; va 0.3
  end

  instrument :instrument3_major1 do
    ve :volenv_chord1; ce :chord_data_major1
  end
  instrument :instrument3_minor1 do
    ve :volenv_chord1; ce :chord_data_minor1
  end
  instrument :instrument3_7 do
    ve :volenv_chord1; ce :chord_data_7
  end
  instrument :instrument3_7_min do
    ve :volenv_chord1; ce :chord_data_7_min
  end
  instrument :instrument3_7_maj do
    ve :volenv_chord1; ce :chord_data_7_maj
  end

end #Music1


if __FILE__ == $0
  require 'z80'

  music = Music1.new
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

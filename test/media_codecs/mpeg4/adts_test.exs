defmodule MediaCodecs.MPEGG4.ADTSTest do
  use ExUnit.Case, async: true

  alias MediaCodecs.MPEG4.ADTS

  describe "ADTS serialize/1" do
    test "serialize one frame" do
      adts = %ADTS{
        audio_object_type: 2,
        channels: 2,
        sampling_frequency: 44100,
        frames: <<1, 2, 3, 4, 5>>
      }

      assert ADTS.serialize(adts) == <<255, 241, 80, 128, 1, 159, 252, 1, 2, 3, 4, 5>>
    end

    test "serialize multiple frames" do
      frames = [<<1, 2, 3, 4, 5>>, <<6, 7>>, <<8, 9, 10>>]

      adts = %ADTS{
        audio_object_type: 2,
        channels: 8,
        sampling_frequency: 11025,
        frames_count: 3,
        frames: Enum.join(frames)
      }

      assert ADTS.serialize(adts) ==
               <<255, 241, 105, 192, 2, 63, 254, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10>>
    end
  end

  describe "ADTS parse/1" do
    test "parse a complete packet" do
      assert {:ok, packet, <<>>} = ADTS.parse(<<255, 241, 80, 128, 1, 159, 252, 1, 2, 3, 4, 5>>)

      assert %ADTS{
               audio_object_type: 2,
               channels: 2,
               sampling_frequency: 44100,
               frames_count: 1,
               frames: <<1, 2, 3, 4, 5>>
             } = packet

      assert {:ok, _packet, <<255, 241, 80>>} =
               ADTS.parse(<<255, 241, 80, 128, 1, 159, 252, 1, 2, 3, 4, 5, 255, 241, 80>>)
    end

    test "parse a complete packet with multiple packets" do
      assert {:ok, packet, <<>>} =
               ADTS.parse(<<255, 241, 105, 192, 2, 63, 254, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10>>)

      assert %ADTS{
               audio_object_type: 2,
               channels: 8,
               sampling_frequency: 11025,
               frames_count: 3,
               frames: <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10>>
             } = packet
    end

    test "need more data" do
      assert :more = ADTS.parse(<<255, 241, 80, 128, 1>>)
      assert :more = ADTS.parse(<<255, 241, 80, 128, 1, 159, 252, 1, 2, 3, 4>>)
    end

    test "invalid packet" do
      assert {:error, :invalid_packet} = ADTS.parse(<<254, 241, 80, 128, 1, 159, 252>>)
    end
  end
end

defmodule MediaCodecs.MPEG4.AudioSpecificConfigTest do
  use ExUnit.Case, async: true

  alias MediaCodecs.MPEG4.AudioSpecificConfig

  describe "parse" do
    test "Parse audio specific config" do
      assert %AudioSpecificConfig{
               object_type: 2,
               sampling_frequency: 44100,
               channels: 2,
               aot_specific_config: <<0::3>>
             } == AudioSpecificConfig.parse(<<18, 16>>)
    end

    test "Parse asc with custom sample rate" do
      assert %AudioSpecificConfig{
               object_type: 0,
               sampling_frequency: 8000,
               channels: 1,
               aot_specific_config: <<0::3>>
             } == AudioSpecificConfig.parse(<<7, 128, 15, 160, 8>>)
    end
  end

  describe "serialize" do
    test "Serializes audio specific config" do
      asc = %AudioSpecificConfig{
        object_type: 2,
        sampling_frequency: 44100,
        channels: 2,
        aot_specific_config: <<0::3>>
      }

      assert AudioSpecificConfig.serialize(asc) == <<18, 16>>
    end

    test "Serializes asc with custom sample rate" do
      asc = %AudioSpecificConfig{
        object_type: 0,
        sampling_frequency: 17000,
        channels: 1,
        aot_specific_config: <<0::3>>
      }

      assert AudioSpecificConfig.serialize(asc) == <<7, 128, 33, 52, 8>>
    end
  end
end

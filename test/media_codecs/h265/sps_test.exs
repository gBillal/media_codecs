defmodule MediaCodecs.H265.SPSTest do
  use ExUnit.Case, async: true

  alias MediaCodecs.H265.NALU.SPS

  describe "SPS parsing" do
    test "parses a valid SPS NAL unit" do
      sps_data =
        <<0x42, 0x00, 0x01, 0x01, 0x60, 0x00, 0x00, 0x03, 0x00, 0x90, 0x00, 0x00, 0x03, 0x00,
          0x00, 0x03, 0x00, 0x78, 0xA0, 0x03, 0xC0, 0x80, 0x10, 0xE5, 0x96, 0x66, 0x69, 0x24,
          0xCA, 0xE0, 0x10, 0x00, 0x00, 0x03, 0x00, 0x10, 0x00, 0x00, 0x03, 0x01, 0xE0, 0x80>>

      sps = SPS.parse(sps_data)

      assert %SPS{
               video_parameter_set_id: 0,
               max_sub_layers_minus1: 0,
               temporal_id_nesting_flag: 1,
               profile_space: 0,
               tier_flag: 0,
               profile_idc: 1,
               profile_compatibility_flag: 1_610_612_736,
               progressive_source_flag: 1,
               interlaced_source_flag: 0,
               non_packed_constraint_flag: 0,
               frame_only_constraint_flag: 1,
               level_idc: 120,
               seq_parameter_set_id: 0,
               chroma_format_idc: 1,
               pic_width_in_luma_samples: 1920,
               pic_height_in_luma_samples: 1080,
               conformance_window: nil,
               bit_depth_luma_minus8: 2,
               bit_depth_chroma_minus8: 4
             } = sps

      assert SPS.width(sps) == 1920
      assert SPS.height(sps) == 1080
      assert SPS.profile(sps) == :main
      assert SPS.mime_type(sps, "hvc1") == "hvc1.1.6.L120.B0"
    end
  end
end

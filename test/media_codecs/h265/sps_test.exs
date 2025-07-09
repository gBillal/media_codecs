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
               profile_tier_level: %SPS.ProfileTierLevel{
                 profile_space: 0,
                 tier_flag: 0,
                 profile_idc: 1,
                 profile_compatibility_flag: 1_610_612_736,
                 progressive_source_flag: 1,
                 interlaced_source_flag: 0,
                 non_packed_constraint_flag: 0,
                 frame_only_constraint_flag: 1,
                 level_idc: 120
               },
               seq_parameter_set_id: 0,
               chroma_format_idc: 1,
               pic_width_in_luma_samples: 1920,
               pic_height_in_luma_samples: 1080,
               conformance_window: nil,
               bit_depth_luma_minus8: 2,
               bit_depth_chroma_minus8: 4
             } = sps

      assert SPS.id(sps_data) == 0
      assert SPS.width(sps) == 1920
      assert SPS.height(sps) == 1080
      assert SPS.profile(sps) == :main
      assert SPS.mime_type(sps, "hvc1") == "hvc1.1.6.L120.B0"
    end

    test "parses sps with max_sub_layers_minus1 > 0" do
      sps_data =
        <<66, 1, 3, 1, 96, 0, 0, 3, 0, 128, 0, 0, 3, 0, 0, 3, 0, 150, 0, 0, 160, 1, 224, 32, 2,
          28, 127, 141, 189, 247, 106, 110, 238, 75, 246, 2, 220, 4, 4, 4, 16, 0, 0, 62, 128, 0,
          2, 238, 7, 33, 222, 229, 16, 3, 211, 128, 1, 19, 156, 0, 122, 112, 0, 34, 115, 132, 0,
          244, 224, 0, 68, 231, 0, 30, 156, 0, 8, 156, 226>>

      sps = SPS.parse(sps_data)

      assert %SPS{
               video_parameter_set_id: 0,
               max_sub_layers_minus1: 1,
               temporal_id_nesting_flag: 1,
               profile_tier_level: %SPS.ProfileTierLevel{
                 profile_space: 0,
                 tier_flag: 0,
                 profile_idc: 1,
                 profile_compatibility_flag: 1_610_612_736,
                 progressive_source_flag: 1,
                 interlaced_source_flag: 0,
                 non_packed_constraint_flag: 0,
                 frame_only_constraint_flag: 0,
                 level_idc: 150
               },
               seq_parameter_set_id: 0,
               chroma_format_idc: 1,
               separate_colour_plane_flag: 0,
               pic_width_in_luma_samples: 3840,
               pic_height_in_luma_samples: 2160,
               conformance_window: [0, 0, 0, 0],
               bit_depth_luma_minus8: 0,
               bit_depth_chroma_minus8: 0,
               log2_max_pic_order_cnt_lsb_minus4: 12,
               sub_layer_ordering_info_present_flag: 1,
               max_dec_pic_buffering_minus1: [2, 2],
               max_num_reorder_pics: [0, 0],
               max_latency_increase_plus1: [0, 0],
               log2_min_luma_coding_block_size_minus3: 0,
               log2_diff_max_min_luma_coding_block_size: 2
             } = sps

      assert SPS.id(sps_data) == 0
    end

    test "parses a valid sps with conformance window" do
      sps_data =
        <<66, 1, 1, 1, 96, 0, 0, 3, 0, 144, 0, 0, 3, 0, 0, 3, 0, 30, 160, 52, 129, 7, 36, 153,
          101, 102, 185, 50, 191, 252, 7, 64, 6, 229, 160, 32, 0, 0, 3, 0, 32, 0, 0, 3, 3, 193>>

      sps = SPS.parse(sps_data)

      assert %SPS{
               video_parameter_set_id: 0,
               max_sub_layers_minus1: 0,
               temporal_id_nesting_flag: 1,
               profile_tier_level: %SPS.ProfileTierLevel{
                 profile_space: 0,
                 tier_flag: 0,
                 profile_idc: 1,
                 profile_compatibility_flag: 1_610_612_736,
                 progressive_source_flag: 1,
                 interlaced_source_flag: 0,
                 non_packed_constraint_flag: 0,
                 frame_only_constraint_flag: 1,
                 level_idc: 30
               },
               seq_parameter_set_id: 0,
               chroma_format_idc: 1,
               separate_colour_plane_flag: 0,
               pic_width_in_luma_samples: 104,
               pic_height_in_luma_samples: 64,
               conformance_window: [0, 3, 0, 3],
               bit_depth_luma_minus8: 0,
               bit_depth_chroma_minus8: 0,
               log2_max_pic_order_cnt_lsb_minus4: 4,
               sub_layer_ordering_info_present_flag: 1,
               max_dec_pic_buffering_minus1: [4],
               max_num_reorder_pics: [2],
               max_latency_increase_plus1: [5],
               log2_min_luma_coding_block_size_minus3: 0,
               log2_diff_max_min_luma_coding_block_size: 2
             } = sps

      assert SPS.width(sps) == 98
      assert SPS.height(sps) == 58
    end
  end
end

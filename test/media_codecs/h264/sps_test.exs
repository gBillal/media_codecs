defmodule MediaCodecs.H264.SPSTest do
  use ExUnit.Case, async: true

  alias MediaCodecs.H264.NALU.SPS

  describe "SPS parsing" do
    test "parses a valid SPS NAL unit" do
      sps_data =
        <<0x66, 0x64, 0x00, 0x1F, 0xAC, 0xD9, 0x40, 0x50, 0x05, 0xBB, 0x01, 0x6C, 0x80, 0x00,
          0x00, 0x03, 0x00, 0x80, 0x00, 0x00, 0x1E, 0x07, 0x8C, 0x18, 0xCB>>

      sps = SPS.parse(sps_data)

      assert %SPS{
               seq_parameter_set_id: 0,
               profile_idc: 100,
               level_idc: 31,
               chroma_format_idc: 1,
               separate_colour_plane_flag: 0,
               log2_max_pic_order_cnt_lsb_minus4: 2,
               bit_depth_luma_minus8: 0,
               bit_depth_chroma_minus8: 0,
               qpprime_y_zero_transform_bypass_flag: 0,
               pic_order_cnt_type: 0,
               pic_width_in_mbs_minus1: 79,
               pic_height_in_map_units_minus1: 44,
               direct_8x8_inference_flag: 1
             } = sps

      assert SPS.id(sps_data) == 0
      assert SPS.width(sps) == 1280
      assert SPS.height(sps) == 720
      assert SPS.profile(sps) == :high
      assert SPS.mime_type(sps, "avc1") == "avc1.64001F"
    end

    test "sps with scaling list" do
      sps_data =
        <<102, 100, 0, 50, 173, 132, 1, 12, 32, 8, 97, 0, 67, 8, 2, 24, 64, 16, 194, 0, 132, 59,
          80, 20, 0, 90, 211, 112, 16, 16, 20, 0, 0, 3, 0, 4, 0, 0, 3, 0, 162, 16>>

      sps = SPS.parse(sps_data)

      assert %SPS{
               seq_parameter_set_id: 0,
               profile_idc: 100,
               level_idc: 50,
               chroma_format_idc: 1,
               scaling_list: [
                 [
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16
                 ],
                 [
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16
                 ],
                 [
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16
                 ],
                 [
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16
                 ],
                 [
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16
                 ],
                 [
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16,
                   16
                 ]
               ]
             } = sps

      assert SPS.mime_type(sps, "avc1") == "avc1.640032"
    end

    test "sps with frame cropping" do
      sps_data =
        <<0x66, 0x42, 0xC0, 0x28, 0xD9, 0x00, 0x78, 0x02, 0x27, 0xE5, 0x84, 0x00, 0x00, 0x03,
          0x00, 0x04, 0x00, 0x00, 0x03, 0x00, 0xF0, 0x3C, 0x60, 0xC9, 0x20>>

      sps = SPS.parse(sps_data)

      assert %SPS{
               seq_parameter_set_id: 0,
               profile_idc: 66,
               level_idc: 40,
               chroma_format_idc: 1,
               frame_crop_offset: %{left: 0, right: 0, top: 0, bottom: 4}
             } = sps

      assert SPS.width(sps) == 1920
      assert SPS.height(sps) == 1080
      assert SPS.profile(sps) == :constrained_baseline
      assert SPS.mime_type(sps, "avc1") == "avc1.42C028"
    end
  end
end

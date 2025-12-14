defmodule MediaCodecs.AV1.SequenceHeaderTest do
  use ExUnit.Case, async: true

  alias MediaCodecs.AV1.OBU.SequenceHeader

  doctest SequenceHeader

  test "Parse a sequence header OBU" do
    assert sequence_header =
             SequenceHeader.parse(<<0, 0, 0, 66, 167, 191, 230, 46, 223, 200, 66>>)

    assert %SequenceHeader{
             seq_profile: 0,
             still_picture: false,
             reduced_still_picture_header: false,
             timing_info: nil,
             operating_points: %{
               0 => %{
                 operating_parameters_info: nil,
                 operating_point_idc: 0,
                 seq_level_idx: 8,
                 seq_tier: 0,
                 initial_display_delay_minus_1: 0
               }
             },
             decoder_model_info: nil,
             max_frame_width_minus_1: 1919,
             max_frame_height_minus_1: 817,
             delta_frame_id_length_minus_2: 0,
             additional_frame_id_length_minus_1: 0,
             use_128x128_superblock: true,
             enable_filter_intra: true,
             enable_intra_edge_filter: true,
             color_config: %{
               high_bitdepth: false,
               bitdepth: 8,
               monochrome: false,
               subsampling_x: 1,
               subsampling_y: 1
             },
             initial_display_delay_present_flag: false,
             operating_points_cnt_minus_1: 0
           } = sequence_header

    assert SequenceHeader.width(sequence_header) == 1920
    assert SequenceHeader.height(sequence_header) == 818
    assert SequenceHeader.mime_type(sequence_header) == "av01.0.08M.08"
  end
end

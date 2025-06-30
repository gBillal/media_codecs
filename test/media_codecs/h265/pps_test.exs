defmodule MediaCodecs.H265.PPSTest do
  use ExUnit.Case, async: true

  alias MediaCodecs.H265.PPS

  test "parses PPS NAL unit" do
    assert %PPS{
             pic_parameter_set_id: 0,
             seq_parameter_set_id: 0,
             dependent_slice_segments_enabled_flag: 0,
             output_flag_present_flag: 0,
             num_extra_slice_header_bits: 0
           } = PPS.parse(<<0x44, 0x00, 0xC1, 0x72, 0xB4, 0x62, 0x40>>)
  end
end

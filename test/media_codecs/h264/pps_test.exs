defmodule MediaCodecs.H264.PPSTest do
  use ExUnit.Case, async: true

  alias MediaCodecs.H264.PPS

  test "parses PPS NAL unit" do
    assert %PPS{
             pic_parameter_set_id: 0,
             seq_parameter_set_id: 0,
             entropy_coding_mode_flag: 1,
             bottom_field_pic_order_in_frame_present_flag: 0
           } = PPS.parse(<<103, 238, 56, 128>>)
  end
end

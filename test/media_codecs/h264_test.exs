defmodule MediaCodecs.H264Test do
  use ExUnit.Case, async: true

  alias MediaCodecs.H264

  @test_fixture "test/fixtures/sample.h264"

  test "Split an access unit to a list of NALu" do
    nalus = File.read!(@test_fixture) |> H264.nalus()

    assert is_list(nalus)
    assert length(nalus) == 4
  end

  test "Get nalu types" do
    assert [:sps, :pps, :sei, :idr] ==
             File.read!(@test_fixture) |> H264.nalus() |> Enum.map(&H264.nalu_type/1)
  end

  test "Pop parameter sets" do
    assert {{[sps], [pps]}, access_unit} = File.read!(@test_fixture) |> H264.pop_parameter_sets()

    assert sps ==
             <<103, 100, 0, 12, 172, 217, 67, 196, 254, 255, 240, 1, 192, 1, 177, 0, 0, 3, 0, 1,
               0, 0, 3, 0, 60, 15, 20, 41, 150>>

    assert pps == <<104, 235, 227, 203, 34, 192>>

    assert is_list(access_unit)
    assert length(access_unit) == 2

    assert H264.nalu_type(sps) == :sps
    assert H264.nalu_type(pps) == :pps
  end
end

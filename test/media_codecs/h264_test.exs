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
    nalus = File.read!(@test_fixture) |> H264.nalus()
    assert [:sps, :pps, :sei, :idr] == Enum.map(nalus, &H264.NALU.type/1)
  end

  test "keyframe?/1" do
    nalus = File.read!(@test_fixture) |> H264.nalus()

    refute H264.NALU.keyframe?(hd(nalus))
    assert H264.NALU.keyframe?(List.last(nalus))
    refute H264.NALU.keyframe?(hd(nalus) |> H264.NALU.parse())
    assert H264.NALU.keyframe?(List.last(nalus) |> H264.NALU.parse())
  end

  test "vcl?/1" do
    nalus = File.read!(@test_fixture) |> H264.nalus()

    refute H264.NALU.vcl?(hd(nalus) |> H264.NALU.parse())
    assert H264.NALU.vcl?(List.last(nalus) |> H264.NALU.parse())
  end

  test "Pop parameter sets" do
    assert {{[sps], [pps]}, access_unit} = File.read!(@test_fixture) |> H264.pop_parameter_sets()

    assert sps ==
             <<103, 100, 0, 12, 172, 217, 67, 196, 254, 255, 240, 1, 192, 1, 177, 0, 0, 3, 0, 1,
               0, 0, 3, 0, 60, 15, 20, 41, 150>>

    assert pps == <<104, 235, 227, 203, 34, 192>>

    assert is_list(access_unit)
    assert length(access_unit) == 2

    assert H264.NALU.type(sps) == :sps
    assert H264.NALU.type(pps) == :pps
  end

  test "Convert Annex B to elemetary stream" do
    access_unit = File.read!(@test_fixture)
    expected_nalus = H264.nalus(access_unit)

    elementary_stream = H264.annexb_to_elementary_stream(access_unit, 2)
    assert elementary_stream == H264.annexb_to_elementary_stream(expected_nalus, 2)

    nalus = for <<size::16, nalu::binary-size(size) <- elementary_stream>>, do: nalu
    assert nalus == expected_nalus
  end
end

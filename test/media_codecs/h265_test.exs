defmodule MediaCodecs.H265Test do
  use ExUnit.Case, async: true

  alias MediaCodecs.H265

  @test_fixture "test/fixtures/sample.h265"

  test "Split an access unit to a list of NALu" do
    nalus = File.read!(@test_fixture) |> H265.nalus()

    assert is_list(nalus)
    assert length(nalus) == 5
  end

  test "Get nalu types" do
    assert [:vps, :sps, :pps, :prefix_sei, :idr_n_lp] ==
             File.read!(@test_fixture) |> H265.nalus() |> Enum.map(&H265.NALU.type/1)
  end

  test "Pop parameter sets" do
    assert {{[vps], [sps], [pps]}, access_unit} =
             File.read!(@test_fixture) |> H265.pop_parameter_sets()

    assert vps ==
             <<64, 1, 12, 1, 255, 255, 1, 96, 0, 0, 3, 0, 144, 0, 0, 3, 0, 0, 3, 0, 60, 149, 152,
               9>>

    assert sps ==
             <<66, 1, 1, 1, 96, 0, 0, 3, 0, 144, 0, 0, 3, 0, 0, 3, 0, 60, 160, 30, 32, 36, 125,
               229, 149, 154, 73, 50, 191, 252, 0, 112, 0, 109, 160, 32, 0, 0, 3, 0, 32, 0, 0, 3,
               3, 193>>

    assert pps == <<68, 1, 193, 114, 180, 98, 64>>

    assert is_list(access_unit)
    assert length(access_unit) == 2

    assert H265.NALU.type(vps) == :vps
    assert H265.NALU.type(sps) == :sps
    assert H265.NALU.type(pps) == :pps
  end

  test "Convert Annex B to elementary stream" do
    access_unit = File.read!(@test_fixture)
    expected_nalus = H265.nalus(access_unit)

    elementary_stream = H265.annexb_to_elementary_stream(access_unit, 2)
    assert elementary_stream == H265.annexb_to_elementary_stream(expected_nalus, 2)

    nalus = for <<size::16, nalu::binary-size(size) <- elementary_stream>>, do: nalu
    assert nalus == expected_nalus
  end
end

defmodule MediaCodecs.AV1Test do
  use ExUnit.Case, async: true

  alias MediaCodecs.AV1

  doctest MediaCodecs.AV1.OBU
  doctest MediaCodecs.AV1.OBU.Header

  test "Split a stream into OBUs" do
    stream = File.read!("./test/fixtures/av1/temporal_unit.av1")
    assert obus = AV1.obus(stream)
    assert length(obus) == 3

    for obu_data <- obus do
      assert {:ok, %AV1.OBU{header: %{type: type}}} = AV1.OBU.parse(obu_data)
      assert type in [:temporal_delimiter, :sequence_header, :frame]
    end

    assert IO.iodata_to_binary(obus) == stream
  end
end

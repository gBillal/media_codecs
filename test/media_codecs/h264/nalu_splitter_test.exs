defmodule MediaCodecs.H264.NaluSplitterTest do
  use ExUnit.Case

  alias MediaCodecs.H264.NaluSplitter

  @test_fixture "test/fixtures/sample.h264"

  test "parse annexb stream" do
    nalus =
      @test_fixture
      |> File.stream!([], 37)
      |> Stream.transform(
        fn -> NaluSplitter.new() end,
        &NaluSplitter.process/2,
        &{NaluSplitter.flush(&1) |> List.wrap(), &1},
        &Function.identity/1
      )
      |> Enum.to_list()

    assert length(nalus) == 4
    assert MediaCodecs.H264.nalus(File.read!(@test_fixture)) == nalus
  end

  test "parse elementary stream" do
    data = File.read!(@test_fixture) |> MediaCodecs.H264.annexb_to_elementary_stream(2)

    nalus =
      data
      |> :binary.bin_to_list()
      |> Enum.chunk_every(100)
      |> Enum.map(&:binary.list_to_bin/1)
      |> Stream.transform(
        fn -> NaluSplitter.new({:elementary, 2}) end,
        &NaluSplitter.process/2,
        &{NaluSplitter.flush(&1) |> List.wrap(), &1},
        &Function.identity/1
      )
      |> Enum.to_list()

    assert length(nalus) == 4
    assert MediaCodecs.H264.nalus(File.read!(@test_fixture)) == nalus
  end
end

defmodule MediaCodecs.H265.NaluSplitterTest do
  use ExUnit.Case

  alias MediaCodecs.H265.NaluSplitter

  @test_fixture "test/fixtures/sample.h265"

  test "parse annexb stream" do
    nalus =
      @test_fixture
      |> File.stream!([], 100)
      |> Stream.transform(
        fn -> NaluSplitter.new() end,
        &NaluSplitter.process(&2, &1),
        &{NaluSplitter.flush(&1) |> List.wrap(), &1},
        &Function.identity/1
      )
      |> Enum.to_list()

    assert length(nalus) == 5
    assert MediaCodecs.H264.nalus(File.read!(@test_fixture)) == nalus
  end

  test "parse elementary stream" do
    data = File.read!(@test_fixture) |> MediaCodecs.H265.annexb_to_elementary_stream(2)

    nalus =
      data
      |> :binary.bin_to_list()
      |> Enum.chunk_every(100)
      |> Enum.map(&:binary.list_to_bin/1)
      |> Stream.transform(
        fn -> NaluSplitter.new({:elementary, 2}) end,
        &NaluSplitter.process(&2, &1),
        &{NaluSplitter.flush(&1) |> List.wrap(), &1},
        &Function.identity/1
      )
      |> Enum.to_list()

    assert length(nalus) == 5
    assert MediaCodecs.H265.nalus(File.read!(@test_fixture)) == nalus
  end
end

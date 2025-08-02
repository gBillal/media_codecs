defmodule MediaCodecs.H264.AccessUnitSplitterTest do
  use ExUnit.Case, async: true

  alias ExUnit.CaptureLog
  alias MediaCodecs.H264.{AccessUnitSplitter, NaluSplitter}

  @test_files_names ["10-720a", "10-720p"]

  @au_lengths_snapshot %{
    "10-720a" => [779, 146, 94, 136],
    "10-720p" => [25_701, 19_044, 14_380, 14_282, 14_762, 18_703, 14_736, 13_603, 12_095, 17_229]
  }

  test "split nalus into access units" do
    for name <- @test_files_names do
      path = "test/fixtures/h264/#{name}.h264"

      access_units =
        path
        |> File.stream!(1024)
        |> Stream.transform(
          fn -> NaluSplitter.new() end,
          &NaluSplitter.process/2,
          &{NaluSplitter.flush(&1), &1},
          fn _acc -> :ok end
        )
        |> Stream.transform(
          fn -> AccessUnitSplitter.new() end,
          fn nalu, splitter ->
            case AccessUnitSplitter.process(nalu, splitter) do
              {nil, splitter} -> {[], splitter}
              {au, splitter} -> {[au], splitter}
            end
          end,
          &{[AccessUnitSplitter.flush(&1)], &1},
          fn _acc -> :ok end
        )
        |> Enum.to_list()

      access_units =
        Enum.map(access_units, fn au -> Enum.map_join(au, &<<1::32, &1::binary>>) end)

      assert length(access_units) == length(@au_lengths_snapshot[name])
      assert Enum.map(access_units, &byte_size/1) == @au_lengths_snapshot[name]
    end
  end

  test "ignore invalid nalus" do
    splitter = AccessUnitSplitter.new()

    logs =
      CaptureLog.capture_log(fn ->
        assert {nil, splitter} = AccessUnitSplitter.process(<<64, 1, 1>>, splitter)
        assert {nil, _splitter} = AccessUnitSplitter.process(<<70, 1, 16>>, splitter)
      end)

    assert logs =~ "Invalid transition, ignore nal unit"

    logs =
      CaptureLog.capture_log(fn ->
        assert {nil, splitter} = AccessUnitSplitter.process(<<0, 1, 225>>, splitter)
        assert {nil, _splitter} = AccessUnitSplitter.process(<<30, 1, 79>>, splitter)
      end)

    assert logs =~ "Invalid transition, ignore nal unit"
  end
end

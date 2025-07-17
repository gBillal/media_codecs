defmodule MediaCodecs.H265.AccessUnitSplitterTest do
  use ExUnit.Case, async: true

  alias ExUnit.CaptureLog
  alias MediaCodecs.H265.{AccessUnitSplitter, NaluSplitter}

  @test_files_names ["10-1920x1080", "10-480x320-mainstillpicture"]

  # These values were obtained with the use of FFmpeg
  @au_lengths_ffmpeg %{
    "10-1920x1080" => [13_981, 9501, 6241, 4865, 4585, 6797, 5669, 4953, 4738, 5042],
    "10-480x320-mainstillpicture" => [
      35_114,
      8824,
      8790,
      8762,
      8757,
      8766,
      8731,
      8735,
      8699,
      8710
    ]
  }

  test "split nalus into access units" do
    for name <- @test_files_names do
      path = "test/fixtures/h265/#{name}.h265"

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

      assert length(access_units) == length(@au_lengths_ffmpeg[name])
      assert Enum.map(access_units, &byte_size/1) == @au_lengths_ffmpeg[name]
    end
  end

  test "ignore invalid nalus" do
    splitter = AccessUnitSplitter.new()

    logs = CaptureLog.capture_log(fn ->
      assert {nil, splitter} = AccessUnitSplitter.process(<<64, 1, 1>>, splitter)
      assert {nil, _splitter} = AccessUnitSplitter.process(<<70, 1, 16>>, splitter)
    end)

    assert logs =~ "Invalid transition, ignore nal unit"

    logs = CaptureLog.capture_log(fn ->
      assert {nil, splitter} = AccessUnitSplitter.process(<<0, 1, 225>>, splitter)
      assert {nil, _splitter} = AccessUnitSplitter.process(<<30, 1, 79>>, splitter)
    end)

    assert logs =~ "Invalid transition, ignore nal unit"
  end
end

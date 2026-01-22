defmodule MediaCodecs.H264 do
  @moduledoc """
  Utilities for working with H.264 (AVC) video codec.
  """
  alias MediaCodecs.H264.NALU
  alias MediaCodecs.H264.NaluSplitter
  alias MediaCodecs.H264.AccessUnitSplitter

  @type profile ::
          :high_cavlc_4_4_4_intra
          | :constrained_baseline
          | :baseline
          | :main
          | :extended
          | :constrained_high
          | :progressive_high
          | :high
          | :high_10_intra
          | :high_10
          | :high_4_2_2_intra
          | :high_4_2_2
          | :high_4_4_4_intra
          | :high_4_4_4_predictive

  @doc """
  Convert an access unit to a list of NALUs.
  """

  @spec parse(binary()) :: [AccessUnitSplitter.t()]
  def parse(access_units) do
    nalu_splinter = NaluSplitter.new(:annexb)
    access_unit_splitter = AccessUnitSplitter.new()

    {nalus, _splinter} =
      NaluSplitter.process(access_units, nalu_splinter)

    Enum.map(nalus, fn nalu ->
      AccessUnitSplitter.process(nalu, access_unit_splitter)
      |> case do
        {nil, splitter} ->
          splitter

        {access_unit, splitter} ->
          {access_unit, splitter}
      end
    end)
  end

  @spec nalus(binary()) :: [binary()]
  def nalus(access_unit) do
    :binary.split(access_unit, [<<1::32>>, <<1::24>>], [:global, :trim_all])
  end

  @doc """
  Pops parameter sets from access unit.
  """
  @spec pop_parameter_sets(access_unit :: binary() | [binary()]) ::
          {{sps :: [binary()], pps :: [binary()]}, access_unit :: [binary()]}
  def pop_parameter_sets(access_unit) do
    nalus =
      if is_binary(access_unit),
        do: nalus(access_unit),
        else: access_unit

    {{sps, pps}, au} =
      Enum.reduce(nalus, {{[], []}, []}, fn nalu, {{sps, pps}, au} ->
        case NALU.type(nalu) do
          :sps -> {{[nalu | sps], pps}, au}
          :pps -> {{sps, [nalu | pps]}, au}
          _other -> {{sps, pps}, [nalu | au]}
        end
      end)

    {{Enum.reverse(sps), Enum.reverse(pps)}, Enum.reverse(au)}
  end

  @doc """
  {{[
    <<103, 100, 0, 12, 172, 217, 67, 196, 254, 255, 240, 1, 192, 1, 177, 0, 0,
      3, 0, 1, 0, 0, 3, 0, 60, 15, 20, 41, 150>>
  ], [<<104, 235, 227, 203, 34, 192>>]},
  [
   <<6, 5, 255, 255, 170, 220, 69, 233, 189, 230, 217, 72, 183, 150, 44, 216,
     32, 217, 35, 238, 239, 120, 50, 54, 52, 32, 45, 32, 99, 111, 114, 101, 32,
     49, 53, 53, 32, 114, 50, 57, 49, 55, 32, 48, 97, 56, 52, ...>>,
   <<101, 136, 132, 0, 103, 58, 55, 34, 129, 77, 130, 17, 1, 145, 75, 240, 209,
     47, 252, 128, 26, 209, 166, 36, 239, 159, 71, 67, 181, 63, 115, 191, 113,
     122, 63, 218, 35, 57, 239, 72, 239, 22, 99, 180, 97, 8, ...>>
  ]}
  Convert an Annex B formatted access unit to an elementary stream.

  The NALU prefix size can be specified, defaulting to 4 bytes.
  """
  @spec annexb_to_elementary_stream(
          access_unit :: binary() | [binary()],
          nalu_prefix_size :: integer()
        ) :: binary()
  def annexb_to_elementary_stream(access_unit, nalu_prefix_size \\ 4)

  def annexb_to_elementary_stream(access_unit, nalu_prefix_size) when is_list(access_unit) do
    Enum.map_join(access_unit, &<<byte_size(&1)::integer-size(nalu_prefix_size * 8), &1::binary>>)
  end

  def annexb_to_elementary_stream(access_unit, nalu_prefix_size) do
    annexb_to_elementary_stream(nalus(access_unit), nalu_prefix_size)
  end
end

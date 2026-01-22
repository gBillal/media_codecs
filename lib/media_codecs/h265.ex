defmodule MediaCodecs.H265 do
  @moduledoc """
  Utilities for working with H.265 (HEVC) video codec.
  """

  alias MediaCodecs.H265.NALU
  alias MediaCodecs.H265.NaluSplitter
  alias MediaCodecs.H265.AccessUnitSplitter

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
      {_au, parser} = AccessUnitSplitter.process(nalu, access_unit_splitter)
      parser.access_unit
    end)
    |> List.flatten()
  end

  @spec nalus(access_unit :: binary()) :: [binary()]
  def nalus(access_unit) do
    :binary.split(access_unit, [<<1::32>>, <<1::24>>], [:global, :trim_all])
  end

  @doc """
  Pops parameter sets from access unit.
  """
  @spec pop_parameter_sets(binary()) ::
          {{vps :: [binary()], sps :: [binary()], pps :: [binary()]}, access_unit :: [binary()]}
  def pop_parameter_sets(access_unit) do
    nalus = if is_binary(access_unit), do: nalus(access_unit), else: access_unit

    {{vps, sps, pps}, au} =
      Enum.reduce(nalus, {{[], [], []}, []}, fn nalu, {{vps, sps, pps}, au} ->
        case NALU.type(nalu) do
          :vps -> {{[nalu | vps], sps, pps}, au}
          :sps -> {{vps, [nalu | sps], pps}, au}
          :pps -> {{vps, sps, [nalu | pps]}, au}
          _other -> {{vps, sps, pps}, [nalu | au]}
        end
      end)

    {{Enum.reverse(vps), Enum.reverse(sps), Enum.reverse(pps)}, Enum.reverse(au)}
  end

  @doc """
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

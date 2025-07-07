defmodule MediaCodecs.H264 do
  @moduledoc """
  Utilities for working with H.264 (AVC) video codec.
  """

  alias MediaCodecs.H264.NALU

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
    nalus = if is_binary(access_unit), do: nalus(access_unit), else: access_unit

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

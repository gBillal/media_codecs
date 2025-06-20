defmodule MediaCodecs.H264 do
  @moduledoc """
  Utilities for working with H.264 (AVC) video codec.
  """

  alias MediaCodecs.H264.{NALU, SPS}

  @type nalu_type ::
          :non_idr
          | :part_a
          | :part_b
          | :part_c
          | :idr
          | :sei
          | :sps
          | :pps
          | :aud
          | :end_of_seq
          | :end_of_stream
          | :filler_data
          | :sps_extension
          | :prefix_nal_unit
          | :subset_sps
          | :auxiliary_non_part
          | :extension
          | :reserved
          | :unspecified

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
  Gets NALu type.
  """
  @spec nalu_type(nalu :: binary()) :: nalu_type()
  def nalu_type(nalu) do
    {{_nal_ref_idc, type}, _nal_body} = header_and_body(nalu)
    type(type)
  end

  @doc """
  Parses a NALU bitstring and returns a NALU struct.
  """
  @spec parse_nalu(bitstring()) :: NALU.t()
  def parse_nalu(nalu) do
    {{nal_ref_idc, type}, nal_body} = header_and_body(nalu)

    case type(type) do
      :sps -> %NALU{type: :sps, nal_ref_idc: nal_ref_idc, content: SPS.parse(nal_body)}
      type -> %NALU{type: type, nal_ref_idc: nal_ref_idc, content: nil}
    end
  end

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
  @spec pop_parameter_sets(binary()) ::
          {{sps :: [binary()], pps :: [binary()]}, access_unit :: [binary()]}
  def pop_parameter_sets(access_unit) do
    {{sps, pps}, au} =
      access_unit
      |> nalus()
      |> Enum.reduce({{[], []}, []}, fn nalu, {{sps, pps}, au} ->
        case nalu_type(nalu) do
          :sps -> {{[nalu | sps], pps}, au}
          :pps -> {{sps, [nalu | pps]}, au}
          _other -> {{sps, pps}, [nalu | au]}
        end
      end)

    {{Enum.reverse(sps), Enum.reverse(pps)}, Enum.reverse(au)}
  end

  defp header_and_body(<<_::1, nal_ref_idc::2, type::5, nal_body::binary>>) do
    {{nal_ref_idc, type}, nal_body}
  end

  defp type(1), do: :non_idr
  defp type(2), do: :part_a
  defp type(3), do: :part_b
  defp type(4), do: :part_c
  defp type(5), do: :idr
  defp type(6), do: :sei
  defp type(7), do: :sps
  defp type(8), do: :pps
  defp type(9), do: :aud
  defp type(10), do: :end_of_seq
  defp type(11), do: :end_of_stream
  defp type(12), do: :filler_data
  defp type(13), do: :sps_extension
  defp type(14), do: :prefix_nal_unit
  defp type(15), do: :subset_sps
  defp type(19), do: :auxiliary_non_part
  defp type(20), do: :extension
  defp type(type) when type in 16..18 or type in 21..23, do: :reserved
  defp type(_type), do: :unspecified
end

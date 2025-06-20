defmodule MediaCodecs.H265 do
  @moduledoc """
  Utilities for working with H.265 (HEVC) video codec.
  """

  alias MediaCodecs.H265.{NALU, SPS}

  @type nalu_type ::
          :trail_n
          | :trail_r
          | :tsa_n
          | :tsa_r
          | :stsa_n
          | :stsa_r
          | :radl_n
          | :radl_r
          | :rasl_n
          | :rasl_r
          | :bla_w_lp
          | :bla_w_radl
          | :bla_n_lp
          | :idr_w_radl
          | :idr_n_lp
          | :cra
          | :aud
          | :eos
          | :eob
          | :fd
          | :prefix_sei
          | :suffix_sei
          | :reserved_irap
          | :reserved_nvcl
          | :unspecified

  @type nalu :: binary()

  @doc """
  Gets NALu type.
  """
  @spec nalu_type(nalu()) :: nalu_type()
  def nalu_type(nalu) do
    {{type, _, _}, _nal_body} = header_and_body(nalu)
    type(type)
  end

  @doc """
  Parses a NALU bitstring and returns a NALU struct.
  """
  @spec parse_nalu(nalu()) :: NALU.t()
  def parse_nalu(nalu) do
    {{type, nuh_layer_id, nuh_temporal_id_plus1}, nal_body} = header_and_body(nalu)
    type = type(type)

    nalu = %NALU{
      type: type,
      nuh_layer_id: nuh_layer_id,
      nuh_temporal_id_plus1: nuh_temporal_id_plus1
    }

    case type do
      :sps -> %{nalu | content: SPS.parse(nal_body)}
      _ -> nalu
    end
  end

  @doc """
  Convert an access unit to a list of NALUs.
  """
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
    {{vps, sps, pps}, au} =
      access_unit
      |> nalus()
      |> Enum.reduce({{[], [], []}, []}, fn nalu, {{vps, sps, pps}, au} ->
        case nalu_type(nalu) do
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

  defp header_and_body(<<_::1, type::6, nuh_layer_id::6, temporal_id::3, nal_body::binary>>) do
    {{type, nuh_layer_id, temporal_id}, nal_body}
  end

  defp type(0), do: :trail_n
  defp type(1), do: :trail_r
  defp type(2), do: :tsa_n
  defp type(3), do: :tsa_r
  defp type(4), do: :stsa_n
  defp type(5), do: :stsa_r
  defp type(6), do: :radl_n
  defp type(7), do: :radl_r
  defp type(8), do: :rasl_n
  defp type(9), do: :rasl_r
  defp type(16), do: :bla_w_lp
  defp type(17), do: :bla_w_radl
  defp type(18), do: :bla_n_lp
  defp type(19), do: :idr_w_radl
  defp type(20), do: :idr_n_lp
  defp type(21), do: :cra
  defp type(32), do: :vps
  defp type(33), do: :sps
  defp type(34), do: :pps
  defp type(35), do: :aud
  defp type(36), do: :eos
  defp type(37), do: :eob
  defp type(38), do: :fd
  defp type(39), do: :prefix_sei
  defp type(40), do: :suffix_sei
  defp type(t) when t in 10..15 or t in 24..31, do: :reserved_non_irap
  defp type(t) when t in 22..23, do: :reserved_irap
  defp type(t) when t in 41..47, do: :reserved_nvcl
  defp type(_type), do: :unspecified
end

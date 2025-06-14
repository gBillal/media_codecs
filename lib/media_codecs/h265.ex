defmodule MediaCodecs.H265 do
  @moduledoc """
  Utilities for working with H.265 (HEVC) video codec.
  """

  alias MediaCodecs.H265.{NALU, SPS}

  @type nalu_type :: :vps | :sps | :pps

  @doc """
  Gets NALu type.
  """
  @spec nalu_type(bitstring()) :: nalu_type()
  def nalu_type(<<_::1, 32::6, _rest::bitstring>>), do: :vps
  def nalu_type(<<_::1, 33::6, _rest::bitstring>>), do: :sps
  def nalu_type(<<_::1, 34::6, _rest::bitstring>>), do: :pps
  def nalu_type(<<_::1, _type::6, _rest::bitstring>>), do: :unknown

  @doc """
  Parses a NALU bitstring and returns a NALU struct.
  """
  @spec parse_nalu(bitstring()) :: NALU.t()
  def parse_nalu(nalu) do
    case nalu_type(nalu) do
      :sps -> %NALU{type: :sps, content: SPS.parse(nalu)}
      _ -> raise "Unsupported NALU type: #{inspect(nalu_type(nalu))}"
    end
  end

  @doc """
  Convert an access unit to a list of NALUs.
  """
  @spec nalus(binary()) :: [binary()]
  def nalus(access_unit) do
    :binary.split(access_unit, [<<1::32>>, <<1::24>>], [:global, :trim_all])
  end
end

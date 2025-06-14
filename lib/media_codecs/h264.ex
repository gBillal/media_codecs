defmodule MediaCodecs.H264 do
  @moduledoc """
  Utilities for working with H.264 (AVC) video codec.
  """

  alias MediaCodecs.H264.{NALU, SPS}

  @type nalu_type :: :sps | :pps

  @doc """
  Gets NALu type.
  """
  @spec nalu_type(bitstring()) :: nalu_type()
  def nalu_type(<<_::3, 7::5, _rest::bitstring>>), do: :sps
  def nalu_type(<<_::3, 8::5, _rest::bitstring>>), do: :pps
  def nalu_type(<<_::3, _type::5, _rest::bitstring>>), do: :unknown

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

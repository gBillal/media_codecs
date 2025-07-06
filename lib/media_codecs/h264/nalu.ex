defmodule MediaCodecs.H264.NALU do
  @moduledoc """
  Struct describing an h264 nalu.
  """

  alias __MODULE__.{PPS, Slice, SPS}

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

  @type t :: %__MODULE__{
          type: nalu_type(),
          nal_ref_idc: non_neg_integer(),
          content: struct() | nil
        }

  defstruct [:type, :nal_ref_idc, :content]

  @doc """
  Parses the NALU header.
  """
  @spec parse_header(nalu :: binary()) :: t()
  def parse_header(nalu) do
    {nal_ref_idc, type} = header(nalu)
    %__MODULE__{nal_ref_idc: nal_ref_idc, type: nalu_type(type)}
  end

  @doc """
  Parses a NALU bitstring and returns a NALU struct.

  An optional keyword can be provided to completely parse the NAL unit:
  - `:sps` - provide the parsed sps NAL unit. Needed for slice parsing.
  - `:pps` - provide the parsed pps NAL unit. Needed for slice parsing.
  """
  @spec parse(nalu :: binary(), Keyword.t()) :: t()
  def parse(nalu, opts \\ []) do
    {nal_ref_idc, type} = header(nalu)

    case nalu_type(type) do
      :sps ->
        %__MODULE__{type: :sps, nal_ref_idc: nal_ref_idc, content: SPS.parse(nalu)}

      :pps ->
        %__MODULE__{type: :pps, nal_ref_idc: nal_ref_idc, content: PPS.parse(nalu)}

      type when type in [:non_idr, :part_a, :part_b, :part_c, :idr] ->
        %__MODULE__{
          type: type,
          nal_ref_idc: nal_ref_idc,
          content: Slice.parse(nalu, opts[:sps], opts[:pps])
        }

      type ->
        %__MODULE__{type: type, nal_ref_idc: nal_ref_idc, content: nil}
    end
  end

  @doc """
  Gets the NALU type.
  """
  @spec type(nalu :: binary()) :: nalu_type()
  def type(<<_::3, type::5, _rest::binary>> = _nalu), do: nalu_type(type)

  @doc """
  Checks if the NALU is a keyframe (IDR).
  """
  @spec keyframe?(nalu :: binary() | t()) :: boolean()
  def keyframe?(%__MODULE__{type: :idr}), do: true
  def keyframe?(%__MODULE__{}), do: false
  def keyframe?(nalu), do: elem(header(nalu), 1) == 5

  defp header(<<_::1, nal_ref_idc::2, type::5, _nal_body::binary>>) do
    {nal_ref_idc, type}
  end

  defp nalu_type(1), do: :non_idr
  defp nalu_type(2), do: :part_a
  defp nalu_type(3), do: :part_b
  defp nalu_type(4), do: :part_c
  defp nalu_type(5), do: :idr
  defp nalu_type(6), do: :sei
  defp nalu_type(7), do: :sps
  defp nalu_type(8), do: :pps
  defp nalu_type(9), do: :aud
  defp nalu_type(10), do: :end_of_seq
  defp nalu_type(11), do: :end_of_stream
  defp nalu_type(12), do: :filler_data
  defp nalu_type(13), do: :sps_extension
  defp nalu_type(14), do: :prefix_nal_unit
  defp nalu_type(15), do: :subset_sps
  defp nalu_type(19), do: :auxiliary_non_part
  defp nalu_type(20), do: :extension
  defp nalu_type(type) when type in 16..18 or type in 21..23, do: :reserved
  defp nalu_type(_type), do: :unspecified
end

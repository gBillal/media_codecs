defmodule MediaCodecs.H265.NALU do
  @moduledoc """
  Struct describing an h265 nalu.
  """

  alias __MODULE__.{VPS, SPS, PPS, Slice}

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

  @type t :: %__MODULE__{
          type: nalu_type(),
          nuh_layer_id: non_neg_integer(),
          nuh_temporal_id_plus1: non_neg_integer(),
          content: struct() | nil
        }

  @irap [:idr_n_lp, :idr_w_radl, :cra, :bla_n_lp, :bla_w_radl]

  defstruct [:type, :nuh_layer_id, :nuh_temporal_id_plus1, :content]

  @doc """
  Parses the NALU header.
  """
  @spec parse_header(nalu :: binary()) :: t()
  def parse_header(nalu) do
    {type, nuh_layer_id, nuh_temporal_id_plus1} = header(nalu)

    %__MODULE__{
      nuh_layer_id: nuh_layer_id,
      type: nalu_type(type),
      nuh_temporal_id_plus1: nuh_temporal_id_plus1
    }
  end

  @doc """
  Gets NALu type.
  """
  @spec type(nalu :: binary()) :: nalu_type()
  def type(nalu) do
    {type, _, _} = header(nalu)
    nalu_type(type)
  end

  @doc """
  Parses a NALU bitstring and returns a NALU struct.

  An optional keyword can be provided to completely parse the NAL unit:
  - `:sps` - provide the parsed sps NAL unit. Needed for slice parsing.
  - `:pps` - provide the parsed pps NAL unit. Needed for slice parsing.
  """
  @spec parse(nalu :: binary(), keyword()) :: t()
  def parse(nalu, opts \\ []) do
    {int_type, nuh_layer_id, nuh_temporal_id_plus1} = header(nalu)
    type = nalu_type(int_type)

    parsed_nalu = %__MODULE__{
      type: type,
      nuh_layer_id: nuh_layer_id,
      nuh_temporal_id_plus1: nuh_temporal_id_plus1
    }

    case type do
      :vps ->
        %{parsed_nalu | content: VPS.parse(nalu)}

      :sps ->
        %{parsed_nalu | content: SPS.parse(nalu)}

      :pps ->
        %{parsed_nalu | content: PPS.parse(nalu)}

      _type when int_type < 32 ->
        %{parsed_nalu | content: Slice.parse(nalu, opts[:sps], opts[:pps])}

      _ ->
        parsed_nalu
    end
  end

  @doc """
  Checks if the NALU is a keyframe (IRAP NALU).

      iex> MediaCodecs.H265.NALU.keyframe?(%MediaCodecs.H265.NALU{type: :idr_n_lp})
      true

      iex> MediaCodecs.H265.NALU.keyframe?(%MediaCodecs.H265.NALU{type: :sps})
      false
  """
  @spec keyframe?(nalu :: binary() | t()) :: boolean()
  def keyframe?(%__MODULE__{type: type}), do: type in @irap

  def keyframe?(nalu) do
    {type, _, _} = header(nalu)
    type >= 16 and type <= 23
  end

  @doc """
  Checks if the NALU is a Video Coding Layer (VCL) NALU.
  """
  @spec vcl?(nalu :: binary()) :: boolean()
  def vcl?(nalu) do
    {type, _, _} = header(nalu)
    type < 32
  end

  defp header(<<_::1, type::6, nuh_layer_id::6, temporal_id::3, _nal_body::binary>>) do
    {type, nuh_layer_id, temporal_id}
  end

  defp nalu_type(0), do: :trail_n
  defp nalu_type(1), do: :trail_r
  defp nalu_type(2), do: :tsa_n
  defp nalu_type(3), do: :tsa_r
  defp nalu_type(4), do: :stsa_n
  defp nalu_type(5), do: :stsa_r
  defp nalu_type(6), do: :radl_n
  defp nalu_type(7), do: :radl_r
  defp nalu_type(8), do: :rasl_n
  defp nalu_type(9), do: :rasl_r
  defp nalu_type(16), do: :bla_w_lp
  defp nalu_type(17), do: :bla_w_radl
  defp nalu_type(18), do: :bla_n_lp
  defp nalu_type(19), do: :idr_w_radl
  defp nalu_type(20), do: :idr_n_lp
  defp nalu_type(21), do: :cra
  defp nalu_type(32), do: :vps
  defp nalu_type(33), do: :sps
  defp nalu_type(34), do: :pps
  defp nalu_type(35), do: :aud
  defp nalu_type(36), do: :eos
  defp nalu_type(37), do: :eob
  defp nalu_type(38), do: :fd
  defp nalu_type(39), do: :prefix_sei
  defp nalu_type(40), do: :suffix_sei
  defp nalu_type(t) when t in 10..15 or t in 24..31, do: :reserved_non_irap
  defp nalu_type(t) when t in 22..23, do: :reserved_irap
  defp nalu_type(t) when t in 41..47, do: :reserved_nvcl
  defp nalu_type(_type), do: :unspecified
end

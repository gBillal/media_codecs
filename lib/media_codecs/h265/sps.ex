defmodule MediaCodecs.H265.SPS do
  @moduledoc """
  Struct describing an H.265 Sequence Parameter Set (SPS).
  """

  import MediaCodecs.Helper

  @type t :: %__MODULE__{
          vps_id: non_neg_integer(),
          max_sub_layers_minus1: non_neg_integer(),
          temporal_id_nesting_flag: 0 | 1,
          profile_space: non_neg_integer(),
          tier_flag: 0 | 1,
          profile_idc: non_neg_integer(),
          profile_compatibility_flag: non_neg_integer(),
          progressive_source_flag: 0 | 1,
          interlaced_source_flag: 0 | 1,
          non_packed_constraint_flag: 0 | 1,
          frame_only_constraint_flag: 0 | 1,
          level_idc: non_neg_integer(),
          sps_id: non_neg_integer(),
          chroma_format_idc: non_neg_integer(),
          pic_width_in_luma_samples: non_neg_integer(),
          pic_height_in_luma_samples: non_neg_integer(),
          conformance_window: [non_neg_integer()] | nil,
          bit_depth_luma_minus8: non_neg_integer(),
          bit_depth_chroma_minus8: non_neg_integer()
        }

  @type profile :: :main | :main_10 | :main_still_picture | :rext

  defstruct [
    :vps_id,
    :max_sub_layers_minus1,
    :temporal_id_nesting_flag,
    :profile_space,
    :tier_flag,
    :profile_idc,
    :profile_compatibility_flag,
    :progressive_source_flag,
    :interlaced_source_flag,
    :non_packed_constraint_flag,
    :frame_only_constraint_flag,
    :level_idc,
    :sps_id,
    :chroma_format_idc,
    :pic_width_in_luma_samples,
    :pic_height_in_luma_samples,
    :conformance_window,
    :bit_depth_luma_minus8,
    :bit_depth_chroma_minus8
  ]

  @doc """
  Parses a SPS NALU from a binary string.
  """
  @spec parse(nal_body :: binary()) :: t()
  def parse(nalu_body) do
    nalu_body
    |> emulation_prevention_remove()
    |> do_parse()
  end

  @doc """
  Gets the width.
  """
  @spec width(t()) :: non_neg_integer()
  def width(%__MODULE__{conformance_window: nil} = sps), do: sps.pic_width_in_luma_samples

  def width(%__MODULE__{} = sps) do
    sub_width_c =
      case sps.chroma_format_idc do
        0 -> 1
        1 -> 2
        2 -> 2
        3 -> 1
      end

    [left, right, _top, _bottom] = sps.conformance_window
    sps.pic_width_in_luma_samples - sub_width_c * (right + left)
  end

  @doc """
  Gets the height.
  """
  @spec height(t()) :: non_neg_integer()
  def height(%__MODULE__{conformance_window: nil} = sps), do: sps.pic_height_in_luma_samples

  def height(%__MODULE__{} = sps) do
    sub_height_c =
      case sps.chroma_format_idc do
        0 -> 1
        1 -> 2
        2 -> 1
        3 -> 1
      end

    [_left, _right, top, bottom] = sps.conformance_window
    sps.pic_height_in_luma_samples - sub_height_c * (bottom + top)
  end

  @doc """
  Gets the stream profile.
  """
  @spec profile(t()) :: profile()
  def profile(%__MODULE__{profile_idc: 1}), do: :main
  def profile(%__MODULE__{profile_idc: 2}), do: :main_10
  def profile(%__MODULE__{profile_idc: 3}), do: :main_still_picture
  def profile(%__MODULE__{profile_idc: 4}), do: :rext

  defp do_parse(
         <<vps_id::4, max_sub_layers_minus1::3, temporal_id_nesting_flag::1, profile_space::2,
           tier_flag::1, profile_idc::5, profile_compatibility_flag::32,
           progressive_source_flag::1, interlaced_source_flag::1, non_packed_constraint_flag::1,
           frame_only_constraint_flag::1, _reserved_44bits::44, level_idc::8, rest::binary>>
       ) do
    {sps_id, rest} = exp_golomb_uint(rest)
    {chroma_format_idc, rest} = exp_golomb_uint(rest)
    rest = seperate_colour_plane(chroma_format_idc, rest)
    {pic_width_in_luma_samples, rest} = exp_golomb_uint(rest)
    {pic_height_in_luma_samples, rest} = exp_golomb_uint(rest)
    {conformance_window, rest} = conformance_window(rest)
    {bit_depth_luma_minus8, rest} = exp_golomb_uint(rest)
    {bit_depth_chroma_minus8, _rest} = exp_golomb_uint(rest)

    %__MODULE__{
      vps_id: vps_id,
      max_sub_layers_minus1: max_sub_layers_minus1,
      temporal_id_nesting_flag: temporal_id_nesting_flag,
      profile_space: profile_space,
      tier_flag: tier_flag,
      profile_idc: profile_idc,
      profile_compatibility_flag: profile_compatibility_flag,
      progressive_source_flag: progressive_source_flag,
      interlaced_source_flag: interlaced_source_flag,
      non_packed_constraint_flag: non_packed_constraint_flag,
      frame_only_constraint_flag: frame_only_constraint_flag,
      level_idc: level_idc,
      sps_id: sps_id,
      chroma_format_idc: chroma_format_idc,
      pic_width_in_luma_samples: pic_width_in_luma_samples,
      pic_height_in_luma_samples: pic_height_in_luma_samples,
      conformance_window: conformance_window,
      bit_depth_luma_minus8: bit_depth_luma_minus8,
      bit_depth_chroma_minus8: bit_depth_chroma_minus8
    }
  end

  defp conformance_window(<<1::1, rest::bitstring>>) do
    {left_offset, rest} = exp_golomb_uint(rest)
    {right_offset, rest} = exp_golomb_uint(rest)
    {top_offset, rest} = exp_golomb_uint(rest)
    {bottom_offset, rest} = exp_golomb_uint(rest)

    {[left_offset, right_offset, top_offset, bottom_offset], rest}
  end

  defp conformance_window(rest), do: {nil, rest}

  defp seperate_colour_plane(3, <<_::1, rest::bitstring>>), do: rest
  defp seperate_colour_plane(_chroma_format_idc, rest), do: rest
end

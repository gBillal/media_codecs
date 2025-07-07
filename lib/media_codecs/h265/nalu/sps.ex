defmodule MediaCodecs.H265.NALU.SPS do
  @moduledoc """
  Struct describing an H.265 Sequence Parameter Set (SPS).
  """

  import MediaCodecs.Helper

  @type t :: %__MODULE__{
          video_parameter_set_id: non_neg_integer(),
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
          seq_parameter_set_id: non_neg_integer(),
          chroma_format_idc: non_neg_integer(),
          separate_colour_plane_flag: 0 | 1,
          pic_width_in_luma_samples: non_neg_integer(),
          pic_height_in_luma_samples: non_neg_integer(),
          conformance_window: [non_neg_integer()] | nil,
          bit_depth_luma_minus8: non_neg_integer(),
          bit_depth_chroma_minus8: non_neg_integer(),
          log2_max_pic_order_cnt_lsb_minus4: non_neg_integer(),
          sub_layer_ordering_info_present_flag: 0 | 1,
          max_dec_pic_buffering_minus1: [non_neg_integer()],
          max_num_reorder_pics: [non_neg_integer()],
          max_latency_increase_plus1: [non_neg_integer()],
          log2_min_luma_coding_block_size_minus3: non_neg_integer(),
          log2_diff_max_min_luma_coding_block_size: non_neg_integer()
        }

  @type profile :: :main | :main_10 | :main_still_picture | :rext

  defstruct [
    :video_parameter_set_id,
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
    :seq_parameter_set_id,
    :chroma_format_idc,
    :separate_colour_plane_flag,
    :pic_width_in_luma_samples,
    :pic_height_in_luma_samples,
    :conformance_window,
    :bit_depth_luma_minus8,
    :bit_depth_chroma_minus8,
    :log2_max_pic_order_cnt_lsb_minus4,
    :sub_layer_ordering_info_present_flag,
    :max_dec_pic_buffering_minus1,
    :max_num_reorder_pics,
    :max_latency_increase_plus1,
    :log2_min_luma_coding_block_size_minus3,
    :log2_diff_max_min_luma_coding_block_size
  ]

  @doc """
  Parses a SPS NALU from a binary string.
  """
  @spec parse(nalu :: binary()) :: t()
  def parse(<<_heaader::16, nal_body::binary>> = _nalu) do
    nal_body
    |> emulation_prevention_remove()
    |> do_parse()
  end

  @doc """
  Gets the SPS ID.
  """
  @spec id(nalu :: binary()) :: non_neg_integer()
  def id(<<_header::16, body::binary>>) do
    <<_::binary-size(13), rest::binary>> = emulation_prevention_remove(body)

    rest
    |> exp_golomb_uint()
    |> elem(0)
  end

  @doc """
  Get video parameter set ID from the SPS.
  """
  @spec video_parameter_set_id(nalu :: binary()) :: non_neg_integer()
  def video_parameter_set_id(<<_header::16, vps_id::4, _rest::bitstring>>), do: vps_id

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

  @doc """
  Builds the MIME type from the SPS.

  The tag is the first part of the MIME type (e.g. `hvc1`).
  """
  @spec mime_type(t(), String.t()) :: String.t()
  def mime_type(%__MODULE__{} = sps, tag) do
    tier =
      case sps.tier_flag do
        0 -> "L"
        1 -> "H"
      end

    "#{tag}.#{sps.profile_idc}.#{reverse_bits(sps.profile_compatibility_flag, 32)}.#{tier}#{sps.level_idc}.B0"
  end

  @doc false
  def segment_size(%__MODULE__{} = sps) do
    pic_width = sps.pic_width_in_luma_samples
    pic_height = sps.pic_height_in_luma_samples

    min_luma_block_size = sps.log2_min_luma_coding_block_size_minus3 + 3
    ctb_log2_size_y = min_luma_block_size + sps.log2_diff_max_min_luma_coding_block_size
    ctb_size_y = Bitwise.bsl(1, ctb_log2_size_y)

    pic_width_in_ctbs_y = ceil(pic_width / ctb_size_y)
    pic_height_in_ctbs_y = ceil(pic_height / ctb_size_y)

    (pic_width_in_ctbs_y * pic_height_in_ctbs_y)
    |> :math.log2()
    |> ceil()
  end

  defp do_parse(
         <<video_parameter_set_id::4, max_sub_layers_minus1::3, temporal_id_nesting_flag::1,
           profile_space::2, tier_flag::1, profile_idc::5, profile_compatibility_flag::32,
           progressive_source_flag::1, interlaced_source_flag::1, non_packed_constraint_flag::1,
           frame_only_constraint_flag::1, _reserved_44bits::44, level_idc::8, rest::binary>>
       ) do
    {seq_parameter_set_id, rest} = exp_golomb_uint(rest)
    {chroma_format_idc, rest} = exp_golomb_uint(rest)
    {separate_colour_plane_flag, rest} = separate_colour_plane_flag(chroma_format_idc, rest)
    {pic_width_in_luma_samples, rest} = exp_golomb_uint(rest)
    {pic_height_in_luma_samples, rest} = exp_golomb_uint(rest)
    {conformance_window, rest} = conformance_window(rest)
    {bit_depth_luma_minus8, rest} = exp_golomb_uint(rest)
    {bit_depth_chroma_minus8, rest} = exp_golomb_uint(rest)
    {log2_max_pic_order_cnt_lsb_minus4, rest} = exp_golomb_uint(rest)
    <<sub_layer_ordering_info_present_flag::1, rest::bitstring>> = rest

    idx = if sub_layer_ordering_info_present_flag == 1, do: 0, else: max_sub_layers_minus1

    {{max_dec_pic_buffering_minus1, max_num_reorder_pics, max_latency_increase_plus1}, rest} =
      Enum.reduce(idx..max_sub_layers_minus1, {{[], [], []}, rest}, fn _idx,
                                                                       {{list1, list2, list3},
                                                                        rest} ->
        {max_dec_pic_buffering_minus1, rest} = exp_golomb_uint(rest)
        {max_num_reorder_pics, rest} = exp_golomb_uint(rest)
        {max_latency_increase_plus1, rest} = exp_golomb_uint(rest)

        {{[max_dec_pic_buffering_minus1 | list1], [max_num_reorder_pics | list2],
          [max_latency_increase_plus1 | list3]}, rest}
      end)

    {log2_min_luma_coding_block_size_minus3, rest} = exp_golomb_uint(rest)
    {log2_diff_max_min_luma_coding_block_size, _rest} = exp_golomb_uint(rest)

    %__MODULE__{
      video_parameter_set_id: video_parameter_set_id,
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
      seq_parameter_set_id: seq_parameter_set_id,
      chroma_format_idc: chroma_format_idc,
      separate_colour_plane_flag: separate_colour_plane_flag,
      pic_width_in_luma_samples: pic_width_in_luma_samples,
      pic_height_in_luma_samples: pic_height_in_luma_samples,
      conformance_window: conformance_window,
      bit_depth_luma_minus8: bit_depth_luma_minus8,
      bit_depth_chroma_minus8: bit_depth_chroma_minus8,
      log2_max_pic_order_cnt_lsb_minus4: log2_max_pic_order_cnt_lsb_minus4,
      sub_layer_ordering_info_present_flag: sub_layer_ordering_info_present_flag,
      max_dec_pic_buffering_minus1: Enum.reverse(max_dec_pic_buffering_minus1),
      max_num_reorder_pics: Enum.reverse(max_num_reorder_pics),
      max_latency_increase_plus1: Enum.reverse(max_latency_increase_plus1),
      log2_min_luma_coding_block_size_minus3: log2_min_luma_coding_block_size_minus3,
      log2_diff_max_min_luma_coding_block_size: log2_diff_max_min_luma_coding_block_size
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

  defp separate_colour_plane_flag(3, <<separate_colour_plane_flag::1, rest::bitstring>>),
    do: {separate_colour_plane_flag, rest}

  defp separate_colour_plane_flag(_chroma_format_idc, rest), do: {0, rest}

  defp reverse_bits(number, width) do
    do_reverse_bits(number, width, 0)
  end

  defp do_reverse_bits(0, 0, reversed), do: reversed

  defp do_reverse_bits(n, width, reversed) do
    next_reversed = Bitwise.bsl(reversed, 1) |> Bitwise.bor(Bitwise.band(n, 1))
    do_reverse_bits(Bitwise.bsr(n, 1), width - 1, next_reversed)
  end
end

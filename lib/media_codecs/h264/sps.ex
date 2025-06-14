defmodule MediaCodecs.H264.SPS do
  @moduledoc """
  Struct describing an H.264 Sequence Parameter Set (SPS).
  """

  import MediaCodecs.Helper

  @type t :: %__MODULE__{
          seq_parameter_set_id: non_neg_integer(),
          profile_idc: non_neg_integer(),
          level_idc: non_neg_integer(),
          chroma_format_idc: non_neg_integer(),
          separate_colour_plane_flag: 0 | 1,
          bit_depth_luma_minus8: non_neg_integer(),
          bit_depth_chroma_minus8: non_neg_integer(),
          qpprime_y_zero_transform_bypass_flag: 0 | 1,
          scaling_list: list(list(non_neg_integer())),
          log2_max_frame_num_minus4: non_neg_integer(),
          pic_order_cnt_type: non_neg_integer(),
          log2_max_pic_order_cnt_lsb_minus4: non_neg_integer() | nil,
          delta_pic_order_always_zero_flag: 0 | 1,
          offset_for_non_ref_pic: integer() | nil,
          offset_for_top_to_bottom_field: integer() | nil,
          num_ref_frames_in_pic_order_cnt_cycle: non_neg_integer() | nil,
          offset_for_ref_frame: list(integer()),
          max_num_ref_frames: non_neg_integer(),
          gaps_in_frame_num_value_allowed_flag: 0 | 1,
          pic_width_in_mbs_minus1: non_neg_integer(),
          pic_height_in_map_units_minus1: non_neg_integer(),
          frame_mbs_only_flag: 0 | 1,
          mb_adaptive_frame_field_flag: 0 | 1,
          direct_8x8_inference_flag: 0 | 1,
          frame_crop_offset:
            %{
              left: non_neg_integer(),
              right: non_neg_integer(),
              top: non_neg_integer(),
              bottom: non_neg_integer()
            }
            | nil
        }

  defstruct [
    :seq_parameter_set_id,
    :profile_idc,
    :level_idc,
    :log2_max_frame_num_minus4,
    :pic_order_cnt_type,
    :log2_max_pic_order_cnt_lsb_minus4,
    :delta_pic_order_always_zero_flag,
    :offset_for_non_ref_pic,
    :offset_for_top_to_bottom_field,
    :num_ref_frames_in_pic_order_cnt_cycle,
    :max_num_ref_frames,
    :gaps_in_frame_num_value_allowed_flag,
    :pic_width_in_mbs_minus1,
    :pic_height_in_map_units_minus1,
    :frame_mbs_only_flag,
    :direct_8x8_inference_flag,
    :frame_crop_offset,
    chroma_format_idc: 1,
    separate_colour_plane_flag: 0,
    bit_depth_luma_minus8: 0,
    bit_depth_chroma_minus8: 0,
    qpprime_y_zero_transform_bypass_flag: 0,
    scaling_list: [],
    offset_for_ref_frame: [],
    mb_adaptive_frame_field_flag: 0
  ]

  @doc """
  Parses a Sequence Parameter Set (SPS) NALU.
  """
  @spec parse(binary()) :: t()
  def parse(<<_header::8, nalu_body::binary>>) do
    nalu_body
    |> emulation_prevention_remove()
    |> do_parse()
  end

  @doc """
  Gets the video width
  """
  @spec width(t()) :: non_neg_integer()
  def width(%__MODULE__{} = sps) do
    chroma_array_type = if sps.separate_colour_plane_flag == 0, do: sps.chroma_format_idc, else: 0

    sub_width_c =
      case sps.chroma_format_idc do
        1 -> 2
        2 -> 2
        3 -> 1
      end

    crop_unit_x = if chroma_array_type == 0, do: 1, else: sub_width_c

    width_offset =
      case sps.frame_crop_offset do
        %{left: left, right: right} -> (left + right) * crop_unit_x
        nil -> 0
      end

    (sps.pic_width_in_mbs_minus1 + 1) * 16 - width_offset
  end

  @doc """
  Gets the video width
  """
  @spec height(t()) :: non_neg_integer()
  def height(%__MODULE__{} = sps) do
    chroma_array_type = if sps.separate_colour_plane_flag == 0, do: sps.chroma_format_idc, else: 0

    sub_height_c =
      case sps.chroma_format_idc do
        1 -> 2
        2 -> 1
        3 -> 1
      end

    crop_unit_y =
      if chroma_array_type == 0,
        do: 2 - sps.frame_mbs_only_flag,
        else: sub_height_c * (2 - sps.frame_mbs_only_flag)

    height_offset =
      case sps.frame_crop_offset do
        %{top: top, bottom: bottom} -> (top + bottom) * crop_unit_y
        nil -> 0
      end

    height_in_map_units = sps.pic_height_in_map_units_minus1 + 1
    height_in_mbs = (2 - sps.frame_mbs_only_flag) * height_in_map_units
    height_in_mbs * 16 - height_offset
  end

  defp do_parse(<<profile_idc::8, _constraint_set::6, _reserverd::2, level_idc::8, rest::binary>>) do
    {seq_parameter_set_id, rest} = exp_golomb_uint(rest)

    sps = %__MODULE__{
      seq_parameter_set_id: seq_parameter_set_id,
      profile_idc: profile_idc,
      level_idc: level_idc
    }

    {sps, rest} =
      if profile_idc in [100, 110, 122, 244, 44, 83, 86, 118, 128, 138, 139, 134, 135] do
        {chroma_format_idc, rest} = exp_golomb_uint(rest)
        {separate_colour_plane_flag, rest} = separate_colour_plane_flag(chroma_format_idc, rest)
        {bit_depth_luma_minus8, rest} = exp_golomb_uint(rest)
        {bit_depth_chroma_minus8, rest} = exp_golomb_uint(rest)
        <<qpprime_y_zero_transform_bypass_flag::1, rest::bitstring>> = rest
        {scaling_list, rest} = scaling_list(chroma_format_idc, rest)

        sps = %{
          sps
          | chroma_format_idc: chroma_format_idc,
            separate_colour_plane_flag: separate_colour_plane_flag,
            bit_depth_luma_minus8: bit_depth_luma_minus8,
            bit_depth_chroma_minus8: bit_depth_chroma_minus8,
            qpprime_y_zero_transform_bypass_flag: qpprime_y_zero_transform_bypass_flag,
            scaling_list: scaling_list
        }

        {sps, rest}
      else
        {sps, rest}
      end

    {log2_max_frame_num_minus4, rest} = exp_golomb_uint(rest)
    {pic_order_cnt_type, rest} = exp_golomb_uint(rest)

    sps = %{
      sps
      | log2_max_frame_num_minus4: log2_max_frame_num_minus4,
        pic_order_cnt_type: pic_order_cnt_type
    }

    {sps, rest} =
      case pic_order_cnt_type do
        0 ->
          {log2_max_pic_order_cnt_lsb_minus4, rest} = exp_golomb_uint(rest)
          sps = %{sps | log2_max_pic_order_cnt_lsb_minus4: log2_max_pic_order_cnt_lsb_minus4}
          {sps, rest}

        1 ->
          <<delta_pic_order_always_zero_flag::1, rest::bitstring>> = rest
          {offset_for_non_ref_pic, rest} = exp_golomb_int(rest)
          {offset_for_top_to_bottom_field, rest} = exp_golomb_int(rest)
          {num_ref_frames_in_pic_order_cnt_cycle, rest} = exp_golomb_uint(rest)

          {offset_for_ref_frame, rest} =
            Enum.reduce(1..num_ref_frames_in_pic_order_cnt_cycle//1, {[], rest}, fn _i,
                                                                                    {acc, data} ->
              {offset, data} = exp_golomb_int(data)
              {[offset | acc], data}
            end)

          sps = %{
            sps
            | delta_pic_order_always_zero_flag: delta_pic_order_always_zero_flag,
              offset_for_non_ref_pic: offset_for_non_ref_pic,
              offset_for_top_to_bottom_field: offset_for_top_to_bottom_field,
              num_ref_frames_in_pic_order_cnt_cycle: num_ref_frames_in_pic_order_cnt_cycle,
              offset_for_ref_frame: Enum.reverse(offset_for_ref_frame)
          }

          {sps, rest}

        _ ->
          {sps, rest}
      end

    {max_num_ref_frames, rest} = exp_golomb_uint(rest)
    <<gaps_in_frame_num_value_allowed_flag::1, rest::bitstring>> = rest
    {pic_width_in_mbs_minus1, rest} = exp_golomb_uint(rest)
    {pic_height_in_map_units_minus1, rest} = exp_golomb_uint(rest)
    <<frame_mbs_only_flag::1, rest::bitstring>> = rest

    {mb_adaptive_frame_field_flag, rest} =
      if frame_mbs_only_flag != 1 do
        <<mb_adaptive_frame_field_flag::1, rest::bitstring>> = rest
        {mb_adaptive_frame_field_flag, rest}
      else
        {0, rest}
      end

    <<direct_8x8_inference_flag::1, frame_cropping_flag::1, rest::bitstring>> = rest
    {frame_crop_offset, _rest} = frame_cropping(frame_cropping_flag, rest)

    %{
      sps
      | max_num_ref_frames: max_num_ref_frames,
        gaps_in_frame_num_value_allowed_flag: gaps_in_frame_num_value_allowed_flag,
        pic_width_in_mbs_minus1: pic_width_in_mbs_minus1,
        pic_height_in_map_units_minus1: pic_height_in_map_units_minus1,
        frame_mbs_only_flag: frame_mbs_only_flag,
        mb_adaptive_frame_field_flag: mb_adaptive_frame_field_flag,
        direct_8x8_inference_flag: direct_8x8_inference_flag,
        frame_crop_offset: frame_crop_offset
    }
  end

  defp separate_colour_plane_flag(3, <<separate_colour_plane_flag::1, rest::binary>>) do
    {separate_colour_plane_flag, rest}
  end

  defp separate_colour_plane_flag(_chromma_format_idc, rest) do
    {0, rest}
  end

  defp scaling_list(chroma_format_idc, <<1::1, rest::bitstring>>) do
    lim = if chroma_format_idc != 3, do: 8, else: 12
    scaling_list_data(rest, 1, lim, [])
  end

  defp scaling_list(_chroma_format_idc, <<_::1, rest::bitstring>>), do: {[], rest}

  defp scaling_list_data(data, idx, lim, acc) when idx > lim,
    do: {Enum.reverse(acc), data}

  defp scaling_list_data(<<1::1, data::bitstring>>, idx, lim, acc) do
    last_scale = 8
    next_scale = 8

    scaling_list_size = if idx <= 6, do: 16, else: 64

    {data, scaling_list, _last_scale, _next_scale} =
      Enum.reduce(1..scaling_list_size, {data, [], last_scale, next_scale}, fn _j,
                                                                               {data, acc,
                                                                                last_scale,
                                                                                next_scale} ->
        {data, next_scale} =
          if next_scale != 0 do
            {delta_scale, data} = exp_golomb_int(data)
            {data, rem(last_scale + delta_scale + 256, 256)}
          else
            {data, next_scale}
          end

        last_scale = if next_scale == 0, do: last_scale, else: next_scale
        {data, [last_scale | acc], last_scale, next_scale}
      end)

    scaling_list_data(data, idx + 1, lim, [Enum.reverse(scaling_list) | acc])
  end

  defp scaling_list_data(<<0::1, data::bitstring>>, idx, lim, acc),
    do: scaling_list_data(data, idx + 1, lim, acc)

  defp frame_cropping(1, rest) do
    {frame_crop_left_offset, rest} = exp_golomb_uint(rest)
    {frame_crop_right_offset, rest} = exp_golomb_uint(rest)
    {frame_crop_top_offset, rest} = exp_golomb_uint(rest)
    {frame_crop_bottom_offset, rest} = exp_golomb_uint(rest)

    {
      %{
        left: frame_crop_left_offset,
        right: frame_crop_right_offset,
        top: frame_crop_top_offset,
        bottom: frame_crop_bottom_offset
      },
      rest
    }
  end

  defp frame_cropping(_frame_cropping_flag = 0, rest), do: {nil, rest}
end

defmodule MediaCodecs.H264.NALU.Slice do
  @moduledoc """
  Struct describing an H.264 Slice.
  """

  import MediaCodecs.Helper

  alias MediaCodecs.H264.NALU.{PPS, SPS}

  @type ps_callback :: (non_neg_integer() -> binary() | nil)

  @type t :: %__MODULE__{
          first_mb_in_slice: non_neg_integer(),
          slice_type: non_neg_integer(),
          pic_parameter_set_id: non_neg_integer(),
          colour_plane_id: non_neg_integer() | nil,
          frame_num: non_neg_integer(),
          field_pic_flag: 0 | 1,
          bottom_field_flag: 0 | 1,
          idr_pic_id: non_neg_integer(),
          pic_order_cnt_lsb: non_neg_integer(),
          delta_pic_order_cnt_bottom: integer()
        }

  defstruct [
    :first_mb_in_slice,
    :slice_type,
    :pic_parameter_set_id,
    :colour_plane_id,
    :frame_num,
    :bottom_field_flag,
    :idr_pic_id,
    :pic_order_cnt_lsb,
    :delta_pic_order_cnt_bottom,
    field_pic_flag: 0
  ]

  @doc """
  Parses a PPS NALU from a binary string.
  """
  @spec parse(nalu :: binary(), SPS.t() | ps_callback() | nil, PPS.t() | ps_callback() | nil) ::
          t()
  def parse(<<_::3, type::5, nalu_body::binary>>, sps \\ nil, pps \\ nil) do
    nalu_body
    |> emulation_prevention_remove()
    |> do_parse(type, sps, pps)
  end

  defp do_parse(data, type, sps, pps) do
    {first_mb_in_slice, data} = exp_golomb_uint(data)
    {slice_type, data} = exp_golomb_uint(data)
    {pic_parameter_set_id, data} = exp_golomb_uint(data)

    slice = %__MODULE__{
      first_mb_in_slice: first_mb_in_slice,
      slice_type: slice_type,
      pic_parameter_set_id: pic_parameter_set_id
    }

    sps = get_ps(pic_parameter_set_id, sps)
    pps = get_ps(pic_parameter_set_id, pps)

    if is_nil(sps) or is_nil(pps) do
      slice
    else
      {colour_plane_id, data} = colour_plane_id(data, sps.separate_colour_plane_flag)

      <<frame_num::integer-size(sps.log2_max_frame_num_minus4 + 4), data::bitstring>> =
        data

      {field_pic_flag, data} = field_pic_flag(data, sps.frame_mbs_only_flag)
      {bottom_field_flag, data} = bottom_field_flag(data, field_pic_flag)

      {idr_pic_id, data} =
        if type == 5 do
          exp_golomb_uint(data)
        else
          {nil, data}
        end

      {pic_order_cnt_lsb, delta_pic_order_cnt_bottom, _data} =
        pic_order_cnt_lsb(data, field_pic_flag, sps, pps)

      %__MODULE__{
        slice
        | colour_plane_id: colour_plane_id,
          frame_num: frame_num,
          field_pic_flag: field_pic_flag,
          bottom_field_flag: bottom_field_flag,
          idr_pic_id: idr_pic_id,
          pic_order_cnt_lsb: pic_order_cnt_lsb,
          delta_pic_order_cnt_bottom: delta_pic_order_cnt_bottom
      }
    end
  end

  defp colour_plane_id(<<colour_plane_id::2, data::bitstring>>, 1) do
    {colour_plane_id, data}
  end

  defp colour_plane_id(data, _sps), do: {nil, data}

  defp field_pic_flag(<<field_pic_flag::1, data::bitstring>>, _frame_mbs_only_flag = 0) do
    {field_pic_flag, data}
  end

  defp field_pic_flag(data, _frame_mbs_only_flsg), do: {0, data}

  defp bottom_field_flag(<<bottom_field_flag::1, data::bitstring>>, 1) do
    {bottom_field_flag, data}
  end

  defp bottom_field_flag(data, _sps), do: {0, data}

  defp pic_order_cnt_lsb(data, field_pic_flag, %{pic_order_cnt_type: 0} = sps, pps) do
    <<pic_order_cnt_lsb::integer-size(sps.log2_max_pic_order_cnt_lsb_minus4 + 4),
      data::bitstring>> = data

    if pps.bottom_field_pic_order_in_frame_present_flag == 1 and field_pic_flag == 0 do
      {delta_pic_order_cnt_bottom, data} = exp_golomb_int(data)
      {pic_order_cnt_lsb, delta_pic_order_cnt_bottom, data}
    else
      {pic_order_cnt_lsb, 0, data}
    end
  end

  defp pic_order_cnt_lsb(data, _field_pic_flag, _sps, _pps), do: {0, 0, data}

  defp get_ps(_pps_id, ps) when is_binary(ps), do: ps
  defp get_ps(pps_id, ps) when is_function(ps, 1), do: ps.(pps_id)
  defp get_ps(_pps_id, _ps), do: nil
end

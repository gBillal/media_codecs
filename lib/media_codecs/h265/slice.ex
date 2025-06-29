defmodule MediaCodecs.H265.Slice do
  @moduledoc """
  Struct describing an H.265 slice.
  """

  import MediaCodecs.Helper

  alias MediaCodecs.H265.{PPS, SPS}

  @type t :: %__MODULE__{
          first_slice_segment_in_pic_flag: 0 | 1,
          no_output_of_prior_pics_flag: 0 | 1,
          pic_parameter_set_id: non_neg_integer(),
          dependent_slice_segment_flag: 0 | 1,
          slice_segment_address: non_neg_integer(),
          slice_type: non_neg_integer(),
          pic_output_flag: 0 | 1,
          colour_plane_id: non_neg_integer() | nil,
          pic_order_cnt_lsb: non_neg_integer()
        }

  defstruct [
    :first_slice_segment_in_pic_flag,
    :no_output_of_prior_pics_flag,
    :pic_parameter_set_id,
    :dependent_slice_segment_flag,
    :slice_segment_address,
    :slice_type,
    :pic_output_flag,
    :colour_plane_id,
    :pic_order_cnt_lsb
  ]

  @doc """
  Parses a PPS NALU from a binary string.
  """
  @spec parse(nalu :: binary(), SPS.t() | nil, PPS.t() | nil) :: t()
  def parse(<<_::1, type::6, _::9, nal_body::binary>>, sps \\ nil, pps \\ nil) do
    nal_body
    |> emulation_prevention_remove()
    |> do_parse(type, sps, pps)
  end

  defp do_parse(<<first_slice_segment_in_pic_flag::1, data::bitstring>>, type, sps, pps) do
    {no_output_of_prior_pics_flag, data} =
      if type >= 16 and type <= 23 do
        <<no_output_of_prior_pics_flag::1, data::bitstring>> = data
        {no_output_of_prior_pics_flag, data}
      else
        {0, data}
      end

    {pic_parameter_set_id, data} = exp_golomb_uint(data)

    slice = %__MODULE__{
      first_slice_segment_in_pic_flag: first_slice_segment_in_pic_flag,
      no_output_of_prior_pics_flag: no_output_of_prior_pics_flag,
      pic_parameter_set_id: pic_parameter_set_id
    }

    if is_nil(sps) or is_nil(pps) do
      slice
    else
      segment_address = SPS.segment_size(sps)

      {dependent_slice_segment_flag, slice_segment_address, data} =
        case {first_slice_segment_in_pic_flag, pps.dependent_slice_segments_enabled_flag} do
          {0, 1} ->
            <<dependent_slice_segment_flag::1,
              slice_segment_address::integer-size(segment_address), data::bitstring>> = data

            {dependent_slice_segment_flag, slice_segment_address, data}

          {0, 0} ->
            <<slice_segment_address::integer-size(segment_address), data::bitstring>> = data
            {0, slice_segment_address, data}

          _other ->
            {0, nil, data}
        end

      slice = %__MODULE__{
        slice
        | dependent_slice_segment_flag: dependent_slice_segment_flag,
          slice_segment_address: slice_segment_address
      }

      parse_non_dependent_slice_segment(data, type, sps, pps, slice)
    end
  end

  defp parse_non_dependent_slice_segment(
         data,
         nal_type,
         sps,
         pps,
         %{dependent_slice_segment_flag: 0} = slice
       ) do
    <<_slice_reserved_flag::binary-size(pps.num_extra_slice_header_bits), data::bitstring>> = data
    {slice_type, data} = exp_golomb_uint(data)
    {pic_output_flag, data} = pic_output_flag_present_flag(data, pps.output_flag_present_flag)
    {colour_plane_id, data} = colour_plane_id(data, sps.separate_colour_plane_flag)

    {pic_order_cnt_lsb, _data} =
      if nal_type != 10 and nal_type != 20 do
        <<pic_order_cnt_lsb::integer-size(sps.log2_max_pic_order_cnt_lsb_minus4 + 4),
          data::bitstring>> = data

        {pic_order_cnt_lsb, data}
      else
        {0, data}
      end

    %__MODULE__{
      slice
      | slice_type: slice_type,
        pic_output_flag: pic_output_flag,
        colour_plane_id: colour_plane_id,
        pic_order_cnt_lsb: pic_order_cnt_lsb
    }
  end

  defp parse_non_dependent_slice_segment(_data, _nal_type, _sps, _pps, slice), do: slice

  defp pic_output_flag_present_flag(<<pic_output_flag::1, data::bitstring>>, 1) do
    {pic_output_flag, data}
  end

  defp pic_output_flag_present_flag(data, 0), do: {1, data}

  defp colour_plane_id(<<colour_plane_id::2, data::bitstring>>, 1) do
    {colour_plane_id, data}
  end

  defp colour_plane_id(data, 0), do: {nil, data}
end

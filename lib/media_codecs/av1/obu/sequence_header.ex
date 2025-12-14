defmodule MediaCodecs.AV1.OBU.SequenceHeader do
  @moduledoc """
  Module describing an AV1 OBU Sequence Header.
  """

  import MediaCodecs.Helper

  @type operating_parameters_info :: %{
          decoder_buffer_delay: non_neg_integer(),
          encoder_buffer_delay: non_neg_integer(),
          low_delay_mode_flag: boolean()
        }

  @type operating_point :: %{
          operating_point_idc: non_neg_integer(),
          seq_level_idx: non_neg_integer(),
          seq_tier: 0..1,
          operating_parameters_info: operating_parameters_info() | nil,
          initial_display_delay_minus_1: non_neg_integer()
        }

  @type timing_info :: %{
          num_units_in_display_tick: non_neg_integer(),
          time_scale: non_neg_integer(),
          num_ticks_per_picture_minus_1: non_neg_integer() | nil
        }

  @type decoder_model_info :: %{
          buffer_delay_length_minus_1: non_neg_integer(),
          num_units_in_decoding_tick: non_neg_integer(),
          buffer_removal_time_length_minus_1: non_neg_integer(),
          frame_presentation_time_length_minus_1: non_neg_integer()
        }

  @type color_config :: %{
          high_bitdepth: boolean(),
          bitdepth: non_neg_integer(),
          monochrome: boolean(),
          subsampling_x: 0..1,
          subsampling_y: 0..1,
          chroma_sample_position: non_neg_integer()
        }

  @type t :: %__MODULE__{
          seq_profile: 0..7,
          still_picture: boolean(),
          reduced_still_picture_header: boolean(),
          timing_info: timing_info() | nil,
          initial_display_delay_present_flag: boolean(),
          operating_points_cnt_minus_1: non_neg_integer(),
          operating_points: %{non_neg_integer() => operating_point()},
          decoder_model_info: decoder_model_info() | nil,
          max_frame_width_minus_1: non_neg_integer(),
          max_frame_height_minus_1: non_neg_integer(),
          delta_frame_id_length_minus_2: non_neg_integer() | nil,
          additional_frame_id_length_minus_1: non_neg_integer() | nil,
          use_128x128_superblock: boolean(),
          enable_filter_intra: boolean(),
          enable_intra_edge_filter: boolean(),
          color_config: color_config()
        }

  defstruct [
    :seq_profile,
    :still_picture,
    :reduced_still_picture_header,
    :timing_info,
    :operating_points,
    :decoder_model_info,
    :max_frame_width_minus_1,
    :max_frame_height_minus_1,
    :delta_frame_id_length_minus_2,
    :additional_frame_id_length_minus_1,
    :use_128x128_superblock,
    :enable_filter_intra,
    :enable_intra_edge_filter,
    :color_config,
    initial_display_delay_present_flag: false,
    operating_points_cnt_minus_1: 0
  ]

  @doc """
  Parses an OBU Sequence Header payload.
  """
  @spec parse(binary()) :: t()
  def parse(
        <<seq_profile::3, still_picture::1, reduced_still_picture_header::1, rest::bitstring>>
      ) do
    sequence_header = %__MODULE__{
      seq_profile: seq_profile,
      still_picture: still_picture == 1,
      reduced_still_picture_header: reduced_still_picture_header == 1
    }

    {sequence_header, _rest} =
      if reduced_still_picture_header == 1 do
        parse_reduced_still_picture_header(sequence_header, rest)
      else
        <<timing_info_present_flag::1, rest::bitstring>> = rest
        {timing_info, rest} = parse_timing_info(timing_info_present_flag == 1, rest)
        {decoder_model_info, rest} = parse_decoder_model_info(timing_info_present_flag == 1, rest)

        <<initial_display_delay_present_flag::1, operating_points_cnt_minus_1::5,
          rest::bitstring>> =
          rest

        {operating_points, rest} =
          Enum.reduce(0..operating_points_cnt_minus_1//1, {%{}, rest}, fn idx,
                                                                          {operating_points, data} ->
            {operating_point, rest} =
              parse_operating_point(
                data,
                decoder_model_info,
                initial_display_delay_present_flag
              )

            {Map.put(operating_points, idx, operating_point), rest}
          end)

        <<frame_width_bits_minus_1::4, frame_height_bits_minus_1::4,
          max_frame_width_minus_1::size(frame_width_bits_minus_1 + 1),
          max_frame_height_minus_1::size(frame_height_bits_minus_1 + 1),
          frame_id_numbers_present_flag::size(1 - reduced_still_picture_header),
          delta_frame_id_length_minus_2::size(frame_id_numbers_present_flag * 4),
          additional_frame_id_length_minus_1::size(frame_id_numbers_present_flag * 3),
          use_128x128_superblock::1, enable_filter_intra::1, enable_intra_edge_filter::1,
          rest::bitstring>> = rest

        sequence_header = %{
          sequence_header
          | initial_display_delay_present_flag: initial_display_delay_present_flag == 1,
            operating_points_cnt_minus_1: operating_points_cnt_minus_1,
            decoder_model_info: decoder_model_info,
            timing_info: timing_info,
            operating_points: operating_points,
            max_frame_width_minus_1: max_frame_width_minus_1,
            max_frame_height_minus_1: max_frame_height_minus_1,
            delta_frame_id_length_minus_2: delta_frame_id_length_minus_2,
            additional_frame_id_length_minus_1: additional_frame_id_length_minus_1,
            use_128x128_superblock: use_128x128_superblock == 1,
            enable_filter_intra: enable_filter_intra == 1,
            enable_intra_edge_filter: enable_intra_edge_filter == 1
        }

        {sequence_header, rest}
      end

    rest =
      if reduced_still_picture_header == 1 do
        <<_::3, rest::bitstring>> = rest
        rest
      else
        <<_::4, enable_order_hint::1, _::size(enable_order_hint * 2),
          seq_choose_screen_content_tools::1, rest::bitstring>> = rest

        {seq_force_screen_content_tools, rest} =
          if seq_choose_screen_content_tools == 1, do: {1, rest}, else: next_bit(rest)

        <<seq_choose_integer_mv::size(seq_force_screen_content_tools),
          _::size(1 - seq_choose_integer_mv), _::size(enable_order_hint * 3 + 3),
          rest::bitstring>> = rest

        rest
      end

    {color_config, _rest} = parse_color_config(rest, seq_profile)
    %{sequence_header | color_config: color_config}
  end

  @doc """
  Gets frame width from sequence header.
  """
  @spec width(t()) :: non_neg_integer()
  def width(%__MODULE__{max_frame_width_minus_1: w}), do: w + 1

  @doc """
  Gets frame height from sequence header.
  """
  @spec height(t()) :: non_neg_integer()
  def height(%__MODULE__{max_frame_height_minus_1: h}), do: h + 1

  @doc """
  Gets mime type to use in `Codecs` field in HLS and Dash.
  """
  @spec mime_type(t()) :: String.t()
  def mime_type(%__MODULE__{seq_profile: profile} = sh) do
    %{seq_level_idx: level, seq_tier: tier} = sh.operating_points[0]

    level = String.pad_leading(Integer.to_string(level), 2, "0")
    tier = if tier == 0, do: "M", else: "H"
    bitdepth = String.pad_leading(Integer.to_string(sh.color_config[:bitdepth]), 2, "0")

    "av01.#{profile}.#{level}#{tier}.#{bitdepth}"
  end

  defp parse_reduced_still_picture_header(sh, <<seq_level_idx::5, rest::bitstring>>) do
    operating_point = %{
      operating_point_idc: 0,
      seq_level_idx: seq_level_idx,
      seq_tier: 0
    }

    {%{sh | operating_points: %{0 => operating_point}}, rest}
  end

  defp parse_timing_info(
         true,
         <<num_units_in_display_tick::32, time_scale::32, equal_picture_interval::1,
           rest::bitstring>>
       ) do
    {num_ticks_per_picture_minus_1, rest} =
      if equal_picture_interval == 1, do: uvlc(rest), else: {nil, rest}

    timing_info = %{
      num_units_in_display_tick: num_units_in_display_tick,
      time_scale: time_scale,
      num_ticks_per_picture_minus_1: num_ticks_per_picture_minus_1
    }

    {timing_info, rest}
  end

  defp parse_timing_info(false, data), do: {nil, data}

  defp parse_decoder_model_info(false, data), do: {nil, data}

  defp parse_decoder_model_info(
         true,
         <<buffer_delay_length_minus_1::5, num_units_in_decoding_tick::32,
           buffer_removal_time_length_minus_1::5, frame_presentation_time_length_minus_1::5,
           rest::bitstring>>
       ) do
    decoder_model_info = %{
      buffer_delay_length_minus_1: buffer_delay_length_minus_1,
      num_units_in_decoding_tick: num_units_in_decoding_tick,
      buffer_removal_time_length_minus_1: buffer_removal_time_length_minus_1,
      frame_presentation_time_length_minus_1: frame_presentation_time_length_minus_1
    }

    {decoder_model_info, rest}
  end

  defp parse_operating_point(
         <<operating_point_idc::12, seq_level_idx::5, rest::bitstring>>,
         decoder_model_info,
         initial_display_delay_present_flag
       ) do
    {seq_tier, rest} = if seq_level_idx > 7, do: next_bit(rest), else: {0, rest}

    operating_point = %{
      operating_point_idc: operating_point_idc,
      seq_level_idx: seq_level_idx,
      seq_tier: seq_tier
    }

    {operating_parameters_info, rest} =
      if not is_nil(decoder_model_info) do
        {decoder_model_present_for_this_op, rest} = next_bit(rest)

        parse_operating_parameters_info(
          decoder_model_present_for_this_op == 1,
          decoder_model_info.buffer_delay_length_minus_1,
          rest
        )
      else
        {nil, rest}
      end

    <<initial_display_delay_present_for_this_op::size(initial_display_delay_present_flag),
      initial_display_delay_minus_1::size(initial_display_delay_present_for_this_op * 4),
      rest::bitstring>> =
      rest

    operating_point =
      Map.merge(operating_point, %{
        operating_parameters_info: operating_parameters_info,
        initial_display_delay_minus_1: initial_display_delay_minus_1
      })

    {operating_point, rest}
  end

  defp parse_operating_parameters_info(false, _buffer_delay_length_minus_1, rest), do: {nil, rest}

  defp parse_operating_parameters_info(true, buffer_delay_length_minus_1, rest) do
    n = buffer_delay_length_minus_1 + 1

    <<decoder_buffer_delay::size(n), encoder_buffer_delay::size(n), low_delay_mode_flag::1,
      rest::bitstring>> = rest

    operating_parameters_info = %{
      decoder_buffer_delay: decoder_buffer_delay,
      encoder_buffer_delay: encoder_buffer_delay,
      low_delay_mode_flag: low_delay_mode_flag == 1
    }

    {operating_parameters_info, rest}
  end

  defp parse_color_config(<<high_bitdepth::1, rest::bitstring>>, seq_profile) do
    {bitdepth, rest} =
      cond do
        seq_profile == 2 and high_bitdepth == 1 ->
          {twelve_bit, rest} = next_bit(rest)
          {10 + twelve_bit * 2, rest}

        seq_profile <= 2 ->
          {8 + high_bitdepth * 2, rest}

        true ->
          {8, rest}
      end

    {monochrome, rest} = if seq_profile == 1, do: {0, rest}, else: next_bit(rest)

    <<color_description_present_flag::1,
      color_primaries::size(color_description_present_flag * 8),
      transfer_characteristics::size(color_description_present_flag * 8),
      matrix_coefficients::size(color_description_present_flag * 8), rest::bitstring>> = rest

    {{subsampling_x, subsampling_y, chroma_sample_position}, rest} =
      cond do
        monochrome == 1 ->
          {_color_range, rest} = next_bit(rest)
          {{1, 1, 0}, rest}

        color_primaries == 1 and transfer_characteristics == 13 and matrix_coefficients == 0 ->
          {{0, 0, 0}, rest}

        true ->
          {_color_range, rest} = next_bit(rest)

          {{subsampling_x, subsampling_y}, rest} =
            cond do
              seq_profile == 0 ->
                {{1, 1}, rest}

              seq_profile == 1 ->
                {{0, 0}, rest}

              bitdepth == 12 ->
                <<subsampling_x::1, subsampling_y::size(subsampling_x), rest::bitstring>> = rest
                {{subsampling_x, subsampling_y}, rest}

              true ->
                {{1, 0}, rest}
            end

          if subsampling_x == 1 and subsampling_y == 1 do
            <<chroma_sample_position::2, rest::bitstring>> = rest
            {{subsampling_x, subsampling_y, chroma_sample_position}, rest}
          else
            {{subsampling_x, subsampling_y, 0}, rest}
          end
      end

    color_config = %{
      high_bitdepth: high_bitdepth == 1,
      bitdepth: bitdepth,
      monochrome: monochrome == 1,
      subsampling_x: subsampling_x,
      subsampling_y: subsampling_y,
      chroma_sample_position: chroma_sample_position
    }

    {color_config, rest}
  end
end

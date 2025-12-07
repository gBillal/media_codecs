defmodule MediaCodecs.AV1.OBU.Header do
  @moduledoc """
  Module describing an AV1 OBU (Open Bitstream Unit) header.
  """

  @type obu_extension_header :: %{
          temporal_id: integer(),
          spatial_id: integer()
        }

  @type obu_type ::
          :sequence_header
          | :temporal_delimiter
          | :frame_header
          | :tile_group
          | :metadata
          | :frame
          | :redudant_frame_header
          | :tile_list
          | :padding
          | :reserved

  @type t :: %__MODULE__{
          type: obu_type(),
          extension_flag: boolean(),
          has_size: boolean(),
          extension_header: obu_extension_header() | nil
        }

  defstruct [
    :type,
    :extension_flag,
    :has_size,
    :extension_header
  ]

  @doc """
  Parses an OBU header.

      iex> MediaCodecs.AV1.OBU.Header.parse(<<18, 0>>)
      {%MediaCodecs.AV1.OBU.Header{
        type: :temporal_delimiter,
        extension_flag: false,
        has_size: true,
        extension_header: nil
      }, <<0>>}

      iex> MediaCodecs.AV1.OBU.Header.parse(<<10, 10, 0, 0, 0, 3, 54, 57>>)
      {%MediaCodecs.AV1.OBU.Header{
        type: :sequence_header,
        extension_flag: false,
        has_size: true,
        extension_header: nil
      }, <<10, 0, 0, 0, 3, 54, 57>>}

      iex> MediaCodecs.AV1.OBU.Header.parse(<<31, 200, 0, 0, 0, 3, 54, 57>>)
      {%MediaCodecs.AV1.OBU.Header{
        type: :frame_header,
        extension_flag: true,
        has_size: true,
        extension_header: %{spatial_id: 1, temporal_id: 6}
      }, <<0, 0, 0, 3, 54, 57>>}

      iex> MediaCodecs.AV1.OBU.Header.parse(<<31>>)
      ** (ArgumentError) Data too short to parse AV1 OBU extension header
  """
  @spec parse(binary()) :: {t(), binary()}
  def parse(
        <<0::1, type::4, extension_header::1, has_size::1, _reserved::1, rest::binary>> = _data
      ) do
    {obu_extension_header, rest} = parse_extension_header(extension_header, rest)

    {%__MODULE__{
       type: obu_type(type),
       extension_flag: extension_header == 1,
       has_size: has_size == 1,
       extension_header: obu_extension_header
     }, rest}
  end

  def parse(data) do
    raise ArgumentError, "Data too short to parse AV1 OBU header: #{byte_size(data)} bytes"
  end

  defp parse_extension_header(
         1 = _exists,
         <<temporal_id::3, spatial_id::2, _reserved::3, rest::binary>>
       ) do
    {%{temporal_id: temporal_id, spatial_id: spatial_id}, rest}
  end

  defp parse_extension_header(0, data), do: {nil, data}

  defp parse_extension_header(_, _data) do
    raise ArgumentError, "Data too short to parse AV1 OBU extension header"
  end

  defp obu_type(1), do: :sequence_header
  defp obu_type(2), do: :temporal_delimiter
  defp obu_type(3), do: :frame_header
  defp obu_type(4), do: :tile_group
  defp obu_type(5), do: :metadata
  defp obu_type(6), do: :frame
  defp obu_type(7), do: :redudant_frame_header
  defp obu_type(8), do: :tile_list
  defp obu_type(15), do: :padding
  defp obu_type(_), do: :reserved
end

defmodule MediaCodecs.AV1 do
  @moduledoc """
  AV1 utilities.
  """

  alias MediaCodecs.Helper

  @doc """
  Split a binary stream into a list of OBUs.
  """
  @spec obus(binary()) :: {:ok, [binary()]} | {:error, atom()}
  def obus(stream), do: do_obus(stream, [])

  defp do_obus(<<>>, acc), do: Enum.reverse(acc)
  defp do_obus(<<_::6, 0::1, _::bitstring>>, _acc), do: {:error, :missing_obu_size}

  defp do_obus(data, acc) do
    rest =
      case data do
        <<_::5, 1::1, _::10, rest::binary>> -> rest
        <<_::5, 0::1, _::2, rest::binary>> -> rest
        _ -> {:error, :invalid_obu}
      end

    {size, rest} = Helper.leb128_decode(rest)
    total_size = byte_size(data) - byte_size(rest) + size

    do_obus(binary_part(data, total_size, byte_size(data) - total_size), [
      binary_part(data, 0, total_size) | acc
    ])
  end
end

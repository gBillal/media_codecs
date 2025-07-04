defmodule MediaCodecs.Helper do
  @moduledoc false

  import Bitwise

  @spec exp_golomb_uint(bitstring(), non_neg_integer()) ::
          {non_neg_integer(), bitstring()}
  @spec exp_golomb_uint(bitstring()) :: {non_neg_integer(), bitstring()}
  def exp_golomb_uint(binary, zeros_count \\ 0)

  def exp_golomb_uint(<<0::1, data::bitstring>>, zeros_count) do
    exp_golomb_uint(data, zeros_count + 1)
  end

  def exp_golomb_uint(data, zeros_count) do
    <<number::size(zeros_count + 1), data::bitstring>> = data
    {number - 1, data}
  end

  @spec exp_golomb_int(bitstring(), non_neg_integer()) :: {integer(), bitstring()}
  @spec exp_golomb_int(bitstring()) :: {integer(), bitstring()}
  def exp_golomb_int(binary, zeros_count \\ 0)

  def exp_golomb_int(<<0::1, data::bitstring>>, zeros_count) do
    exp_golomb_int(data, zeros_count + 1)
  end

  def exp_golomb_int(data, zeros_count) do
    <<number::size(zeros_count + 1), data::bitstring>> = data
    number = number - 1

    if rem(number, 2) == 0 do
      {-div(number, 2), data}
    else
      {div(number + 1, 2), data}
    end
  end

  @spec emulation_prevention_remove(bitstring()) :: bitstring()
  def emulation_prevention_remove(data) do
    :binary.split(data, <<0, 0, 3>>, [:global]) |> Enum.join(<<0, 0>>)
  end

  @doc """
  Decodes a Base128 variable-length integer from the given binary data.
  """
  def base128_varint_decode(data) do
    do_base128_varint_decode(data, 0)
  end

  @doc """
  Encodes an integer into a Base128 variable-length binary.
  """
  @spec base128_varint_encode(non_neg_integer()) :: binary()
  def base128_varint_encode(0), do: <<0>>

  def base128_varint_encode(integer) do
    integer |> do_base128_varint_encode([]) |> :binary.list_to_bin()
  end

  def bool_to_int(true), do: 1
  def bool_to_int(_other), do: 0

  defp do_base128_varint_decode(<<stop_bit::1, length::7, rest::binary>>, acc) do
    acc = acc <<< 7 ||| length

    case stop_bit do
      1 -> do_base128_varint_decode(rest, acc)
      0 -> {acc, rest}
    end
  end

  defp do_base128_varint_encode(0, acc) do
    List.update_at(acc, -1, &(&1 &&& 0x7F))
  end

  defp do_base128_varint_encode(integer, acc) do
    value = 0x80 ||| (integer &&& 0x7F)
    do_base128_varint_encode(integer >>> 7, [value | acc])
  end
end

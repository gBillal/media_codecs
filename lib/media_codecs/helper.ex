defmodule MediaCodecs.Helper do
  @moduledoc false

  import Bitwise

  @compile {:inline,
            bool_to_int: 1,
            exp_golomb_uint: 1,
            exp_golomb_int: 1,
            leb128_decode: 1,
            uvlc: 1,
            uvlc: 2,
            next_bit: 1}

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

  @spec uvlc(bitstring(), non_neg_integer()) :: {non_neg_integer(), bitstring()}
  @spec uvlc(bitstring()) :: {non_neg_integer(), bitstring()}
  def uvlc(binary, zeros_count \\ 0)

  def uvlc(<<0::1, data::bitstring>>, zeros_count), do: uvlc(data, zeros_count + 1)
  def uvlc(data, zeros_count) when zeros_count >= 32, do: {(1 <<< 32) - 1, data}

  def uvlc(data, zeros_count) do
    <<number::size(zeros_count + 1), data::bitstring>> = data
    {number + (1 <<< zeros_count) - 1, data}
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

  @doc """
  Decodes an unsigned integer represented by a variable number of little-endian bytes.

      iex> MediaCodecs.Helper.leb128_decode(<<229, 142, 38>>)
      {624485, <<>>}

      iex> MediaCodecs.Helper.leb128_decode(<<172, 2>>)
      {300, <<>>}

      iex> MediaCodecs.Helper.leb128_decode(<<127>>)
      {127, <<>>}
  """
  @spec leb128_decode(binary()) :: {non_neg_integer(), binary()}
  def leb128_decode(<<stop::1, value::7, rest::binary>>, acc \\ 0, idx \\ 0) do
    acc = value |> Bitwise.bsl(idx * 7) |> Bitwise.bor(acc)

    case stop do
      0 -> {acc, rest}
      1 -> leb128_decode(rest, acc, idx + 1)
    end
  end

  @doc """
  Encodes an unsigned integer into a variable number of little-endian bytes.

      iex> MediaCodecs.Helper.leb128_encode(624485)
      <<229, 142, 38>>

      iex> MediaCodecs.Helper.leb128_encode(300)
      <<172, 2>>

      iex> MediaCodecs.Helper.leb128_encode(127)
      <<127>>
  """
  @spec leb128_encode(non_neg_integer()) :: binary()
  def leb128_encode(value) do
    byte = Bitwise.band(value, 0x7F)
    rest = Bitwise.bsr(value, 7)

    if rest > 0 do
      IO.iodata_to_binary([Bitwise.bor(byte, 0x80) | leb128_encode(rest)])
    else
      <<byte>>
    end
  end

  @spec bool_to_int(boolean()) :: 0 | 1
  def bool_to_int(true), do: 1
  def bool_to_int(_other), do: 0

  @spec next_bit(bitstring()) :: {0 | 1, bitstring()}
  def next_bit(<<bit::1, rest::bitstring>>), do: {bit, rest}

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

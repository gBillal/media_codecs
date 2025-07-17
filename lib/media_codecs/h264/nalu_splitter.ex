defmodule MediaCodecs.H264.NaluSplitter do
  @moduledoc """
  Split a bytestream to a list of nalus.
  """

  @type input_structure :: :annexb | :elementary | {:elementary, size :: non_neg_integer()}

  @type t :: %__MODULE__{
          unprocessed_data: binary(),
          input_structure: input_structure(),
          prefix_pattern: :binary.cp()
        }

  defstruct unprocessed_data: <<>>, input_structure: :annexb, prefix_pattern: nil

  @annexb_prefix <<0, 0, 1>>

  @doc """
  Creates a new NaluSplitter.

  ## Options

    - `:input_type` - The type of input data, can be `:annexb`, `:elementary`, or `{:elementary, size}`.
      Defaults to `:annexb`.
  """
  @spec new(input_structure()) :: t()
  def new(input_structure \\ :annexb) do
    %__MODULE__{
      input_structure: input_structure,
      prefix_pattern: :binary.compile_pattern([<<0, 0, 0, 1>>, <<0, 0, 1>>])
    }
  end

  @doc """
  Processes the given data and splits it into nalus.
  """
  @spec process(binary(), t()) :: {list(binary()), t()}
  def process(data, %__MODULE__{} = splitter) do
    nalus =
      do_split_data(
        splitter.input_structure,
        splitter.unprocessed_data <> data,
        splitter.prefix_pattern
      )

    {unprocessed, nalus} = List.pop_at(nalus, -1)

    unprocessed =
      case splitter.input_structure do
        :annexb -> @annexb_prefix <> unprocessed
        _other -> unprocessed
      end

    {nalus, %__MODULE__{splitter | unprocessed_data: unprocessed}}
  end

  @doc """
  Flushes any unprocessed data from the splitter.
  """
  @spec flush(t()) :: list()
  def flush(%__MODULE__{unprocessed_data: <<>>}), do: []

  def flush(%__MODULE__{input_structure: :annexb} = splitter) do
    do_split_data(:annexb, splitter.unprocessed_data, splitter.prefix_pattern)
  end

  def flush(%__MODULE__{}), do: []

  defp do_split_data(:annexb, data, pattern) do
    :binary.split(data, pattern, [:global, :trim_all])
  end

  defp do_split_data(:elementary, data, pattern) do
    do_split_data({:elementary, 4}, data, pattern)
  end

  defp do_split_data({:elementary, prefix_size}, data, pattern) do
    case data do
      <<nalu_size::integer-size(prefix_size * 8), nalu::binary-size(nalu_size), rest::binary>> ->
        [nalu | do_split_data({:elementary, prefix_size}, rest, pattern)]

      data ->
        [data]
    end
  end
end

defmodule MediaCodecs.H265.NaluSplitter do
  @moduledoc """
  Split a bytestream to a list of nalus.
  """

  alias MediaCodecs.H264.NaluSplitter

  @doc """
  Creates a new NaluSplitter.

  ## Options

    - `:input_type` - The type of input data, can be `:annexb`, `:elementary`, or `{:elementary, size}`.
      Defaults to `:annexb`.
  """
  @spec new(NaluSplitter.input_structure()) :: NaluSplitter.t()
  defdelegate new(input_structure \\ :annexb), to: NaluSplitter

  @doc """
  Processes the given data and splits it into nalus.
  """
  @spec process(NaluSplitter.t(), binary()) :: {list(binary()), NaluSplitter.t()}
  defdelegate process(splitter, data), to: NaluSplitter

  @doc """
  Flushes any unprocessed data from the splitter.
  """
  @spec flush(NaluSplitter.t()) :: list()
  defdelegate flush(splitter), to: NaluSplitter
end

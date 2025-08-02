defmodule MediaCodecs.H265.AccessUnitSplitter do
  @moduledoc """
  Moodule resposible for splitting a stream of NAL units into access units.
  """

  require Logger

  alias MediaCodecs.H265.NALU

  @type access_unit :: [binary()]

  @type t :: %__MODULE__{
          access_unit: access_unit(),
          stage: :first | :second,
          previous_nalu_type: integer() | nil
        }

  @non_vcl_nalus_at_au_beginning [32, 33, 34, 39]
  @non_vcl_nalus_at_au_end [36, 37, 38, 40]

  defstruct access_unit: [], stage: :first, previous_nalu_type: nil

  @doc """
  Creates a new access unit splitter.
  """
  @spec new() :: t()
  def new(), do: %__MODULE__{}

  @doc """
  Processes a NAL unit.

  If the current NAL unit starts a new access unit, it returns the completed access unit.
  If the NAL unit is part of the current access unit, it returns `nil`.
  """
  @spec process(nalu :: binary(), t()) :: {access_unit() | nil, t()}
  def process(nalu, %{stage: :first} = splitter) do
    nalu_type = NALU.type(nalu, :integer)
    first_slice? = nalu_type < 32 and first_slice?(nalu)

    # Conditions:
    #   * VCL nalu and first slice
    #   * NALU is aud and is the first one
    #   * NALU is vps/sps/pps/prefix sei
    #   * NALU has a type in 41..44 or 48...55
    valid? =
      first_slice? or (nalu_type == 35 and splitter.access_unit == []) or
        nalu_type in @non_vcl_nalus_at_au_beginning or
        nalu_type in 41..44 or
        nalu_type in 48..55

    stage = if first_slice?, do: :second, else: :first

    if valid? do
      {nil,
       %{
         splitter
         | stage: stage,
           access_unit: [nalu | splitter.access_unit],
           previous_nalu_type: nalu_type
       }}
    else
      Logger.warning("[AccessUnitSplitter]: Invalid transition, ignore nal unit")
      {nil, splitter}
    end
  end

  def process(nalu, %{stage: :second} = splitter) do
    nalu_type = NALU.type(nalu, :integer)
    first_slice? = nalu_type < 32 and first_slice?(nalu)

    # New access units conditions:
    #   * VCL nalu and first slice
    #   * NALU is aud or vps/sps/pps/prefix sei
    new_au? = first_slice? or nalu_type == 35 or nalu_type in @non_vcl_nalus_at_au_beginning

    # Same access units conditions:
    #   * The nalu is the same type as the previous one
    #   * NALU is fd, end of sequence, end of bitstream or suffix sei
    #   * NALU has type 45 to 47 or 56 to 63
    same_au? =
      nalu_type == splitter.previous_nalu_type or nalu_type in @non_vcl_nalus_at_au_end or
        nalu_type in 45..47 or nalu_type in 56..63

    cond do
      new_au? ->
        {Enum.reverse(splitter.access_unit),
         %{
           splitter
           | stage: if(first_slice?, do: :second, else: :first),
             access_unit: [nalu],
             previous_nalu_type: nalu_type
         }}

      same_au? ->
        {nil,
         %{
           splitter
           | access_unit: [nalu | splitter.access_unit],
             previous_nalu_type: nalu_type
         }}

      true ->
        Logger.warning("[AccessUnitSplitter]: Invalid transition, ignore nal unit")
        {nil, splitter}
    end
  end

  @doc """
  Flushes the splitter and return the remaining nalus as an complete access unit
  """
  @spec flush(t()) :: access_unit()
  def flush(splitter), do: Enum.reverse(splitter.access_unit)

  defp first_slice?(<<_header::16, 1::1, _rest::bitstring>>), do: true
  defp first_slice?(_nalu), do: false
end

defmodule MediaCodecs.H265.NALU.SPS.ProfileTierLevel do
  @moduledoc """
  Struct describing the Profile Tier Level (PTL) of an H.265 Sequence Parameter Set (SPS).
  """

  @type t :: %__MODULE__{
          profile_space: non_neg_integer(),
          tier_flag: 0 | 1,
          profile_idc: non_neg_integer(),
          profile_compatibility_flag: non_neg_integer(),
          progressive_source_flag: 0 | 1,
          interlaced_source_flag: 0 | 1,
          non_packed_constraint_flag: 0 | 1,
          frame_only_constraint_flag: 0 | 1,
          level_idc: non_neg_integer() | nil
        }

  defstruct [
    :profile_space,
    :tier_flag,
    :profile_idc,
    :profile_compatibility_flag,
    :progressive_source_flag,
    :interlaced_source_flag,
    :non_packed_constraint_flag,
    :frame_only_constraint_flag,
    :level_idc
  ]

  @doc false
  def parse(data, profile_present?, level_present?) do
    {result, rest} = parse_profile(profile_present?, data, %__MODULE__{})

    if level_present? do
      <<level_idc::8, rest::binary>> = rest
      {%__MODULE__{result | level_idc: level_idc}, rest}
    else
      {result, rest}
    end
  end

  defp parse_profile(
         true,
         <<profile_space::2, tier_flag::1, profile_idc::5, profile_compatibility_flag::32,
           progressive_source_flag::1, interlaced_source_flag::1, non_packed_constraint_flag::1,
           frame_only_constraint_flag::1, _reserved_44bits::44, rest::binary>>,
         res
       ) do
    res = %__MODULE__{
      res
      | profile_space: profile_space,
        tier_flag: tier_flag,
        profile_idc: profile_idc,
        profile_compatibility_flag: profile_compatibility_flag,
        progressive_source_flag: progressive_source_flag,
        interlaced_source_flag: interlaced_source_flag,
        non_packed_constraint_flag: non_packed_constraint_flag,
        frame_only_constraint_flag: frame_only_constraint_flag
    }

    {res, rest}
  end

  defp parse_profile(false, data, res), do: {res, data}
end

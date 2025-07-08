defmodule MediaCodecs.MixProject do
  use Mix.Project

  @version "0.6.0"
  @github_url "https://github.com/gBillal/media_codecs"

  def project do
    [
      app: :media_codecs,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # hex
      description: "Media Codecs Utilities",
      package: package(),

      # docs
      name: "MediCodecs",
      source_url: @github_url,
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["Billal Ghilas"],
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @github_url
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md",
        "LICENSE"
      ],
      formatters: ["html"],
      source_ref: "v#{@version}",
      nest_modules_by_prefix: [
        MediaCodecs.H264,
        MediaCodecs.H265,
        MediaCodecs.MPEG4
      ],
      groups_for_modules: [
        H264: [
          ~r/MediaCodecs\.H264($|\.)/
        ],
        H265: [
          ~r/MediaCodecs\.H265($|\.)/
        ],
        MPEG4: [
          ~r/MediaCodecs\.MPEG4($|\.)/
        ]
      ]
    ]
  end
end

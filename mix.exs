defmodule HighlanderPg.MixProject do
  use Mix.Project

  def project do
    [
      app: :highlander_pg,
      version: "1.0.1",
      elixir: "~> 1.13",
      elixirc_paths: elixirc_paths(Mix.env()),
      hex: [
        api_url: "https://hex.codecodeship.com/api"
      ],
      package: package(),
      start_permanent: Mix.env() == :prod,
      docs: docs(),
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:postgrex, "~> 0.16.1 or ~> 0.17.0"},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp docs() do
    [main: "HighlanderPG"]
  end

  defp package() do
    [
      description: "There can only be one! (run a globally unique singleton process)",
      licenses: ["COMMERCIAL"],
      maintainers: ["Derek Kraan"],
      links: %{}
      # links: %{"Code Code Ship" => "https://hex.codecodeship.com/packages/highlander_pg"}
    ]
  end
end

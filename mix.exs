defmodule TaigaToSlack.Mixfile do
  use Mix.Project

  def project do
    [app: :taigatoslack,
     version: "1.0.0",
     elixir: "~> 1.6",
     name: "taigatoslack",
     description: "Get notified in Slack when something changes on Taiga",
     licences: "MIT",
     maintainers: "Appaloosa",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     package: package(),
     preferred_cli_env: [
       vcr: :test, "vcr.delete": :test, "vrc.check": :test, "vcr.show": :test
     ]
   ]
  end

  def application do
    [applications: [:logger, :cowboy, :plug, :poison, :slack],
     mod: {TaigaToSlack.Api, []}]
  end

  defp deps do
    [
      {:httpoison, "~> 0.8"},
      {:ex_doc, "~> 0.11"},
      {:earmark, ">= 0.0.0"},
      {:poison, "~> 1.5"},
      {:exvcr, "~> 0.7", only: :test},
      {:mix_test_watch, "~> 0.2", only: :dev},
      {:dogma, "~> 0.1", only: :dev},
      {:cowboy, "~> 1.0.3"},
      {:plug, "~> 1.0"},
      {:slack, "~> 0.11.0"}
    ]
  end

  defp package do
    [# These are the default files included in the package
     name: :taigatoslack,
     files: ["lib", "mix.exs", "README*", "CHANGELOG*"],
     maintainers: ["Appaloosa"],
     licenses: ["MIT"],
     links: %{"GitHub" => "https://github.com/appaloosa-store/taiga-to-slack"}]
  end
end

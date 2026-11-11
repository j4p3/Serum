defmodule Serum.Mixfile do
  use Mix.Project

  @serum_version "1.5.1"

  def project do
    [
      app: :serum,
      version: @serum_version,
      elixir: "~> 1.16",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      deps: deps(),
      package: package(),
      docs: docs(),
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  def application do
    [extra_applications: [:logger, :eex], mod: {Serum, []}]
  end

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.html": :test
      ]
    ]
  end

  defp deps do
    [
      {:mdex, "~> 0.14"},
      {:file_system, "~> 1.1"},
      {:bandit, "~> 1.14"},
      {:plug, "~> 1.20"},
      {:websock_adapter, "~> 0.5"},
      {:timex, "~> 4.0"},
      {:floki, "~> 0.38"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: [:test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false},
      {:mix_test_watch, "~> 1.4", only: :dev, runtime: false},
      {:mox, "~> 1.3", only: :test}
    ]
  end

  defp package do
    [
      name: "serum",
      description: "Yet another static website generator written in Elixir",
      maintainers: ["Eunbin Jeong"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/Dalgona/Serum",
        "Website" => "http://dalgona.github.io/Serum"
      }
    ]
  end

  defp docs do
    [
      main: "Serum",
      source_url: "https://github.com/Dalgona/Serum",
      homepage_url: "https://dalgona.github.io/Serum",
      groups_for_modules: [
        "Entry Points": [
          Serum,
          Serum.Build,
          Serum.DevServer,
          Serum.DevServer.Prompt
        ],
        "Core Types": [
          Serum.File,
          Serum.Fragment,
          Serum.Page,
          Serum.Post,
          Serum.PostList,
          Serum.Project,
          Serum.Result,
          Serum.Tag,
          Serum.Template
        ],
        "Built-in Plugins": [
          Serum.Plugins.LiveReloader,
          Serum.Plugins.PreviewGenerator,
          Serum.Plugins.SitemapGenerator,
          Serum.Plugins.TableOfContents
        ],
        "Extension Development": [
          Serum.HtmlTreeHelper,
          Serum.Plugin,
          Serum.Theme
        ]
      ],
      nest_modules_by_prefix: [
        Serum,
        Serum.Plugins
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["test/support", "lib"]
  defp elixirc_paths(_), do: ["lib"]
end

defmodule Torrentex.MixProject do
  use Mix.Project

  def project do
    [
      app: :torrentex,
      version: "0.1.0",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [coveralls: :test],
      deps: deps(),
      escript: [main_module: Torrentex.Cli],
      dialyzer: [
        plt_add_deps: :apps_direct,
        flags: [:unmatched_returns, :error_handling, :race_conditions, :no_opaque]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :crypto, :inets, :ssl],
      # mod: {Torrentex.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:bento, "~> 0.9.2"},
      {:stream_data, "~> 0.5", only: :test},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:excoveralls, "~> 0.10", only: :test}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end

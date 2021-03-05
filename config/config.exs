import Config

config :logger,
  backends: [:console],
  format: "$time $metadata [$level] $message \n",
  metadata: [:error_code, :peer],
  compile_time_purge_matching: [
    [level_lower_than: :info]
  ]

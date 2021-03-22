import Config


config :logger,
  backend: [:console],
  format: "$time $metadata [$level] $message \n",
  metadata: [:error_code, :peer, :mfa, :crash_reason],
  compile_time_purge_matching: [
    [level_lower_than: :info]
  ]

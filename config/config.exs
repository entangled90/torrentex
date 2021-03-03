import Config

config :logger, :console,
  format: "$time $metadata [$level] $message \n",
  metadata: [:error_code, :peer]

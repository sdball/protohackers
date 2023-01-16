import Config

config :protohackers, Protohackers.MobInTheMiddleServer,
  host: ~c(localhost),
  port: 11238

import_config "#{config_env()}.exs"

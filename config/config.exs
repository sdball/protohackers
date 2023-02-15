import Config

config :smoke_test, port: 11235
config :prime_time, port: 11236
config :means_to_an_end, port: 11237
config :budget_chat, port: 11238
config :unusual_database_program, port: 11239
config :mob_in_the_middle, port: 11240, target: [host: ~c(localhost), port: 11238]
config :speed_daemon, port: 11241

import_config "#{config_env()}.exs"

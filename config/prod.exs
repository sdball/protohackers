import Config

config :smoke_test, port: 5000
config :prime_time, port: 5000
config :means_to_an_end, port: 5000
config :budget_chat, port: 5000
config :unusual_database_program, port: 5000
config :mob_in_the_middle, port: 5000, target: [host: ~c(chat.protohackers.com), port: 16963]
config :speed_daemon, port: 5000
config :line_reversal, port: 5000

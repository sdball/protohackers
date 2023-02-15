# SmokeTest

[Protohackers 0: Smoke Test](https://protohackers.com/problem/0) solved in Elixir

## Usage

Run the server (e.g. `mix run --no-halt`)

While the server is running you can netcat data to the server port and it will be
echoed back.

```
$ echo "hello there" | nc localhost 11235
```

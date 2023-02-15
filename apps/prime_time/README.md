# Prime Time

[Protohackers 1: Prime Time](https://protohackers.com/problem/1) solved in
Elixir

## Usage

Run the PrimeTime server e.g. `mix run --no-halt`

While the server is running it will answer requests as expected by the problem
definition.

```shell
$ echo '{"method":"isPrime","number":5}' | nc 169.155.48.93 11236
{"method":"isPrime","prime":true}
```

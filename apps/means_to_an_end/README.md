# Means To An End

[Protohackers 2: Means to An End](https://protohackers.com/problem/2) solved
in Elixir

## Usage

Run the "Means to an End" server e.g. `mix run --no-halt`

The server accepts asset prices with timestamps and returns queried averages.

To test manually with netcat you can use -n -e to echo raw bytes

* `echo -n` : do not append newline
* `echo -e` : handle escape codes e.g. `\x49` to make a hex 0x49 byte

```
$ echo -n -e "\x49\x00\x00\x30\x39\x00\x00\x00\x65" | nc localhost 11237
INSERT - 12345 - 101
```

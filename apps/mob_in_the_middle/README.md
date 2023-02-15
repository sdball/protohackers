# MobInTheMiddle

[Protohackers 5: Mob in the Middle](https://protohackers.com/problem/5) solved
in Elixir

## Usage

Run the BudgetChat server AND the MobInTheMiddle server locally e.g. `mix run --no-halt`

While the server is running you can telnet to the server port to start an
interactive chat session. After being prompted for a name you will join the chat
room and anything you type will be sent as a message.

BUT sneakily the MobInTheMiddle server will rewrite any "Boguscoin" addresses
to/from your client.

Use multiple telnet sessions to get the actual chat experience.

```
telnet localhost 11240
```

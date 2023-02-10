defmodule Protohackers.MITM.Boguscoin do
  @boguscoin ~r/^7[a-zA-Z0-9]{25,34}$/
  @target_coin "7YWHMfk9JZe0LM0g1ZauHuiSxhI"

  def rewrite(string) when is_binary(string) do
    string
    |> String.split(" ")
    |> Enum.map(&Regex.replace(@boguscoin, &1, "7YWHMfk9JZe0LM0g1ZauHuiSxhI"))
    |> Enum.join(" ")
  end
end

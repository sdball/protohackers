defmodule PrimeNumbers do
  def is_prime?(2), do: true
  def is_prime?(3), do: true

  def is_prime?(x) when is_integer(x) and x > 3 do
    from = 2
    to = trunc(:math.sqrt(x))
    n_total = to - from + 1

    n_tried =
      Enum.take_while(from..to, fn i -> rem(x, i) != 0 end)
      |> Enum.count()

    n_total == n_tried
  end

  def is_prime?(x) when is_integer(x), do: false

  def is_prime?(x) when is_float(x), do: false

  def is_prime?(_anything), do: false
end

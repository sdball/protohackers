defmodule PrimeFactors do
  def of(n) do
    factors(n, div(n, 2)) |> Enum.filter(&is_prime?/1) |> Enum.reverse()
  end

  def is_prime?(0), do: false
  def is_prime?(1), do: false
  def is_prime?(n) when is_integer(n) and n < 1, do: false

  def is_prime?(n) when is_integer(n) do
    factors(n, div(n, 2)) == [1]
  end

  def is_prime?(_other), do: false

  defp factors(1, _), do: [1]
  defp factors(_, 1), do: [1]

  defp factors(n, i) do
    if rem(n, i) == 0 do
      [i | factors(n, i - 1)]
    else
      factors(n, i - 1)
    end
  end
end

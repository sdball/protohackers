Benchee.run(%{
  "PrimeFactors" => fn -> PrimeFactors.is_prime?(86358305) end,
  "PrimeNumbers" => fn -> PrimeNumbers.is_prime?(86358305) end
}, time: 3)

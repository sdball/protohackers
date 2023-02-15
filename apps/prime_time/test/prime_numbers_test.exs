defmodule PrimeNumbersTest do
  use ExUnit.Case, async: true

  test "zero is not prime" do
    assert PrimeNumbers.is_prime?(0) == false
  end

  test "negatives are not prime" do
    assert PrimeNumbers.is_prime?(-3) == false
  end

  test "identifies prime numbers and composite numbers" do
    assert PrimeNumbers.is_prime?(1) == false
    assert PrimeNumbers.is_prime?(2) == true
    assert PrimeNumbers.is_prime?(3) == true
    assert PrimeNumbers.is_prime?(4) == false
    assert PrimeNumbers.is_prime?(5) == true
    assert PrimeNumbers.is_prime?(16) == false
    assert PrimeNumbers.is_prime?(17) == true
    assert PrimeNumbers.is_prime?(59) == true
    assert PrimeNumbers.is_prime?(60) == false
    assert PrimeNumbers.is_prime?(61) == true
    assert PrimeNumbers.is_prime?(210) == false
    assert PrimeNumbers.is_prime?(211) == true
  end

  test "floats are not prime" do
    assert PrimeNumbers.is_prime?(1.123) == false
    assert PrimeNumbers.is_prime?(2.000) == false
  end

  test "words are not prime" do
    assert PrimeNumbers.is_prime?("two") == false
  end
end

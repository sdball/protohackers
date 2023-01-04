defmodule PrimeFactorsTest do
  use ExUnit.Case, async: true

  test "zero is not prime" do
    assert PrimeFactors.is_prime?(0) == false
  end

  test "negatives are not prime" do
    assert PrimeFactors.is_prime?(-3) == false
  end

  test "identifies prime numbers and composite numbers" do
    assert PrimeFactors.is_prime?(1) == false
    assert PrimeFactors.is_prime?(2) == true
    assert PrimeFactors.is_prime?(3) == true
    assert PrimeFactors.is_prime?(4) == false
    assert PrimeFactors.is_prime?(5) == true
    assert PrimeFactors.is_prime?(16) == false
    assert PrimeFactors.is_prime?(17) == true
    assert PrimeFactors.is_prime?(59) == true
    assert PrimeFactors.is_prime?(60) == false
    assert PrimeFactors.is_prime?(61) == true
    assert PrimeFactors.is_prime?(210) == false
    assert PrimeFactors.is_prime?(211) == true
  end

  test "floats are not prime" do
    assert PrimeFactors.is_prime?(1.123) == false
    assert PrimeFactors.is_prime?(2.000) == false
  end

  test "words are not prime" do
    assert PrimeFactors.is_prime?("two") == false
  end

  test "determines prime factors of a given number" do
    assert PrimeFactors.of(3) == []
    assert PrimeFactors.of(9) == [3]
    assert PrimeFactors.of(10) == [2, 5]
    assert PrimeFactors.of(16) == [2]
    assert PrimeFactors.of(21) == [3, 7]
    assert PrimeFactors.of(99) == [3, 11]
    assert PrimeFactors.of(210) == [2, 3, 5, 7]
    assert PrimeFactors.of(211) == []
  end
end

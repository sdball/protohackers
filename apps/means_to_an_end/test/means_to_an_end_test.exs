defmodule MeansToAnEndTest do
  use ExUnit.Case

  describe "asset pricing history and calculation" do
    test "track a list of timestamped prices" do
      history = %{}
      history = MeansToAnEnd.insert(history, 12345, 101)
      assert history |> Enum.into([]) |> Enum.sort() == [{12345, 101}]

      history = MeansToAnEnd.insert(history, 12346, 100)
      assert history |> Enum.into([]) |> Enum.sort() == [{12345, 101}, {12346, 100}]

      history = MeansToAnEnd.insert(history, 12347, 102)
      assert history |> Enum.into([]) |> Enum.sort() == [{12345, 101}, {12346, 100}, {12347, 102}]
    end

    test "query an average price between timestamps" do
      history = %{
        12348 => 200,
        12347 => 102,
        12346 => 100,
        12345 => 101
      }

      average = MeansToAnEnd.query(history, 12345, 12347)
      assert average == 101
    end

    test "large numbers are queried properly" do
      history = %{
        903_773_005 => 4_294_967_284,
        903_870_526 => 4_294_967_294,
        903_928_433 => 4_294_967_278,
        903_968_073 => 4_294_967_286,
        904_037_196 => 4_294_967_275,
        904_064_981 => 4_294_967_261,
        904_122_415 => 4_294_967_253,
        904_184_004 => 4_294_967_238,
        904_210_902 => 4_294_967_240,
        904_260_916 => 4_294_967_241,
        904_277_328 => 4_294_967_236,
        904_283_271 => 4_294_967_240,
        904_343_127 => 4_294_967_240,
        904_351_616 => 4_294_967_228,
        904_364_965 => 4_294_967_236,
        904_438_718 => 4_294_967_228,
        904_440_224 => 4_294_967_225,
        904_465_848 => 4_294_967_216,
        904_533_050 => 4_294_967_216,
        904_601_999 => 4_294_967_204,
        904_624_501 => 4_294_967_188,
        904_628_298 => 4_294_967_170,
        904_683_950 => 4_294_967_178,
        904_725_601 => 4_294_967_173,
        904_809_612 => 4_294_967_170,
        904_888_252 => 4_294_967_161
      }

      average = MeansToAnEnd.query(history, 903_773_005, 904_888_252)
      assert average == 4_294_967_229
    end

    test "queries outside of given timestamps return 0" do
      history = %{
        12348 => 200,
        12347 => 102,
        12346 => 100,
        12345 => 101
      }

      average = MeansToAnEnd.query(history, 1000, 2000)
      assert average == 0
    end

    test "queries with out of order timestamps return 0" do
      history = %{
        12348 => 200,
        12347 => 102,
        12346 => 100,
        12345 => 101
      }

      average = MeansToAnEnd.query(history, 12347, 12345)
      assert average == 0
    end
  end

  describe "tracking asset prices per client" do
    test "a client can track asset prices and query average" do
      port = Application.get_env(:means_to_an_end, :port)
      {:ok, socket} = :gen_tcp.connect('localhost', port, [:binary, active: false])
      :gen_tcp.send(socket, insert(timestamp: 12345, price: 101))
      :gen_tcp.send(socket, insert(timestamp: 12346, price: 102))
      :gen_tcp.send(socket, insert(timestamp: 12347, price: 100))
      :gen_tcp.send(socket, query(min: 12345, max: 12347))
      {:ok, <<resp::signed-integer-32>>} = :gen_tcp.recv(socket, 0)
      assert resp == 101
    end

    test "invalid requests are ignored" do
      port = Application.get_env(:means_to_an_end, :port)
      {:ok, socket} = :gen_tcp.connect('localhost', port, [:binary, active: false])
      :gen_tcp.send(socket, insert(timestamp: 12345, price: 101))
      :gen_tcp.send(socket, insert(timestamp: 12346, price: 102))
      :gen_tcp.send(socket, insert(timestamp: 12347, price: 100))
      :gen_tcp.send(socket, invalid())
      :gen_tcp.send(socket, query(min: 12345, max: 12347))
      {:ok, <<resp::signed-integer-32>>} = :gen_tcp.recv(socket, 0)
      assert resp == 101
    end

    test "reinserting over the same timestamp overwrites data" do
      port = Application.get_env(:means_to_an_end, :port)
      {:ok, socket} = :gen_tcp.connect('localhost', port, [:binary, active: false])
      :gen_tcp.send(socket, insert(timestamp: 12345, price: 101))
      :gen_tcp.send(socket, insert(timestamp: 12345, price: 300))
      :gen_tcp.send(socket, query(min: 12345, max: 12345))
      {:ok, <<resp::signed-integer-32>>} = :gen_tcp.recv(socket, 0)
      assert resp == 300
    end

    test "querying data outside of given timestamps returns 0" do
      port = Application.get_env(:means_to_an_end, :port)
      {:ok, socket} = :gen_tcp.connect('localhost', port, [:binary, active: false])
      :gen_tcp.send(socket, insert(timestamp: 12345, price: 101))
      :gen_tcp.send(socket, insert(timestamp: 12345, price: 300))
      :gen_tcp.send(socket, query(min: 1000, max: 2000))
      {:ok, <<resp::signed-integer-32>>} = :gen_tcp.recv(socket, 0)
      assert resp == 0
    end

    test "querying data with out of order timestamps returns 0 as the average" do
      port = Application.get_env(:means_to_an_end, :port)
      {:ok, socket} = :gen_tcp.connect('localhost', port, [:binary, active: false])
      :gen_tcp.send(socket, insert(timestamp: 1000, price: 123))
      :gen_tcp.send(socket, insert(timestamp: 1111, price: 123))
      :gen_tcp.send(socket, insert(timestamp: 1, price: 123))
      :gen_tcp.send(socket, insert(timestamp: 9999, price: 123))
      :gen_tcp.send(socket, query(min: 1500, max: 1000))
      {:ok, <<resp::signed-integer-32>>} = :gen_tcp.recv(socket, 0)
      assert resp == 0
    end

    test "querying treats timestamps and prices as signed 32 bit integers" do
      port = Application.get_env(:means_to_an_end, :port)
      {:ok, socket} = :gen_tcp.connect('localhost', port, [:binary, active: false])
      :gen_tcp.send(socket, insert(timestamp: 12345, price: -300))
      :gen_tcp.send(socket, insert(timestamp: 12346, price: 500))
      :gen_tcp.send(socket, query(min: 12345, max: 12346))
      {:ok, <<resp::signed-integer-32>>} = :gen_tcp.recv(socket, 0)
      assert resp == 100
    end
  end

  defp insert(timestamp: timestamp, price: price) do
    <<"I", timestamp::signed-integer-32, price::signed-integer-32>>
  end

  defp query(min: mintime, max: maxtime) do
    <<"Q", mintime::signed-integer-32, maxtime::signed-integer-32>>
  end

  defp invalid() do
    <<"Z", 0::signed-integer-64>>
  end
end

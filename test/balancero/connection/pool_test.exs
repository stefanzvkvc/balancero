defmodule Balancero.Connection.PoolTest do
  use ExUnit.Case, async: false

  setup do
    host = "127.0.0.1"
    port = 1234
    opts = []
    TestServer.start_link(port)
    start_supervised({Registry, name: :balancero_connections_registry, keys: :unique})
    start_supervised({Phoenix.PubSub, name: Balancero.PubSub})

    start_supervised(
      {Balancero.Connection.Tracker,
       [name: Balancero.Connection.Tracker, pubsub_server: Balancero.PubSub]}
    )

    {:ok, host: host, port: port, opts: opts}
  end

  test "supervisor is started" do
    # then
    {:ok, _pid} = Balancero.Connection.Pool.start_link([])
  end

  test "child is started", %{host: host, port: port, opts: opts} do
    # then
    {:ok, _pid} = Balancero.Connection.Pool.start_link([])
    {:ok, _pid} = Balancero.Connection.Pool.start_child(host: host, port: port, opts: opts)
  end

  test "child is terminated", %{host: host, port: port, opts: opts} do
    # then
    {:ok, _pid} = Balancero.Connection.Pool.start_link([])
    {:ok, pid} = Balancero.Connection.Pool.start_child(host: host, port: port, opts: opts)
    :ok = Balancero.Connection.Pool.terminate_child(pid)
  end
end

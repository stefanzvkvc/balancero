defmodule Balancero.Connection.SocketTest do
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

  test "socket is started", %{host: host, port: port, opts: opts} do
    # when
    {:ok, pid} = Balancero.Connection.Socket.start_link(host: host, port: port, opts: opts)
    # give time to get connected
    Process.sleep(200)
    state = :sys.get_state(pid)
    # then
    assert not is_nil(state.mod_state.socket)
  end

  test "socket is registred", %{host: host, port: port, opts: opts} do
    # when
    {:ok, pid} = Balancero.Connection.Socket.start_link(host: host, port: port, opts: opts)
    # give time to get connected
    Process.sleep(200)
    [{registred_pid, _}] = Balancero.Connection.Socket.lookup(host)
    # then
    assert pid == registred_pid
  end
end

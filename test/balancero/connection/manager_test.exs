defmodule Balancero.Connection.ManagerTest do
  use ExUnit.Case, async: false

  setup do
    host = "127.0.0.1"
    port = 1234
    opts = []
    TestServer.start_link(port)
    nodes = LocalCluster.start_nodes("my_cluster", 2)

    for node <- nodes do
      {:ok, _} =
        :rpc.block_call(node, Supervisor, :start_link, [
          [
            {Registry, [name: :balancero_connections_registry, keys: :unique]},
            {Phoenix.PubSub, [name: Balancero.PubSub]},
            {Balancero.Connection.Tracker,
             [name: Balancero.Connection.Tracker, pubsub_server: Balancero.PubSub]},
            {Balancero.Connection.Pool, []}
          ],
          [strategy: :one_for_one]
        ])
    end

    {:ok, nodes: nodes, host: host, port: port, opts: opts}
  end

  test "manager is started", %{nodes: nodes} do
    # then
    for node <- nodes do
      {:ok, _} = :rpc.block_call(node, Balancero.Connection.Manager, :start_link, [[]])
    end
  end

  test "manager is informed about status connection", %{
    nodes: [node | _] = nodes,
    host: host,
    port: port,
    opts: opts
  } do
    # when
    for node <- nodes do
      {:ok, _} = :rpc.block_call(node, Balancero.Connection.Manager, :start_link, [[]])
    end

    {:ok, _pid} =
      :rpc.block_call(node, Balancero.Connection.Socket, :start_link, [
        [host: host, port: port, opts: opts]
      ])
    # then
    for node <- nodes do
      Process.sleep(700)
      {:ok, host} = :rpc.block_call(node, Balancero.Connection.Manager, :get_hosts, [])
      [host_data] = Map.values(host)
      assert host_data[:connections][:total] == 1
    end
  end

  test "new host is added", %{nodes: [node | _] = nodes, host: host, port: port, opts: opts} do
    # when
    for node <- nodes do
      {:ok, _} = :rpc.block_call(node, Balancero.Connection.Manager, :start_link, [[]])
    end

    # then
    :ok =
      :rpc.block_call(node, Balancero.Connection.Manager, :add, [
        [host: host, port: port, opts: opts]
      ])
  end

  test "host is removed", %{nodes: [node | _] = nodes, host: host, port: port, opts: opts} do
    # when
    for node <- nodes do
      {:ok, _} = :rpc.block_call(node, Balancero.Connection.Manager, :start_link, [[]])
    end

    for node <- nodes do
      {:ok, _pid} =
        :rpc.call(node, Balancero.Connection.Pool, :start_child, [
          [host: host, port: port, opts: opts]
        ])

      Process.sleep(200)
    end

    # then
    :ok = :rpc.block_call(node, Balancero.Connection.Manager, :remove, [host])
  end

  test "host is paused", %{nodes: [node | _] = nodes, host: host, port: port, opts: opts} do
    # when
    for node <- nodes do
      {:ok, _} = :rpc.block_call(node, Balancero.Connection.Manager, :start_link, [[]])
    end

    for node <- nodes do
      {:ok, _pid} =
        :rpc.call(node, Balancero.Connection.Pool, :start_child, [
          [host: host, port: port, opts: opts]
        ])

      Process.sleep(200)
    end

    :ok = :rpc.block_call(node, Balancero.Connection.Manager, :pause, [host])
    Process.sleep(200)
    # then
    for node <- nodes do
      {:ok, host} = :rpc.block_call(node, Balancero.Connection.Manager, :get_hosts, [])
      [host_data] = Map.values(host)
      assert host_data[:paused?]
    end
  end

  test "host is unpaused", %{nodes: [node | _] = nodes, host: host, port: port, opts: opts} do
    # when
    for node <- nodes do
      {:ok, _} = :rpc.block_call(node, Balancero.Connection.Manager, :start_link, [[]])
    end

    for node <- nodes do
      {:ok, _pid} =
        :rpc.call(node, Balancero.Connection.Pool, :start_child, [
          [host: host, port: port, opts: opts]
        ])

      Process.sleep(200)
    end

    :ok = :rpc.block_call(node, Balancero.Connection.Manager, :pause, [host])
    Process.sleep(200)

    for node <- nodes do
      {:ok, host} = :rpc.block_call(node, Balancero.Connection.Manager, :get_hosts, [])
      [host_data] = Map.values(host)
      assert host_data[:paused?]
    end

    :ok = :rpc.block_call(node, Balancero.Connection.Manager, :unpause, [host])
    Process.sleep(200)
    # then
    for node <- nodes do
      {:ok, host} = :rpc.block_call(node, Balancero.Connection.Manager, :get_hosts, [])
      [host_data] = Map.values(host)
      assert host_data[:paused?] == false
    end
  end
end

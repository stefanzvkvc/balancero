defmodule BalanceroTest do
  use ExUnit.Case, async: false

  setup do
    TestServer.start_link(1234)
    nodes = LocalCluster.start_nodes("my_cluster", 2)
    {:ok, nodes: nodes}
  end

  test "balancero is started", %{nodes: nodes} do
    # when
    result = start_balancero(nodes)
    # then
    assert Enum.all?(result, &(&1 == :ok))
  end

  test "balancero returned server", %{nodes: [node | _] = nodes} do
    # when
    start_balancero(nodes)

    Process.sleep(200)
    {:ok, server} = :rpc.block_call(node, Balancero, :get, [])
    # then
    assert is_binary(server)
  end

  test "balancero tracks client connection", %{nodes: [node | _] = nodes} do
    # when
    start_balancero(nodes)
    Process.sleep(200)
    {:ok, ref} = :rpc.block_call(node, Balancero, :track, ["127.0.0.1"])
    # then
    assert is_binary(ref)
  end

  test "balancero untracks client connection", %{nodes: [node | _] = nodes} do
    # when
    start_balancero(nodes)
    Process.sleep(200)
    {:ok, _ref} = :rpc.block_call(node, Balancero, :track, ["127.0.0.1"])
    Process.sleep(200)
    # then
    :ok = :rpc.block_call(node, Balancero, :untrack, [])
  end

  defp start_balancero(nodes) do
    server_list = [
      [
        host: "127.0.0.1",
        port: 1234,
        opts: []
      ]
    ]

    for node <- nodes do
      case :rpc.block_call(node, Balancero, :start_link, [server_list]) do
        {:ok, _} -> :ok
        _ -> :error
      end
    end
  end
end

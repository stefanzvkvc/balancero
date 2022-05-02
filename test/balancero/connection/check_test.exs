defmodule Balancero.Connection.CheckTest do
  use ExUnit.Case, async: false

  setup do
    nodes = LocalCluster.start_nodes("my_cluster", 2)

    for node <- nodes do
      {:ok, _} =
        :rpc.block_call(node, Supervisor, :start_link, [
          [
            {Phoenix.PubSub, [name: Balancero.PubSub]},
            {Balancero.Connection.Check, []}
          ],
          [strategy: :one_for_one]
        ])
    end

    {:ok, nodes: nodes}
  end

  test "state is updated with new interval", %{nodes: [node | _] = nodes} do
    # given
    new_interval = "test"
    # when
    :ok =
      :rpc.block_call(node, Balancero.Connection.Check, :set_check_interval, [
        new_interval
      ])

    # then
    for node <- nodes do
      pid = :rpc.block_call(node, Process, :whereis, [Balancero.Connection.Check])
      state = :sys.get_state(pid)
      assert state.interval == new_interval
    end
  end
end

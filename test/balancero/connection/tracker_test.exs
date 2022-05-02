defmodule Balancero.Connection.TrackerTest do
  use ExUnit.Case, async: false

  setup do
    start_supervised({Phoenix.PubSub, name: Balancero.PubSub})

    start_supervised(
      {Balancero.Connection.Tracker,
       [name: Balancero.Connection.Tracker, pubsub_server: Balancero.PubSub]}
    )

    {:ok, host: "127.0.0.1", type: :test}
  end

  test "track process", %{host: host, type: type} do
    # when
    Phoenix.PubSub.subscribe(Balancero.PubSub, Balancero.Connection.Tracker.topic())
    {:ok, _ref} = Balancero.Connection.Tracker.track(host, type)
    # then
    assert_receive {:join, _server, %{type: ^type}}
  end

  test "list tracked processes", %{host: host, type: type} do
    # when
    {:ok, _ref} = Balancero.Connection.Tracker.track(host, type)
    list = Balancero.Connection.Tracker.list()
    # then
    assert list != []
  end

  test "untrack tracked processes", %{host: host, type: type} do
    # when
    Phoenix.PubSub.subscribe(Balancero.PubSub, Balancero.Connection.Tracker.topic())
    {:ok, _ref} = Balancero.Connection.Tracker.track(host, type)
    :ok = Balancero.Connection.Tracker.untrack()
    # then
    assert_receive {:join, _server, %{type: ^type}}
    assert_receive {:leave, _server, %{type: ^type}}
  end
end

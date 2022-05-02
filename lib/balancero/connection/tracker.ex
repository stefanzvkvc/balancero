defmodule Balancero.Connection.Tracker do
  ## https://hexdocs.pm/phoenix_pubsub/Phoenix.Tracker.html
  @moduledoc false
  use Phoenix.Tracker
  require Logger

  @doc """
  The Phoenix.PubSub topic.
  """
  def topic() do
    "connection.tracker"
  end

  @doc """
  Tracks a presence.
  """
  def track(host, type) do
    Phoenix.Tracker.track(__MODULE__, self(), topic(), host, %{type: type})
  end

  @doc """
  Untracks a presence.
  """
  def untrack() do
    Phoenix.Tracker.untrack(__MODULE__, self())
  end

  @doc """
  Lists all presences tracked under a given topic.
  """
  def list() do
    Phoenix.Tracker.list(__MODULE__, topic())
  end

  @doc """
  Starts Tracker.
  """
  def start_link(opts) do
    opts = Keyword.merge([name: __MODULE__], opts)
    Phoenix.Tracker.start_link(__MODULE__, opts, opts)
  end

  @impl true
  def init(opts) do
    Logger.debug("Process initialization.")
    server = Keyword.fetch!(opts, :pubsub_server)
    {:ok, %{pubsub_server: server, node_name: Phoenix.PubSub.node_name(server)}}
  end

  @impl true
  def handle_diff(diff, state) do
    for {topic, {joins, leaves}} <- diff do
      for {key, meta} <- joins do
        msg = {:join, key, meta}
        Phoenix.PubSub.direct_broadcast!(state.node_name, state.pubsub_server, topic, msg)
      end

      for {key, meta} <- leaves do
        msg = {:leave, key, meta}
        Phoenix.PubSub.direct_broadcast!(state.node_name, state.pubsub_server, topic, msg)
      end
    end

    {:ok, state}
  end
end

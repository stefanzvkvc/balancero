defmodule Balancero.Supervisor do
  @moduledoc """
  Supervisor responsible for managing all necessary processes.
  """
  use Supervisor

  @doc """
  Starts a supervisor with the given children.
  """
  def start_link(options) do
    Supervisor.start_link(__MODULE__, options, name: __MODULE__)
  end

  @impl true
  def init(options) do
    children = [
      {Registry, name: :balancero_connections_registry, keys: :unique},
      {Phoenix.PubSub, name: Balancero.PubSub},
      {Balancero.Connection.Tracker,
       [name: Balancero.Connection.Tracker, pubsub_server: Balancero.PubSub]},
      {Balancero.Connection.Manager, []},
      {Balancero.Connection.Pool, []},
      {Balancero.Connection.Check, options}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end

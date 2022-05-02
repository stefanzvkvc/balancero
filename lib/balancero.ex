defmodule Balancero do
  @moduledoc """
  Module provides APIs such as retrieving the host based on a configured balancer strategy,
  tracking and untracking the client connection to an external service.
  """
  alias Balancero.Connection.{Tracker, Manager}

  @typedoc "Options used for `child_spec/1` and `start_link/1`"
  @type start_option :: Keyword.t()

  @doc """
  Returns a host based on the configured strategy.
  """
  def get() do
    Manager.get()
  end

  @doc """
  Tracks a consumer's presence.
  """
  @spec track(String.t()) :: {:ok, binary()} | {:error, term()}
  def track(host) do
    Tracker.track(host, :client)
  end

  @doc """
  Untracks a consumer's presence.
  """
  @spec untrack() :: :ok
  def untrack() do
    Tracker.untrack()
  end

  @doc """
  Starts a supervisor.
  """
  @spec start_link([start_option]) :: {:ok, pid} | {:error, term}
  def start_link(options) do
    Balancero.Supervisor.start_link(options)
  end

  @doc """
  Returns a specification to start a balancero under a supervisor.

  See `Supervisor`.
  """
  @spec child_spec([start_option]) :: Supervisor.child_spec()
  def child_spec(options) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [options]},
      type: :supervisor
    }
  end
end

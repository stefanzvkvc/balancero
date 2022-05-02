defmodule Balancero.Connection.Check do
  @moduledoc """
  At startup, the Check process will contact connection pool supervisor
  to initiate the process for each server address in the config list.
  It is also responsible for periodically check
  whether for all server addresses connection process is started.
  If connection process is missing, Check process will contact connection pool supervisor to start it.
  """
  use GenServer
  require Logger

  defstruct interval: nil

  @type t :: %__MODULE__{
          interval: term()
        }

  @doc """
  Gets debug option from config.
  If it is not configured, sets default value.
  """
  def get_debug_option() do
    Application.get_env(:balancero, :check_debug, [])
  end

  @doc """
  Sets debug option.
  """
  def set_debug_option(option) do
    Application.put_env(:balancero, :check_debug, option)
  end

  @doc """
  Gets check interval from config.
  If it is not configured, sets default value.
  """
  def get_check_interval() do
    Application.get_env(:balancero, :check_interval, 30_000)
  end

  @doc """
  Sets check interval.
  """
  def set_check_interval(interval) do
    Application.put_env(:balancero, :check_interval, interval)
    GenServer.cast(__MODULE__, {:set_check_interval, interval})
  end

  @doc """
  The Phoenix.PubSub topic.
  """
  def topic() do
    "connection.check"
  end

  @doc """
  Starts #{__MODULE__} process.
  """
  def start_link(init_arg) do
    options = [
      name: __MODULE__,
      debug: get_debug_option()
    ]

    GenServer.start_link(__MODULE__, init_arg, options)
  end

  @impl true
  def init(init_arg) do
    interval = get_check_interval()
    Phoenix.PubSub.subscribe(Balancero.PubSub, topic())
    state = struct(__MODULE__, interval: interval)
    {:ok, state, {:continue, {:start, init_arg}}}
  end

  @impl true
  def handle_continue({:start, init_arg}, state) do
    interval = state.interval
    Enum.each(init_arg, &Balancero.Connection.Pool.start_child(&1))
    Process.send_after(self(), :check, interval)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:set_check_interval, interval} = message, _state) do
    Phoenix.PubSub.broadcast_from(Balancero.PubSub, self(), topic(), message)
    {:noreply, %__MODULE__{interval: interval}}
  end

  @impl true
  def handle_info(:check, state) do
    interval = state.interval
    servers = Application.get_env(:balancero, :servers, [])

    Enum.each(servers, fn server ->
      host = server[:host]
      connection = Balancero.Connection.Socket.lookup(host)

      if connection == [] do
        Balancero.Connection.Pool.start_child(server)
      end
    end)

    Process.send_after(self(), :check, interval)
    {:noreply, state}
  end

  def handle_info({:set_check_interval, interval}, _state) do
    {:noreply, %__MODULE__{interval: interval}}
  end
end

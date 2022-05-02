defmodule Balancero.Connection.Socket do
  @moduledoc """
  Socket is a process responsible for creating and keeping
  connection alive.
  """
  use Connection
  require Logger
  defstruct host: nil, port: nil, opts: nil, timeout: nil, attempts: 0, socket: nil
  @registry :balancero_connections_registry

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :transient,
      shutdown: 500
    }
  end

  @doc """
  Gets debug option from config.
  If it is not configured, sets default value.
  """
  def get_debug_option() do
    Application.get_env(:balancero, :connection_debug, [])
  end

  @doc """
  Sets debug option.
  """
  def set_debug_option(option) do
    Application.put_env(:balancero, :connection_debug, option)
  end

  @doc """
  Starts #{__MODULE__} process.
  """
  def start_link([host: host, port: port, opts: opts], timeout \\ 5000) do
    options = [
      name: {:via, Registry, {@registry, host}},
      debug: get_debug_option()
    ]

    Connection.start_link(__MODULE__, {host, port, opts, timeout}, options)
  end

  @doc """
  Finds the process.
  """
  def lookup(host) do
    Registry.lookup(@registry, host)
  end

  def init({host, port, opts, timeout}) do
    state = struct(__MODULE__, host: host, port: port, opts: opts, timeout: timeout)
    {:connect, :init, state}
  end

  def connect(
        _,
        %__MODULE__{
          host: host,
          port: port,
          opts: opts,
          timeout: timeout,
          attempts: attempts,
          socket: nil
        } = state
      ) do
    attempts = attempts + 1

    with attempts when attempts <= 3 <- attempts,
         {:ok, socket} <- :gen_tcp.connect(String.to_charlist(host), port, [active: true] ++ opts, timeout) do
      Logger.debug("Connected to #{host}:#{inspect(port)}")
      Balancero.Connection.Tracker.track(host, :status)
      {:ok, %__MODULE__{state | socket: socket, attempts: 0}}
    else
      {:error, reason} ->
        Logger.warn("Error on connecting to #{host}:#{inspect(port)}. Reason: #{inspect(reason)}")
        {:backoff, 1000, %__MODULE__{state | attempts: attempts}}

      _ ->
        Logger.warn("Maximal number of connection attempts excedeed for #{host}:#{inspect(port)}")
        {:stop, :normal, state}
    end
  end

  def handle_info({:tcp_closed, _socket}, %__MODULE__{host: host, port: port} = state) do
    Logger.warn("Connection is closed with #{host}:#{inspect(port)}. Reconnecting...")
    Balancero.Connection.Tracker.untrack()
    {:connect, :reconnect, %__MODULE__{state | socket: nil}}
  end

  def handle_info(msg, state) do
    Logger.warn("Unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end
end

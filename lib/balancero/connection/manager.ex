defmodule Balancero.Connection.Manager do
  @moduledoc """
  Manager is a process responsible for keeping information up-to-date
  about current amount of connections per host.

  Manager also provides API command for getting host based on defined strategy,
  pausing/unpausing trafic towards specific host as well as adding new server
  and removing existing ones.
  """
  use GenServer
  require Logger
  defstruct hosts: %{}

  @type t :: %__MODULE__{
          hosts: hosts()
        }
  @type hosts() :: %{host() => host_info()}
  @type host :: String.t()
  @type host_info :: %{
          connections: connections(),
          paused?: boolean()
        }
  @type connections :: %{
          total: integer(),
          client: integer(),
          status: integer()
        }

  @doc """
  Gets debug option from config.
  If it is not configured, sets default value.
  """
  def get_debug_option() do
    Application.get_env(:balancero, :manager_debug, [])
  end

  @doc """
  Sets debug option.
  """
  def set_debug_option(option) do
    Application.put_env(:balancero, :manager_debug, option)
  end

  @doc """
  Gets strategy option from config.
  If it is not configured, sets default value.
  """
  def get_strategy_option() do
    Application.get_env(:balancero, :manager_strategy, :least)
  end

  @doc """
  Sets strategy option.
  """
  def set_strategy_option(option) do
    Application.put_env(:balancero, :manager_strategy, option)
  end

  @doc """
  The Phoenix.PubSub topic.
  """
  def topic() do
    "connection.manager"
  end

  @doc """
  Gets host based on defined strategy.

  ## Examples

      iex> Balancero.Connection.Manager.get()
      {:ok, "127.0.0.1"}

  """
  def get() do
    GenServer.call(__MODULE__, :get)
  end

  @doc """
  Returns hosts informations.

  ## Examples

      iex> Balancero.Connection.Manager.get_hosts()
      {:ok,
        %{
          "127.0.0.1" => %{
            connections: %{
              total: 2,
              status: 1,
              client: 1
            },
            paused?: false
          }
        }
      }

  """
  @spec get_hosts() :: {:ok, hosts()}
  def get_hosts() do
    GenServer.call(__MODULE__, :hosts)
  end

  @doc """
  Puts on pause given host.

  ## Examples

      iex> Balancero.Connection.Manager.pause("127.0.0.1")
      :ok

      iex> Balancero.Connection.Manager.pause("127.0.0.2")
      {:error, :not_found}

  """
  @spec pause(String.t()) :: :ok | {:error, atom()}
  def pause(host) do
    GenServer.call(__MODULE__, {:pause, host})
  end

  @doc """
  Unpauses given host.

  ## Examples

      iex> Balancero.Connection.Manager.unpause("127.0.0.1")
      :ok

      iex> Balancero.Connection.Manager.unpause("127.0.0.2")
      {:error, :not_found}

  """
  @spec unpause(String.t()) :: :ok | {:error, atom()}
  def unpause(host) do
    GenServer.call(__MODULE__, {:unpause, host})
  end

  @doc """
  Adds server.

  ## Examples

      iex> Balancero.Connection.Manager.add([host: "127.0.0.1", port: 1234, options: []])
      :ok

  """
  @spec add(list()) :: :ok
  def add(server) do
    GenServer.call(__MODULE__, {:add, server})
  end

  @doc """
  Removes host from manager's state.

  ## Examples

      iex> Balancero.Connection.Manager.remove("127.0.0.1")
      :ok

      iex> Balancero.Connection.Manager.remove("127.0.0.1")
      {:error, :not_found}

  """
  @spec remove(String.t()) :: :ok | {:error, atom()}
  def remove(host) do
    GenServer.call(__MODULE__, {:remove, host})
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
  def init(_init_arg) do
    Logger.debug("Process initialization.")
    Phoenix.PubSub.subscribe(Balancero.PubSub, Balancero.Connection.Tracker.topic())
    Phoenix.PubSub.subscribe(Balancero.PubSub, topic())
    list = Balancero.Connection.Tracker.list()

    state =
      if list == [] do
        struct(__MODULE__)
      else
        hosts = count_connections(list)
        struct(__MODULE__, hosts: hosts)
      end

    {:ok, state}
  end

  @impl true
  def handle_call(:get, _from, %__MODULE__{hosts: hosts} = state) do
    case get_strategy_option() do
      :least ->
        if map_size(hosts) != 0 do
          reply =
            hosts
            |> Enum.reject(fn {_host, host_info} -> host_info[:paused?] end)
            |> Enum.min_by(fn {_host, host_info} -> host_info[:connections][:total] end)
            |> case do
              {host, _host_info} -> {:ok, host}
              [] -> {:error, :no_hosts_avaliable}
            end

          {:reply, reply, state}
        else
          {:reply, {:error, :no_hosts_avaliable}, state}
        end

      _ ->
        {:reply, {:error, :unknown_strategy}, state}
    end
  end

  def handle_call(:hosts, _from, state) do
    {:reply, {:ok, state.hosts}, state}
  end

  def handle_call({:pause, host}, _from, state) do
    case exist(state.hosts, host) do
      {:ok, :already_exist} ->
        state = put_in(state.hosts[host][:paused?], true)
        broadcast_from({:paused, host})
        {:reply, :ok, state}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:unpause, host}, _from, state) do
    case exist(state.hosts, host) do
      {:ok, :already_exist} ->
        state = put_in(state.hosts[host][:paused?], false)
        broadcast_from({:unpaused, host})
        {:reply, :ok, state}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:add, server}, _from, state) do
    host = Keyword.get(server, :host)

    case exist(state.hosts, host) do
      {:ok, :already_exist} ->
        {:reply, {:error, :already_exist}, state}

      {:error, :not_found} ->
        update_config(server)
        broadcast_from({:added, server})
        {:reply, :ok, state}
    end
  end

  def handle_call({:remove, host}, _from, state) do
    case exist(state.hosts, host) do
      {:ok, :already_exist} ->
        hosts = Application.get_env(:balancero, :servers, [])
        updated_list = Enum.reject(hosts, &(&1[:host] == host))
        Application.put_env(:balancero, :servers, updated_list)
        [{pid, _value}] = Balancero.Connection.Socket.lookup(host)
        :ok = Balancero.Connection.Pool.terminate_child(pid)
        broadcast_from({:removed, host, updated_list})
        {:reply, :ok, state}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call(_command, _from, state) do
    {:reply, {:error, :command_not_supported}, state}
  end

  @impl true
  def handle_info({:join, host, %{type: type}}, %__MODULE__{hosts: hosts}) do
    case hosts[host] do
      nil ->
        client = if type == :client, do: 1, else: 0
        status = if type == :status, do: 1, else: 0
        total = 1

        host_info = %{
          connections: %{total: total, client: client, status: status},
          paused?: false
        }

        hosts = Map.put(hosts, host, host_info)
        {:noreply, %__MODULE__{hosts: hosts}}

      host_info ->
        client = host_info.connections.client
        client = if type == :client, do: client + 1, else: client
        status = host_info.connections.status
        status = if type == :status, do: status + 1, else: status
        total = host_info.connections.total + 1
        connections = %{total: total, client: client, status: status}
        host_info = Map.put(host_info, :connections, connections)
        hosts = Map.put(hosts, host, host_info)
        {:noreply, %__MODULE__{hosts: hosts}}
    end
  end

  def handle_info({:leave, host, %{type: type}}, %__MODULE__{hosts: hosts} = state) do
    case type do
      :status ->
        hosts = Map.delete(hosts, host)
        {:noreply, %__MODULE__{hosts: hosts}}

      :client ->
        case hosts[host] do
          nil ->
            {:noreply, state}

          host_info ->
            client = host_info.connections.client - 1
            status = host_info.connections.status
            total = host_info.connections.total - 1
            connections = %{total: total, client: client, status: status}
            host_info = Map.put(host_info, :connections, connections)
            hosts = Map.put(hosts, host, host_info)
            {:noreply, %__MODULE__{hosts: hosts}}
        end
    end
  end

  def handle_info({:paused, host}, state) do
    state = put_in(state.hosts[host][:paused?], true)
    {:noreply, state}
  end

  def handle_info({:unpaused, host}, state) do
    state = put_in(state.hosts[host][:paused?], false)
    {:noreply, state}
  end

  def handle_info({:added, server}, state) do
    update_config(server)
    {:noreply, state}
  end

  def handle_info({:removed, host, updated_list}, state) do
    Application.put_env(:balancero, :servers, updated_list)
    [{pid, _value}] = Balancero.Connection.Socket.lookup(host)
    :ok = Balancero.Connection.Pool.terminate_child(pid)
    {:noreply, state}
  end

  defp count_connections(list) do
    list
    |> Enum.group_by(fn {host, _presence_info} -> host end)
    |> Enum.reduce(%{}, fn {host, presence_info}, acc ->
      status_connections =
        Enum.count(presence_info, fn {_host, presence_info} ->
          presence_info[:type] == :status
        end)

      client_connections =
        Enum.count(presence_info, fn {_host, presence_info} ->
          presence_info[:type] == :client
        end)

      total = status_connections + client_connections

      connections = %{
        total: total,
        client: client_connections,
        status: status_connections
      }

      Map.put(acc, host, %{connections: connections})
    end)
  end

  defp exist(hosts, host) do
    hosts = Map.keys(hosts)
    if host in hosts, do: {:ok, :already_exist}, else: {:error, :not_found}
  end

  defp update_config(server) do
    host = Keyword.get(server, :host)
    port = Keyword.get(server, :port)
    servers = Application.get_env(:balancero, :servers, [])
    member? = Enum.member?(servers, &(&1[:host] == host and &1[:port] == port))

    case member? do
      true ->
        :ok

      false ->
        Application.put_env(:balancero, :servers, [server | servers])
        :ok
    end
  end

  defp broadcast_from(message) do
    Phoenix.PubSub.broadcast_from(
      Balancero.PubSub,
      self(),
      topic(),
      message
    )
  end
end

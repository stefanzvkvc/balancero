defmodule Balancero.Connection.Pool do
  @moduledoc """
  Supervisor responsible for managing socket processes.
  """
  use DynamicSupervisor
  require Logger

  @doc """
  Starts a supervisor.
  """
  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @doc """
  Starts child process.
  """
  def start_child(arg) do
    DynamicSupervisor.start_child(__MODULE__, {Balancero.Connection.Socket, arg})
  end

  @doc """
  Terminates child process.
  """
  def terminate_child(arg) do
    DynamicSupervisor.terminate_child(__MODULE__, arg)
  end

  @impl true
  def init(_init_arg) do
    Logger.debug("Process initialization.")
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end

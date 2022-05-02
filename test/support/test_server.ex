defmodule TestServer do
  require Logger
  @options [:binary, packet: :line, active: false, reuseaddr: true]
  def start_link(port) do
    {:ok, socket} = :gen_tcp.listen(port, @options)
    pid = spawn_link(fn -> loop(socket) end)
    {:ok, pid}
  end

  defp loop(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    spawn_link(fn -> serve(client) end)
    loop(socket)
  end

  defp serve(socket) do
    case :gen_tcp.recv(socket, 0) do
      {:error, :closed} ->
        Logger.debug("Connection closed...")
        :ok

      {:error, error} ->
        Logger.debug("Error on receiving data from socket. Error: #{inspect(error)}")
        :ok

      {:ok, data} ->
        Logger.debug("Received: #{inspect(data)}...")
        :ok
    end
  end
end

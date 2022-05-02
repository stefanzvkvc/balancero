defmodule Balancero.SupervisorTest do
  use ExUnit.Case, async: false

  test "supervisor is started" do
    # then
    {:ok, _pid} = Balancero.Supervisor.start_link([])
  end
end

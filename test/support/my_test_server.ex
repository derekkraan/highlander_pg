defmodule MyTestServer do
  use GenServer

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, [])
  end

  def init(arg) do
    [msg, pid] = arg
    send(pid, msg)

    {:ok, arg}
  end
end

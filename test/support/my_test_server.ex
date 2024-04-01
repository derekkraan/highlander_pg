defmodule TestServer do
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

defmodule TestServer2 do
  use GenServer

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, [])
  end

  def init(arg) do
    [msg_start, _msg_terminate, pid] = arg
    send(pid, msg_start)
    Process.flag(:trap_exit, true)

    {:ok, arg}
  end

  def terminate(_reason, state) do
    [_msg_start, msg_terminate, pid] = state
    # simulate taking a little longer
    Process.sleep(50)
    send(pid, msg_terminate)
  end
end

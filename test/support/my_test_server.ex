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
    [msg_start, msg_stop, pid | start_opts] = init_arg

    GenServer.start_link(__MODULE__, [msg_start, msg_stop, pid], start_opts)
  end

  def init(arg) do
    [msg_start, _msg_terminate, pid] = arg
    send(pid, msg_start)
    Process.flag(:trap_exit, true)

    {:ok, arg}
  end

  def handle_info({:stop, reason}, state) do
    {:stop, reason, state}
  end

  def terminate(_reason, state) do
    [_msg_start, msg_terminate, pid] = state
    # simulate taking a little longer
    Process.sleep(50)
    send(pid, msg_terminate)
  end
end

defmodule TestServer3 do
  use GenServer

  def start_link(init_arg) do
    {init_arg, start_opts} =
      case Keyword.pop(init_arg, :name) do
        {nil, init_arg} ->
          {init_arg, []}

        {name, init_arg} ->
          {init_arg, [name: name]}
      end

    GenServer.start_link(__MODULE__, init_arg, start_opts)
  end

  def init(arg) do
    {:ok, arg}
  end

  def handle_call(:ping, _from, state) do
    {:reply, :pong, state}
  end
end

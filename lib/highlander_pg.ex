defmodule HighlanderPG do
  @external_resource "README.md"
  @moduledoc @external_resource
             |> File.read!()
             |> String.split("<!-- MDOC !-->")
             |> Enum.fetch!(1)

  use GenServer

  defstruct [:connect_opts, :pg_child, :child, :name]

  def start_link(opts) do
    [child | opts] = opts

    {init_opts, options} =
      gen_options(opts)

    GenServer.start_link(__MODULE__, {child, init_opts}, options)
  end

  def which_children(server) do
    GenServer.call(server, :which_children)
  end

  @spec gen_options(keyword()) :: {init_opts :: keyword(), opts :: keyword()}
  def gen_options(opts) do
    {_init_opts, _options} =
      case Keyword.pop(opts, :sup_name) do
        {nil, init_opts} -> {init_opts, []}
        {name, init_opts} -> {init_opts, [name: name]}
      end
  end

  @impl GenServer
  def init({child, init_opts}) do
    Process.flag(:trap_exit, true)
    connect_opts = Keyword.fetch!(init_opts, :connect_opts)

    child =
      HighlanderPG.Supervisor.handle_child_spec(child)
      |> Map.put(:pid, :undefined)

    # TODO make `name` default to module of GenServer instead of module of HighlanderPG?
    name = Keyword.get(init_opts, :name, __MODULE__)

    state = %__MODULE__{connect_opts: connect_opts, child: child, name: name}

    {:ok, state, {:continue, :init}}
  end

  @impl GenServer
  def handle_call(:which_children, _ref, state) do
    modules =
      case state.child do
        %{modules: modules} -> modules
        %{start: {m, _f, _a}} -> [m]
      end

    children =
      [{state.child.id, state.child.pid, state.child.type, modules}]

    {:reply, children, state}
  end

  @impl GenServer
  def handle_continue(:init, state) do
    # wait for the signal to start the process
    {:noreply, connect(state)}
  end

  @impl GenServer
  def handle_info(:got_lock, state) do
    {:noreply, Map.put(state, :child, start_child(state.child))}
  end

  def handle_info({:EXIT, _pid, _reason}, state) do
    {:stop, :shutdown, state}
  end

  defp connect(state) do
    opts =
      state.connect_opts
      |> Keyword.put(:sync_connect, false)

    postgrex_child =
      {Postgrex.SimpleConnection, [HighlanderPG.DBLock, [self(), state.name], opts]}
      |> HighlanderPG.Supervisor.handle_child_spec()
      |> start_child()

    Map.put(state, :pg_child, postgrex_child)
  end

  # TODO make the keyspace configurable
  # TODO make the hash function configurable

  defp start_child(child) do
    {m, f, a} = child.start

    case apply(m, f, a) do
      {:ok, pid} when is_pid(pid) ->
        Map.put(child, :pid, pid)
    end
  end

  @impl GenServer
  def terminate(:shutdown, state) do
    HighlanderPG.Supervisor.shutdown(state.child)

    HighlanderPG.Supervisor.shutdown(state.pg_child)
  end
end

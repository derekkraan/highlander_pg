defmodule HighlanderPG do
  @external_resource "README.md"
  @moduledoc @external_resource
             |> File.read!()
             |> String.split("<!-- MDOC !-->")
             |> Enum.fetch!(1)

  use GenServer

  defstruct [:connect_opts, :pg_child, :child, :name]

  @type start_opt ::
          {:child, Supervisor.child_spec()}
          | {:connect_opts, keyword()}
          | {:name, term()}
          | {:sup_name, term()}

  @spec start_link([start_opt()]) :: Supervisor.on_start()
  @doc """
  Starts HighlanderPG.

  This function is normally not called directly. You would incorporate HighlanderPG in your supervision tree as follows:

  ```elixir
  # lib/application.ex

  highlander_child = {MyUniqueProcess, arg}

  children = [
    ...
    {HighlanderPG, [child: highlander_child, connect_opts: connect_opts()]}
    ...
  ]

  Supervisor.init(children, strategy: :one_for_one)
  ```

  Options are documented below:
  - `:child` -- mandatory, the child spec of the process or supervisor that HighlanderPG will run.
  - `:connect_opts` -- mandatory, these are passed to `Postgrex.SimpleConnection.start_link/3`. See `Postgrex.start_link/1` for the most relevant options.
  - `:sup_name` -- optional, if you wish to give HighlanderPG's process a name so you can easily access it later.
    ```
    children = [
      {HighlanderPG, [child: child, connect_opts: connect_opts, sup_name: :my_highlander]}
    ]

    # later
    HighlanderPG.count_children(:my_highlander)
    #=> %{active: 1, workers: 1, supervisors: 0, specs: 1}
    ```

  - `:name` -- optional, the key on which HighlanderPG ensures your supervised process or supervisor is unique. The default value is `HighlanderPG` which means that if you wish to use HighlanderPG to monitor multiple globally unique processes, you will need to override this value.
    ```
    children = [
      {HighlanderPG, [child: child1, connect_opts: connect_opts, name: :highlander1]},
      {HighlanderPG, [child: child2, connect_opts: connect_opts, name: :highlander2]},
    ]
    ```
  """
  def start_link(opts) do
    {child, opts} = Keyword.pop(opts, :child)

    {init_opts, start_opts} =
      gen_options(opts)

    GenServer.start_link(__MODULE__, {child, init_opts}, start_opts)
  end

  @spec which_children(Supervisor.supervisor()) :: [
          {term() | :undefined, Supervisor.child(), :worker | :supervisor, [module()] | :dynamic}
        ]
  @doc """
  See `Supervisor.which_children/1`.
  """
  def which_children(server) do
    GenServer.call(server, :which_children)
  end

  @spec count_children(Supervisor.supervisor()) :: %{
          specs: non_neg_integer(),
          active: non_neg_integer(),
          supervisors: non_neg_integer(),
          workers: non_neg_integer()
        }
  @doc """
  See `Supervisor.count_children/1`.
  """
  def count_children(server) do
    GenServer.call(server, :count_children)
  end

  defp gen_options(opts) do
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
  def handle_call(:count_children, _ref, state) do
    reply =
      cond do
        state.child.pid == :undefined ->
          %{active: 0, supervisors: 0, workers: 0, specs: 1}

        state.child.type == :worker ->
          %{active: 1, supervisors: 0, workers: 1, specs: 1}

        state.child.type == :supervisor ->
          %{active: 1, supervisors: 1, workers: 0, specs: 1}
      end

    {:reply, reply, state}
  end

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

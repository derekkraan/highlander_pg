defmodule HighlanderPg do
  @moduledoc """
  Documentation for `HighlanderPg`.

  Wrap your supervisor or process with HighlanderPg and it will ensure that it only runs on one node in your cluster.

  HighlanderPg only requires common access to a Postgres instance, and unlike Highlander (the original library), it will work whether you have configured Erlang clustering. HighlanderPg also offers better guarantees that your process will never be running in two places at once, being that it is not susceptible to split-brain phenomena. This is of course contingent on your database being available. For any application that is dependent on the database to run anyways, this is not a big obstacle.

  |  | **Highlander** | **HighlanderPg** |
  | Runs your process once, globally | ✓ | ✓ |
  | Works with Erlang Clustering | ✓ | ✓ |
  | Works without Erlang Clustering | | ✓ |
  | Split-brain prevention | | ✓ |
  | Supports further development | | ✓ |

  ```elixir
  # lib/application.ex

  children = [
    ...
    {HighlanderPg, child_spec, [name: "my_unique_name", connect_opts: connect_opts()]},
    ...
  ]
  ```

  HighlanderPg accomplishes this using Postgres' advisory locks. In order to do so, it opens and maintains a connection to your postgres database. Configure connect_opts like this:

  ```elixir
  # config/runtime.exs or config/prod.exs

  config :my_app, MyApp.Repo,
    username: "",
    password: "",
    hostname: "",
    database: ""

  config :my_app, :highlander_pg,
    username: "",
    password: "",
    hostname: "",
    database: ""

  # lib/application.ex
  defp connect_opts() do
    Application.get_env(:my_app, :highlander_pg)
  end
  ```

  # Behaviour
  On boot, HighlanderPg will attempt to connect with the specified database.

  If it is given malformed options, then it will raise an exception and crash. This is to prevent misconfiguration.

  If it can not connect, it will emit an error but not raise an exception. This mirrors other libraries, like `Ecto`. A database failure is an expected condition, and it should be possible to design an application that continues to function in some limited capacity without the database.

  If a connection can be made, then HighlanderPg will attempt to acquire an advisory lock. If it has been able to acquire this lock, then it will start your child process defined by `child_spec`.

  If HighlanderPg can not acquire the lock, then it will simply wait until the lock can be acquired. This will occur automatically when the lock becomes free, ensuring near-continuous operation of your process.

  # Finding your process

  Commonly, you may wish to be able to find your global singleton process, so that you can communicate with it. This can be done by leveraging erlang's `:global` module.

  ```elixir
  # GenServer.start_link
  GenServer.start_link(MyGenServer, args, name: {:global, "my_global_name"})

  # child_spec
  %{
    id: MyGenServer,
    start: {GenServer, :start_link, [MyGenServer, args, name: {:global, "my_global_name}]}
  }
  ```

  # HighlanderPg as a Supervisor
  To your application, HighlanderPg functions like a normal supervisor. Consequently, it also implements `count_children/1` and `which_children/1`, to offer some insight into the system.
  """

  use GenServer

  def start_link(opts) do
    {init_opts, options} =
      case Keyword.pop(opts, :name) do
        {nil, init_opts} -> {init_opts, []}
        {name, init_opts} -> {init_opts, [name: name]}
      end

    GenServer.start_link(__MODULE__, init_opts, options)
  end

  defstruct [:connect_opts, :pg_pid, :child_spec, :child_pid]

  @impl true
  def init(init_opts) do
    Process.flag(:trap_exit, true)
    connect_opts = Keyword.fetch!(init_opts, :connect_opts)
    child_spec = Keyword.fetch!(init_opts, :child_spec) |> Supervisor.child_spec([])

    {:ok, %__MODULE__{connect_opts: connect_opts, child_spec: child_spec}, {:continue, :init}}
  end

  @impl true
  def handle_continue(:init, state) do
    {:ok, pg_pid} = connect(state)

    state = %{state | pg_pid: pg_pid}

    if get_lock(state) do
      {:noreply, start_child(state)}
    else
      # TODO try again very soon
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(msg, state) do
    {:noreply, state}
  end

  defp connect(state) do
    Postgrex.start_link(state.connect_opts)
  end

  defp get_lock(state) do
    # TODO turn `id` into the lock id, not `[1, 1]`
    case Postgrex.query(state.pg_pid, "select pg_advisory_lock($1, $2)", [1, 1]) do
      {:ok,
       %Postgrex.Result{
         rows: [[:void]]
       }} ->
        true
    end
  end

  defp start_child(state) do
    {m, f, a} = state.child_spec.start

    case apply(m, f, a) do
      {:ok, pid} when is_pid(pid) -> %{state | child_pid: pid}
    end
  end
end

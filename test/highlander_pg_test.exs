defmodule HighlanderPGTest do
  use ExUnit.Case
  doctest HighlanderPG
  import ExUnit.CaptureLog

  @connect_opts [
    username: "postgres",
    password: "postgres",
    database: "highlander",
    port: "5431"
  ]

  def sup(name, child_spec, opts \\ []) do
    children = [
      {HighlanderPG,
       [child: child_spec, name: name, connect_opts: @connect_opts, polling_interval: 50] ++ opts}
    ]

    opts = [strategy: :one_for_one]
    {:ok, _spid} = Supervisor.start_link(children, opts)
  end

  test "can start a child" do
    {:ok, _sup} = sup(:my_test_server, {TestServer, [:hello, self()]})
    assert_receive :hello, 500
  end

  test "reports an error" do
    Process.flag(:trap_exit, true)

    assert capture_log(fn ->
             {:ok, _sup} = sup(:error_server, {ErrorServer, [:hello, self()]})
             Process.sleep(200)
           end) =~ "Child ErrorServer of Supervisor :error_server failed to start"
  end

  test "runs when only given a child module" do
    {:ok, spid} = sup(:my_highlander_pg6, TestServer3)

    # give time for process to start
    Process.sleep(100)

    [{HighlanderPG, hpid, _, _}] = Supervisor.which_children(spid)
    [{TestServer3, pid, _, _}] = Supervisor.which_children(hpid)
    assert :pong = GenServer.call(pid, :ping)
  end

  test "connects to postgres" do
    sup(:my_highlander_pg2, {TestServer, [:hello, self()]})
    sup(:my_highlander_pg2, {TestServer, [:hello, self()]})
    assert_receive(:hello, 500)
    refute_receive(:hello, 500)
  end

  test "shuts down gracefully" do
    {:ok, spid1} = sup(:my_highlander_pg3, {TestServer2, [:hello, :goodbye, self()]})
    assert_receive(:hello, 500)
    Supervisor.stop(spid1)
    assert_receive(:goodbye, 500)
  end

  test "starts a second process when the first dies" do
    {:ok, spid1} = sup(:my_highlander_pg4, {TestServer2, [:hello, :goodbye, self()]})

    assert_receive(:hello, 500)

    {:ok, _spid2} = sup(:my_highlander_pg4, {TestServer2, [:hello, :goodbye, self()]})

    refute_receive(:hello, 500)

    Supervisor.stop(spid1)
    assert_receive(:goodbye, 500)

    assert_receive(:hello, 500)
  end

  test "implements which_children/1" do
    {:ok, spid1} = sup(:my_highlander_pg5, {TestServer2, [:hello, :goodbye, self()]})
    assert_receive :hello, 500
    {:ok, spid2} = sup(:my_highlander_pg5, {TestServer2, [:hello, :goodbye, self()]})
    [{HighlanderPG, hpid, :supervisor, _children}] = Supervisor.which_children(spid1)
    assert [{TestServer2, pid, :worker, [TestServer2]}] = HighlanderPG.which_children(hpid)
    assert is_pid(pid)
    [{HighlanderPG, hpid2, :supervisor, _children}] = Supervisor.which_children(spid2)

    assert [{TestServer2, :undefined, :worker, [TestServer2]}] =
             HighlanderPG.which_children(hpid2)
  end

  test "implements count_children/1" do
    {:ok, spid1} = sup(:my_highlander_pg5, {TestServer2, [:hello, :goodbye, self()]})
    assert_receive :hello, 500
    {:ok, spid2} = sup(:my_highlander_pg5, {TestServer2, [:hello, :goodbye, self()]})
    [{HighlanderPG, hpid1, :supervisor, _children}] = Supervisor.which_children(spid1)
    [{HighlanderPG, hpid2, :supervisor, _children}] = Supervisor.which_children(spid2)

    assert %{active: 1, workers: 1, supervisors: 0, specs: 1} ==
             HighlanderPG.count_children(hpid1)

    assert %{active: 0, workers: 0, supervisors: 0, specs: 1} ==
             HighlanderPG.count_children(hpid2)
  end

  test "count_children/1 counts supervisors" do
    {:ok, spid1} =
      sup(:my_highlander_pg11, %{
        start: {Supervisor, :start_link, [[], [strategy: :one_for_one]]},
        id: Supervisor,
        type: :supervisor
      })

    Process.sleep(100)

    [{HighlanderPG, hpid1, :supervisor, _children}] = Supervisor.which_children(spid1)

    assert %{active: 1, workers: 0, supervisors: 1, specs: 1} ==
             HighlanderPG.count_children(hpid1)
  end

  test "can name HighlanderPG" do
    {:ok, _spid} = sup(:test_server, TestServer3, sup_name: :highlander_pg_named)
    assert [{TestServer3, _, _, _}] = HighlanderPG.which_children(:highlander_pg_named)
  end

  test "can name supervised process" do
    {:ok, _spid} = sup(:random_string, {TestServer3, name: :test_server2})

    # give time for process to start
    Process.sleep(100)

    assert :pong = GenServer.call(:test_server2, :ping)
  end

  test "highlander exits and closes connection when process shuts down" do
    Process.flag(:trap_exit, true)

    child = {TestServer2, [:hello, :goodbye, self(), name: :process_exits]}

    {:ok, hpid1} = HighlanderPG.start_link(child: child, connect_opts: @connect_opts)
    assert_receive :hello, 500
    {:ok, _hpid2} = HighlanderPG.start_link(child: child, connect_opts: @connect_opts)
    refute_receive :hello, 500

    send(GenServer.whereis(:process_exits), {:stop, :shutdown})
    assert_receive {:EXIT, ^hpid1, :shutdown}, 500
    assert_receive :hello, 500
  end

  test "highlander exits and closes connection when process exits unexpectedly" do
    Process.flag(:trap_exit, true)

    child = {TestServer2, [:hello, :goodbye, self(), name: :process_exits2]}

    {:ok, hpid1} = HighlanderPG.start_link(child: child, connect_opts: @connect_opts)
    assert_receive :hello, 500
    {:ok, _hpid2} = HighlanderPG.start_link(child: child, connect_opts: @connect_opts)
    refute_receive :hello, 500

    send(GenServer.whereis(:process_exits2), {:stop, "bad reason"})
    assert_receive {:EXIT, ^hpid1, :shutdown}, 500
    assert_receive :hello, 500
  end

  test "highlander exits when connection drops unexpectedly" do
    Process.flag(:trap_exit, true)

    child = {TestServer2, [:hello, :goodbye, self()]}

    {:ok, hpid1} = HighlanderPG.start_link(child: child, connect_opts: @connect_opts)
    assert_receive :hello, 500
    %{pg_child: %{pid: pg_pid}} = :sys.get_state(hpid1)
    {:ok, _hpid2} = HighlanderPG.start_link(child: child, connect_opts: @connect_opts)
    refute_receive :hello, 500

    Process.exit(pg_pid, :kill)
    assert_receive {:EXIT, ^hpid1, :shutdown}
    assert_receive :hello, 500
  end
end

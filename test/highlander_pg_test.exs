defmodule HighlanderPGTest do
  use ExUnit.Case
  doctest HighlanderPG

  @connect_opts [
    username: "postgres",
    password: "postgres",
    database: "highlander"
  ]

  def sup(name, child_spec, opts \\ []) do
    children = [
      {HighlanderPG, [child_spec, name: name, connect_opts: @connect_opts] ++ opts}
    ]

    opts = [strategy: :one_for_one]
    {:ok, _spid} = Supervisor.start_link(children, opts)
  end

  test "can start a child" do
    {:ok, _sup} = sup(:my_test_server, {TestServer, [:hello, self()]})
    assert_receive :hello
  end

  # TEST bad connection opts = error on start

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
    assert_receive(:hello)
    refute_receive(:hello, 500)
  end

  test "shuts down gracefully" do
    {:ok, spid1} = sup(:my_highlander_pg3, {TestServer2, [:hello, :goodbye, self()]})
    assert_receive(:hello)
    Supervisor.stop(spid1)
    assert_receive(:goodbye)
  end

  test "starts a second process when the first dies" do
    {:ok, spid1} = sup(:my_highlander_pg4, {TestServer2, [:hello, :goodbye, self()]})

    assert_receive(:hello)

    {:ok, _spid2} = sup(:my_highlander_pg4, {TestServer2, [:hello, :goodbye, self()]})

    refute_receive(:hello, 500)

    Supervisor.stop(spid1)
    assert_receive(:goodbye, 500)

    assert_receive(:hello)
  end

  test "implements which_children/1" do
    {:ok, spid1} = sup(:my_highlander_pg5, {TestServer2, [:hello, :goodbye, self()]})
    assert_receive :hello
    {:ok, spid2} = sup(:my_highlander_pg5, {TestServer2, [:hello, :goodbye, self()]})
    [{HighlanderPG, hpid, :worker, _children}] = HighlanderPG.which_children(spid1)
    assert [{TestServer2, pid, :worker, [TestServer2]}] = HighlanderPG.which_children(hpid)
    assert is_pid(pid)
    [{HighlanderPG, hpid2, :worker, _children}] = HighlanderPG.which_children(spid2)

    assert [{TestServer2, :undefined, :worker, [TestServer2]}] =
             HighlanderPG.which_children(hpid2)
  end

  # TEST when process exits unexpectedly (process restarts)
  # TEST when connection drops unexpectedly (terminate)
  # TEST works with :via tuple

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

    {:ok, hpid1} = HighlanderPG.start_link([child, connect_opts: @connect_opts])
    assert_receive :hello
    {:ok, _hpid2} = HighlanderPG.start_link([child, connect_opts: @connect_opts])
    refute_receive :hello

    send(GenServer.whereis(:process_exits), {:stop, :shutdown})
    assert_receive {:EXIT, ^hpid1, :shutdown}
    assert_receive :hello
  end

  test "highlander exits and closes connection when process exits unexpectedly" do
    Process.flag(:trap_exit, true)

    child = {TestServer2, [:hello, :goodbye, self(), name: :process_exits2]}

    {:ok, hpid1} = HighlanderPG.start_link([child, connect_opts: @connect_opts])
    assert_receive :hello
    {:ok, _hpid2} = HighlanderPG.start_link([child, connect_opts: @connect_opts])
    refute_receive :hello

    send(GenServer.whereis(:process_exits2), {:stop, "bad reason"})
    assert_receive {:EXIT, ^hpid1, :shutdown}
    assert_receive :hello
  end
end

defmodule HighlanderPGTest do
  use ExUnit.Case
  doctest HighlanderPG

  @connect_opts [
    username: "postgres",
    password: "postgres",
    database: "highlander"
  ]

  def sup(name, child_spec) do
    children = [
      {HighlanderPG, [child: child_spec, name: name, connect_opts: @connect_opts]}
    ]

    opts = [strategy: :one_for_one]
    {:ok, _spid} = Supervisor.start_link(children, opts)
  end

  test "can start a child" do
    children = [
      {HighlanderPG,
       [
         child: {TestServer, [:hello, self()]},
         name: :my_test_server,
         connect_opts: @connect_opts
       ]}
    ]

    opts = [strategy: :one_for_one, name: MySupervisor]
    assert {:ok, _s_pid} = Supervisor.start_link(children, opts)
  end

  # TEST bad connection opts = error on start

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

  test "implements Supervisor.which_children/1" do
    {:ok, spid1} = sup(:my_highlander_pg5, {TestServer2, [:hello, :goodbye, self()]})
    assert_receive :hello
    {:ok, spid2} = sup(:my_highlander_pg5, {TestServer2, [:hello, :goodbye, self()]})
    [{HighlanderPG, hpid, :worker, _children}] = Supervisor.which_children(spid1)
    assert [{TestServer2, pid, :worker, [TestServer2]}] = Supervisor.which_children(hpid)
    assert is_pid(pid)
    [{HighlanderPG, hpid2, :worker, _children}] = Supervisor.which_children(spid2)
    assert [{TestServer2, :undefined, :worker, [TestServer2]}] = Supervisor.which_children(hpid2)
  end

  # TEST when process exits unexpectedly (process restarts)
  # TEST when connection drops unexpectedly (terminate)
end

defmodule HighlanderPGTest do
  use ExUnit.Case
  doctest HighlanderPG

  @connect_opts [
    username: "postgres",
    password: "postgres",
    database: "highlander"
  ]

  test "can start a child" do
    children = [
      {HighlanderPG,
       [
         child_spec: {TestServer, [:hello, self()]},
         name: :my_test_server,
         connect_opts: @connect_opts
       ]}
    ]

    opts = [strategy: :one_for_one, name: MySupervisor]
    assert {:ok, _s_pid} = Supervisor.start_link(children, opts)
  end

  # bad connection opts = error on start

  test "connects to postgres" do
    sup(:my_highlander_pg2, {TestServer, [:hello, self()]})
    sup(:my_highlander_pg2, {TestServer, [:hello, self()]})
    # child_spec = {TestServer, [:hello, self()]}

    # children = [
    #   {HighlanderPG,
    #    [child_spec: child_spec, name: :my_highlander_pg, connect_opts: @connect_opts]},
    #   Supervisor.child_spec(
    #     {HighlanderPG,
    #      [
    #        child_spec: child_spec,
    #        name: :my_highlander_pg2,
    #        connect_opts: @connect_opts
    #      ]},
    #     id: :highlander_2
    #   )
    # ]

    # opts = [strategy: :one_for_one, name: MySupervisor2]
    # {:ok, _s_pid} = Supervisor.start_link(children, opts)

    assert_receive(:hello)
    refute_receive(:hello, 500)
  end

  def sup(name, child_spec) do
    children = [
      {HighlanderPG, [child_spec: child_spec, name: name, connect_opts: @connect_opts]}
    ]

    opts = [strategy: :one_for_one]
    {:ok, _spid} = Supervisor.start_link(children, opts)
  end

  test "starts a second process when the first dies" do
    {:ok, spid1} = sup(:my_highlander_pg3, {TestServer2, [:hello, :goodbye, self()]})
    {:ok, _spid2} = sup(:my_highlander_pg3, {TestServer2, [:hello, :goodbye, self()]})

    assert_receive(:hello)
    refute_receive(:hello, 500)

    Supervisor.stop(spid1)

    assert_receive(:hello)
  end

  test "shuts down gracefully" do
    # child_spec = {TestServer2, [:hello, :goodbye, self()]}
    # children = 
  end
end

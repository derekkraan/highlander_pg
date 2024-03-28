defmodule HighlanderPgTest do
  use ExUnit.Case
  doctest HighlanderPg

  @connect_opts [
    username: "postgres",
    password: "postgres",
    database: "highlander"
  ]

  test "can start a child" do
    children = [
      {HighlanderPg,
       [child_spec: {MyTestServer, :hello}, name: :my_test_server, connect_opts: @connect_opts]}
    ]

    opts = [strategy: :one_for_one, name: MySupervisor]
    assert {:ok, _s_pid} = Supervisor.start_link(children, opts)
  end

  # bad connection opts = error on start

  test "connects to postgres" do
    child_spec = {MyTestServer, [:hello, self()]}

    children = [
      {HighlanderPg,
       [child_spec: child_spec, name: :my_highlander_pg, connect_opts: @connect_opts]},
      Supervisor.child_spec(
        {HighlanderPg,
         [
           child_spec: child_spec,
           name: :my_highlander_pg2,
           connect_opts: @connect_opts
         ]},
        id: :highlander_2
      )
    ]

    opts = [strategy: :one_for_one, name: MySupervisor2]
    {:ok, _s_pid} = Supervisor.start_link(children, opts)

    assert_receive(:hello)
    refute_receive(:hello, 500)
  end

  test "starts a second process when the first dies" do
    child_spec = {MyTestServer, [:hello, self()]}

    children = [
      {HighlanderPg,
       [child_spec: child_spec, name: :my_highlander_pg, connect_opts: @connect_opts]}
    ]

    opts = [strategy: :one_for_one, name: MySupervisor3]
    {:ok, spid1} = Supervisor.start_link(children, opts)

    opts = [strategy: :one_for_one, name: MySupervisor4]

    {:ok, _spid2} =
      Supervisor.start_link(children, opts)

    assert_receive(:hello)
    refute_receive(:hello, 500)

    Supervisor.stop(spid1)

    assert_receive(:hello)
  end
end

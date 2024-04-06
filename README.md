# HighlanderPG

<!-- MDOC !-->

Wrap your supervisor or process with HighlanderPG to run it as a singleton process in your cluster, backed by Postgres.

## Installation

To install HighlanderPG, you will need to purchase a license. HighlanderPG is [hosted on Code Code Ship](https://hex.codecodeship.com/package/highlander_pg).

Once you have purchased a license, follow the installation instructions there. They are duplicated here for completeness:

First add `codecodeship` as a Hex repository:

```bash
mix hex.repo add codecodeship https://hex.codecodeship.com/api/repo --fetch-public-key SHA256:5hyUvvnGT45CntYCrHAOO3tn94l1xz8fUlyQS7qDhxg --auth-key [YOUR AUTH KEY]
```

Then add `highlander_pg` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:highlander_pg, "~> 1.0", repo: :codecodeship},
  ]
end
```

Full documentation can be found on Code Code Ship at <https://hexdocs.codecodeship.com/highlander_pg/1.0.0>.

# Highlander vs HighlanderPG

I wrote Highlander in April of 2020, as a simple way to run a singleton process in your Erlang/Elixir cluster. Highlander is backed by `:global`, which is a highly-available global registry. This works fine for most people, but it has some drawbacks:

- If you have network troubles, `:global` can form partitions, and that would result in separate Highlander instances in each partition. It is possible that your process will end up running multiple instances globally, instead of just one.
- It is sometimes difficult or impossible to enable clustering, such as in Heroku. This makes it also impossible to use the original Highlander.

For users who want better guarantees that a singleton will only be run once globally, and for anyone who can not use BEAM's clustering or doesn't want to rely on it, I have developed HighlanderPG.

HighlanderPG uses Postgres advisory locks to ensure global uniqueness. On startup, HighlanderPG will attempt to acquire an advisory lock using the database that you have configured. If it gets the lock, it will start and supervise its configured process.

If at any time, the connection to Postgres is lost, the supervised process will be killed. If HighlanderPG can not achieve a connection to the database, no process will not be started.

Therefore, if your database goes down, HighlanderPG will not start its supervised process anywhere. For applications which are dependent on a connection to the database to work anyways (which is most of them), this is a reasonable trade-off.

I have also cleaned up the Supervisor behaviour of HighlanderPG. It now handles shutdowns better, for instance, and is compatible with some `Supervisor` functions, such as `Supervisor.which_children/1`.

## HighlanderPG is a paid library

HighlanderPG is also a paid library, and it differs in this way from Highlander, which is open source.

By purchasing a license for HighlanderPG, you will be supporting its maintenance and further development.

Licenses are based on a yearly fee, which reflects the volume of ongoing maintenance and bugfixes. If you do the math, you'll quickly realize that HighlanderPG is a very good deal compared to developing and maintaining this functionality yourself.

## Summary

|  | **Highlander** | **HighlanderPG** |
| Runs your process once, globally | ✓ | ✓ |
| Works with Erlang Clustering | ✓ | ✓ |
| Works without Erlang Clustering | | ✓ |
| Failure mode: runs your process 2x or more | ✓ | |
| Failure mode: runs your process 0x | | ✓ [1] |
| Supports further development | | ✓ |

[1] It is possible that Postgres might give out an advisory lock while another node still thinks it has the lock. This situation will resolve itself after the other node's Postgres connection times out.

# Usage

Wrap your supervisor or process with HighlanderPG and it will ensure that it only runs on one node in your cluster.

```elixir
# lib/application.ex

# before:
children = [
  MyModule
]

# after:
children = [
  {HighlanderPG, [child: MyModule, connect_opts: connect_opts()]},
]
```

HighlanderPG opens and maintains a connection to your Postgres database instance. To do that, it needs the connection details. This is configured in the same way as Ecto.

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

# HighlanderPG as a Supervisor
To your application, HighlanderPG functions like a normal supervisor. Consequently, it also implements `count_children/1` and `which_children/1`, to offer some insight into the system.

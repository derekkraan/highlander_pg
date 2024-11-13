# HighlanderPG

<!-- MDOC !-->

Wrap your supervisor or process with HighlanderPG to run it as a singleton process in your cluster, backed by Postgres.

# Usage

Wrap your supervisor or process with HighlanderPG and it will ensure that it only runs on one node in your cluster.

```elixir
# before:
children = [
  MyChild
]

# after:
children = [
  {HighlanderPG, [child: MyChild, repo: MyApp.Repo]},
]
```

# Highlander vs HighlanderPG

How does HighlanderPG differ from Highlander (the open sourced version)?

I wrote Highlander in April of 2020, as a simple way to run a singleton process in your Elixir cluster. Highlander is backed by `:global`, which is a highly-available global registry. HighlanderPG improves on the original in several ways:

- If you have network troubles, `:global` can form partitions, and that would result in separate Highlander instances in each partition. It is possible that your process will end up running multiple instances globally, instead of just one. HighlanderPG eliminates this possibility. The downside to this is that if your Postgres DB becomes unavailable for whatever reason, your child process won't run. For most applications, this is of little consequence.

- Highlander requires BEAM clustering, meaning you can't use it in some environments (eg, Heroku). HighlanderPG works anywhere you can connect to the database.

- HighlanderPG includes much better supervisor semantics. It is built as a tiny supervisor, which means you can run functions like `which_children/1` and `count_children/1` on it.

## How does HighlanderPG work?

HighlanderPG uses Postgres advisory locks to ensure global uniqueness. On startup, HighlanderPG will connect to the database and attempt to acquire an advisory lock. If it gets the lock, it will start and supervise its configured process.

If at any time, the connection to Postgres is lost, the supervised process will be killed. If HighlanderPG can not achieve a connection to the database, no process will not be started.

If your process dies, then HighlanderPG also shuts down, and is subsequently restarted. The lock will be acquired by one of the HighlanderPG processes running on one of the nodes (including the node where it last crashed, depending on timing), and the process will start up again, as a singleton.

## HighlanderPG is a paid library

HighlanderPG is a paid library. It differs in this way from Highlander, which is open source.

By purchasing a license for HighlanderPG, you will be supporting its maintenance and further development.

Licenses are based on a yearly fee, which reflects the volume of ongoing maintenance and bugfixes. If you do the math, you'll quickly realize that HighlanderPG is a very good deal compared to developing and maintaining this specialized functionality yourself.

## Summary

|  | **Highlander** | **HighlanderPG** |
| --- | --- | --- |
| Runs your process once, globally | ✓ | ✓ |
| Works with Erlang Clustering | ✓ | ✓ |
| Works without Erlang Clustering | | ✓ |
| Failure mode: runs your process 2x or more | ✓ | |
| Failure mode: runs your process 0x | | ✓ [1] |
| Supports further development | | ✓ |

[1] It is possible that Postgres might give out an advisory lock while another node still thinks it has the lock. This situation will resolve itself after the other node's Postgres connection times out. This time-out is configurable in connect_opts. See the docs for details.

# Tips and Tricks

## Finding your process

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

# Installation

To install HighlanderPG, you will need to purchase a license. HighlanderPG is [hosted on Code Code Ship](https://hex.codecodeship.com/package/highlander_pg).

Once you have purchased a license, follow the installation instructions there. They are duplicated here for completeness, but copying the instructions from Code Code Ship, which include your specific auth key, is faster:

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

Full documentation can be found on Code Code Ship at <http://hexdocs.codecodeship.com/highlander_pg/1.0.0>.


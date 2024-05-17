defmodule HighlanderPG.DBLock do
  @moduledoc false
  @behaviour Postgrex.SimpleConnection

  @impl Postgrex.SimpleConnection
  def init([pid, name]) do
    {:ok, %{from: {pid, name}, name: name}}
  end

  @impl Postgrex.SimpleConnection
  def handle_connect(state) do
    {:query, query(state), state}
  end

  @impl Postgrex.SimpleConnection
  def handle_result(results, state) when is_list(results) do
    case results do
      [%{rows: [["t"]]}] ->
        {pid, _name} = state.from
        send(pid, :got_lock)
        {:noreply, state}

      [%{rows: [["f"]]}] ->
        Process.send_after(self(), :try_again, 100)
        {:noreply, state}
    end
  end

  @impl Postgrex.SimpleConnection
  def handle_info(:try_again, state) do
    {:query, query(state), state}
  end

  @impl Postgrex.SimpleConnection
  def notify(_, _, state) do
    {:noreply, state}
  end

  defp query(state) do
    "select pg_try_advisory_lock(1, #{:erlang.phash2(state.name)})"
  end
end

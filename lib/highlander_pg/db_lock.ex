defmodule HighlanderPG.DBLock do
  @behaviour Postgrex.SimpleConnection

  @impl Postgrex.SimpleConnection
  def init([pid, name]) do
    {:ok, %{from: {pid, name}, name: name}}
  end

  # @impl Postgrex.SimpleConnection
  # def handle_call({:query, query}, from, state) do
  #   {:query, query, %{state | from: from}}
  # end

  @impl Postgrex.SimpleConnection
  def handle_connect(state) do
    {:query, "select pg_advisory_lock(1, #{:erlang.phash2(state.name)})", state}
  end

  @impl Postgrex.SimpleConnection
  def handle_result(results, state) when is_list(results) do
    {pid, _name} = state.from
    send(pid, :got_lock)
    {:noreply, state}
  end

  @impl Postgrex.SimpleConnection
  def handle_result(%Postgrex.Error{} = error, state) do
    Postgrex.SimpleConnection.reply(state.from, error)
    {:noreply, state}
  end

  @impl Postgrex.SimpleConnection
  def notify(_, _, state) do
    {:noreply, state}
  end
end

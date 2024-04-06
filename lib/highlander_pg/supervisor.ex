#
# Copyright Ericsson AB 1996-2024. All Rights Reserved.
# Copyright Moose Code BV 2024. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
#
defmodule HighlanderPG.Supervisor do
  @moduledoc false
  @default_child_spec %{type: :worker, restart: :permanent}

  def handle_child_spec(child_spec) do
    child_spec =
      child_spec
      |> Supervisor.child_spec([])

    child_spec = Map.merge(@default_child_spec, child_spec)

    shutdown =
      case child_spec do
        %{shutdown: shutdown} -> shutdown
        %{type: :worker} -> 5000
        %{type: :supervisor} -> :infinity
      end

    Map.put(child_spec, :shutdown, shutdown)
  end

  def shutdown(%{pid: pid, shutdown: :brutal_kill}) do
    monitor = Process.monitor(pid)
    Process.exit(pid, :kill)

    receive do
      {:DOWN, ^monitor, :process, ^pid, _reason} ->
        :ok
    end
  end

  def shutdown(%{pid: pid, shutdown: time}) do
    monitor = Process.monitor(pid)
    Process.exit(pid, :shutdown)

    receive do
      {:DOWN, ^monitor, :process, ^pid, _reason} ->
        :ok
    after
      time ->
        Process.exit(pid, :kill)

        receive do
          {:DOWN, ^monitor, :process, ^pid, _reason} ->
            :ok
        end
    end
  end
end

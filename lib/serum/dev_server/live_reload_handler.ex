defmodule Serum.DevServer.LiveReloadHandler do
  @moduledoc false

  _moduledocp = """
  A WebSock handler that sends signals to clients on file events.
  """

  @behaviour WebSock

  import Serum.IOProxy, only: [put_err: 2, put_msg: 2]
  alias Serum.DevServer.Service

  @impl true
  def init(state) do
    put_msg(:info, "Live Reloader: WebSocket connected.")
    Service.GenServer.subscribe()

    {:ok, state}
  end

  @impl true
  def handle_in(message, state) do
    put_err(:warn, "Live Reloader: Ignoring a message from client: #{inspect(message)}")

    {:ok, state}
  end

  @impl true
  def handle_info(message, state)

  def handle_info(:send_reload, state) do
    {:push, {:text, "reload"}, state}
  end

  def handle_info(_, state), do: {:ok, state}

  @impl true
  def terminate(_reason, _state) do
    put_msg(:info, "Live Reloader: WebSocket disconnected.")

    :ok
  end
end

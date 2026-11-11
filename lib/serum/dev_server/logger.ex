defmodule Serum.DevServer.Logger do
  @moduledoc false

  alias Serum.IOProxy

  @spec log(Plug.Conn.t(), integer()) :: :ok
  def log(%Plug.Conn{} = conn, status) do
    from = conn.remote_ip |> :inet.ntoa() |> to_string()

    msg =
      [
        [status_color(status), "[", to_string(status), "] ", :reset],
        [from, ?\s, conn.method, ?\s, :bright, conn.request_path]
      ]
      |> IO.ANSI.format()
      |> IO.iodata_to_binary()

    IOProxy.put_msg(:info, msg)
  end

  defp status_color(code)
  defp status_color(code) when code in 200..299, do: :green
  defp status_color(code) when code in 300..399, do: :cyan
  defp status_color(_code), do: :red
end

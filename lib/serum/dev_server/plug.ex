defmodule Serum.DevServer.Plug do
  @moduledoc false

  _moduledocp = """
  A Plug which serves the built website from a temporary directory and
  upgrades live reloader requests to WebSocket connections.
  """

  @behaviour Plug

  import Plug.Conn
  alias Serum.DevServer.LiveReloadHandler
  alias Serum.DevServer.Logger

  @impl true
  def init(opts) do
    %{
      site: opts |> Keyword.fetch!(:site) |> Path.expand(),
      base: opts |> Keyword.get(:base, "/") |> Path.split() |> Enum.reject(&(&1 == "/"))
    }
  end

  @impl true
  def call(conn, opts)

  def call(%Plug.Conn{path_info: ["serum_live_reloader"]} = conn, _opts) do
    conn
    |> WebSockAdapter.upgrade(LiveReloadHandler, nil, timeout: :infinity)
    |> halt()
  end

  def call(%Plug.Conn{method: method} = conn, opts) when method in ["GET", "HEAD"] do
    with {:ok, segments} <- strip_base(conn.path_info, opts.base),
         {:ok, segments} <- decode_segments(segments) do
      serve(conn, Path.join([opts.site | segments]))
    else
      :error -> respond(conn, 404, "Not Found")
    end
  end

  def call(conn, _opts), do: respond(conn, 405, "Method Not Allowed")

  @spec strip_base([binary()], [binary()]) :: {:ok, [binary()]} | :error
  defp strip_base(segments, base)
  defp strip_base(segments, []), do: {:ok, segments}
  defp strip_base([x | segments], [x | base]), do: strip_base(segments, base)
  defp strip_base(_, _), do: :error

  @spec decode_segments([binary()]) :: {:ok, [binary()]} | :error
  defp decode_segments(segments) do
    decoded = Enum.map(segments, &URI.decode/1)

    if Enum.any?(decoded, &invalid_segment?/1), do: :error, else: {:ok, decoded}
  end

  @spec invalid_segment?(binary()) :: boolean()
  defp invalid_segment?(segment) do
    segment in [".", ".."] or String.contains?(segment, ["/", "\\", <<0>>])
  end

  @spec serve(Plug.Conn.t(), binary()) :: Plug.Conn.t()
  defp serve(conn, path) do
    cond do
      File.regular?(path) ->
        send_static(conn, path)

      File.dir?(path) and not String.ends_with?(conn.request_path, "/") ->
        conn
        |> put_resp_header("location", conn.request_path <> "/")
        |> respond(301, "")

      File.regular?(Path.join(path, "index.html")) ->
        send_static(conn, Path.join(path, "index.html"))

      true ->
        respond(conn, 404, "Not Found")
    end
  end

  @spec send_static(Plug.Conn.t(), binary()) :: Plug.Conn.t()
  defp send_static(conn, path) do
    Logger.log(conn, 200)

    type = MIME.from_path(path)

    conn
    |> put_resp_content_type(type, charset(type))
    |> put_resp_header("cache-control", "no-store")
    |> send_file(200, path)
  end

  @spec charset(binary()) :: binary() | nil
  defp charset("text/" <> _), do: "utf-8"
  defp charset("application/javascript"), do: "utf-8"
  defp charset("application/json"), do: "utf-8"
  defp charset("application/xml"), do: "utf-8"
  defp charset("image/svg+xml"), do: "utf-8"
  defp charset(_type), do: nil

  @spec respond(Plug.Conn.t(), integer(), binary()) :: Plug.Conn.t()
  defp respond(conn, status, body) do
    Logger.log(conn, status)

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(status, body)
  end
end

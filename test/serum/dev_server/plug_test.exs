defmodule Serum.DevServer.PlugTest do
  use ExUnit.Case, async: true
  import Plug.Conn
  import Plug.Test
  import Serum.TestHelper
  alias Serum.DevServer.Plug, as: DevServerPlug

  setup_all do
    site = get_tmp_dir("serum_test_")

    File.mkdir_p!(Path.join(site, "posts"))
    File.write!(Path.join(site, "index.html"), "<h1>Home</h1>")
    File.write!(Path.join(site, "posts/index.html"), "<h1>Posts</h1>")
    File.write!(Path.join(site, "posts/hello world.html"), "<h1>Hello</h1>")
    File.write!(Path.join(site, "image.png"), <<137, 80, 78, 71>>)
    File.write!(Path.join(Path.dirname(site), "serum_test_secret"), "secret")

    on_exit(fn ->
      File.rm_rf!(site)
      File.rm!(Path.join(Path.dirname(site), "serum_test_secret"))
    end)

    {:ok, site: site}
  end

  defp request(ctx, method, path, base \\ "/") do
    opts = DevServerPlug.init(site: ctx.site, base: base)

    method |> conn(path) |> DevServerPlug.call(opts)
  end

  describe "call/2" do
    test "serves the index file of the root directory", ctx do
      conn = request(ctx, :get, "/")

      assert conn.status === 200
      assert conn.resp_body === "<h1>Home</h1>"
      assert get_resp_header(conn, "content-type") === ["text/html; charset=utf-8"]
    end

    test "serves regular files", ctx do
      conn = request(ctx, :get, "/posts/hello%20world.html")

      assert conn.status === 200
      assert conn.resp_body === "<h1>Hello</h1>"
    end

    test "does not add a charset to binary files", ctx do
      conn = request(ctx, :get, "/image.png")

      assert conn.status === 200
      assert get_resp_header(conn, "content-type") === ["image/png"]
    end

    test "serves the index file of a subdirectory", ctx do
      conn = request(ctx, :get, "/posts/")

      assert conn.status === 200
      assert conn.resp_body === "<h1>Posts</h1>"
    end

    test "redirects to a directory URL with a trailing slash", ctx do
      conn = request(ctx, :get, "/posts")

      assert conn.status === 301
      assert get_resp_header(conn, "location") === ["/posts/"]
    end

    test "strips the base URL of the project", ctx do
      assert request(ctx, :get, "/blog/posts/", "/blog/").status === 200
      assert request(ctx, :get, "/posts/", "/blog/").status === 404
    end

    test "responds with 404 if the file does not exist", ctx do
      assert request(ctx, :get, "/nope.html").status === 404
    end

    test "does not serve files outside the site directory", ctx do
      assert request(ctx, :get, "/../serum_test_secret").status === 404
      assert request(ctx, :get, "/%2e%2e/serum_test_secret").status === 404
      assert request(ctx, :get, "/posts/..%2f..%2fserum_test_secret").status === 404
    end

    test "rejects methods other than GET and HEAD", ctx do
      assert request(ctx, :post, "/").status === 405
      assert request(ctx, :head, "/").status === 200
    end
  end
end

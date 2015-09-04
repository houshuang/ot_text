defmodule Server do
  use Plug.Router
  import MultiDef

  plug Plug.Parsers, parsers: [:urlencoded, :json, :multipart],
                       json_decoder: Poison
  plug :match
  plug :dispatch

  post "/rpc" do
    conn = Plug.Conn.fetch_query_params(conn)
    params = conn.body_params
    IO.inspect(params)
    method = params["method"]
    args = fixArgs(params["args"])
    if args == [nil], do: args = []
    if !method || method == "" || !is_list(args) do
      send_resp(conn, 404, "oops")
    else
      res = try do
        :erlang.apply(Text, String.to_atom(method), args)
      catch
        _,e -> %{error: inspect(e)}
      rescue
        e -> %{error: inspect(e)}
      end
      IO.inspect(res)
      send_resp(conn, 200, Poison.encode!(res))
    end
  end

  def fixArgs(args) do
    Enum.map(args, fn
      x when is_list(x) ->
      Enum.map(x, fn
        %{"d" => n} -> %{d: n}
        x -> x
      end)
      x -> x
    end)
  end

  match _ do
    send_resp(conn, 404, "oops")
  end

  def start do
    {:ok, _} = Plug.Adapters.Cowboy.http Server, []
  end
end
# unirest.post('http://example.com/helloworld') .header('Accept', 'application/json') .send({ "Hello": "World!" }) .end(function (response) { console.log(response.body); });

defmodule Serum.Result do
  @moduledoc """
  This module defines types for positive results or errors returned by
  functions in this project.
  """

  import Serum.IOProxy, only: [put_err: 2]

  @type t :: :ok | error()
  @type t(type) :: {:ok, type} | error()

  @type error :: {:error, err_details()}
  @type err_details :: msg_detail() | full_detail() | nest_detail()
  @type msg_detail :: binary()
  @type full_detail :: {binary(), binary(), non_neg_integer()}
  @type nest_detail :: {term(), [error()]}

  @doc """
  Takes a list of result objects (without returned values) and checks if there
  is no error.

  Returns `:ok` if there is no error.

  Returns an aggregated error object if there is one or more errors.
  """
  @spec aggregate([t()], term()) :: t()
  def aggregate(results, from) do
    case Enum.reject(results, &succeeded?/1) do
      [] -> :ok
      errors when is_list(errors) -> {:error, {from, errors}}
    end
  end

  @doc """
  Takes a list of result objects (with returned values) and checks if there is
  no error.

  If there is no error, it returns `{:ok, list}` where `list` is a list of
  returned values.

  Returns an aggregated error object if there is one or more errors.
  """
  @spec aggregate_values([t(term)], term()) :: t([term()])
  def aggregate_values(results, from) do
    case Enum.reject(results, &succeeded?/1) do
      [] -> {:ok, Enum.map(results, &elem(&1, 1))}
      errors when is_list(errors) -> {:error, {from, errors}}
    end
  end

  @spec succeeded?(t() | t(term)) :: boolean()
  defp succeeded?(result)
  defp succeeded?(:ok), do: true
  defp succeeded?({:ok, _}), do: true
  defp succeeded?({:error, _}), do: false

  @doc "Prints an error object in a beautiful format."
  @spec show(t() | t(term()), non_neg_integer()) :: :ok
  def show(result, indent \\ 0)
  def show(:ok, depth), do: put_err(:info, get_message(:ok, depth))
  def show({:ok, _} = result, depth), do: put_err(:info, get_message(result, depth))
  def show(error, depth), do: put_err(:error, get_message(error, depth))

  @doc """
  Gets a human friendly message from the given `result`.

  You can control the indentation level by passing a non-negative integer to
  the `depth` parameter.
  """
  @spec get_message(t() | t(term), non_neg_integer()) :: binary()
  def get_message(result, depth) do
    result |> do_get_message(depth) |> IO.iodata_to_binary()
  end

  @spec do_get_message(t() | t(term), non_neg_integer()) :: IO.chardata()
  defp do_get_message(result, depth)
  defp do_get_message(:ok, depth), do: indented("No error detected", depth)
  defp do_get_message({:ok, _}, depth), do: do_get_message(:ok, depth)

  defp do_get_message({:error, msg}, depth) when is_binary(msg) do
    indented(msg, depth)
  end

  defp do_get_message({:error, {posix, file, line}}, depth) when is_atom(posix) do
    msg = posix |> :file.format_error() |> IO.iodata_to_binary()

    do_get_message({:error, {msg, file, line}}, depth)
  end

  defp do_get_message({:error, {msg, file, 0}}, depth) when is_binary(msg) do
    indented([file, ": ", msg], depth)
  end

  defp do_get_message({:error, {msg, file, line}}, depth) when is_binary(msg) do
    indented([file, ?:, to_string(line), ": ", msg], depth)
  end

  defp do_get_message({:error, {msg, errors}}, depth) when is_list(errors) do
    head = indented(["\x1b[1;31m", to_string(msg), ":\x1b[0m"], depth)
    children = Enum.map(errors, &do_get_message(&1, depth + 1))

    Enum.intersperse([head | children], ?\n)
  end

  @spec indented(IO.chardata(), non_neg_integer()) :: IO.chardata()
  defp indented(str, 0), do: str
  defp indented(str, depth), do: [List.duplicate("  ", depth - 1), "\x1b[31m-\x1b[0m ", str]
end

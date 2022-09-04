defmodule Serum.Post do
  @moduledoc """
  Defines a struct representing a blog post page.

  ## Fields

  * `file`: Source path
  * `title`: Post title
  * `date`: Post date (formatted)
  * `raw_date`: Post date (erlang tuple style)
  * `tags`: A list of tags
  * `url`: Absolute URL of the blog post in the website
  * `canonical_url`: Custom canonical URL of the blog post
  * `html`: Post contents converted into HTML
  * `preview`: Preview text of the post
  * `output`: Destination path
  """

  alias Serum.Fragment
  alias Serum.Post.PreviewGenerator
  alias Serum.Project
  alias Serum.Renderer
  alias Serum.Result
  alias Serum.Tag
  alias Serum.Template
  alias Serum.Template.Storage, as: TS

  @type t :: %__MODULE__{
          file: binary(),
          title: binary(),
          date: binary(),
          raw_date: :calendar.datetime(),
          tags: [Tag.t()],
          url: binary(),
          canonical_url: binary(),
          html: binary(),
          preview: binary(),
          output: binary(),
          extras: map(),
          template: binary() | nil
        }

  defstruct [
    :file,
    :title,
    :date,
    :raw_date,
    :tags,
    :url,
    :canonical_url,
    :html,
    :preview,
    :output,
    :extras,
    :template
  ]

  @spec new(binary(), {map(), map()}, binary(), Project.t()) :: t()
  def new(path, {header, extras}, html, %Project{} = proj) do
    tags = Tag.batch_create(header[:tags] || [], proj)
    datetime = header[:date]
    date_str = Timex.format!(datetime, proj.date_format)
    raw_date = to_erl_datetime(datetime)
    preview = PreviewGenerator.generate_preview(html, proj.preview_length)
    {url, output} = path |> Path.basename(".md") |> url_and_output(proj)

    %__MODULE__{
      file: path,
      title: header[:title],
      tags: tags,
      html: html,
      preview: preview,
      raw_date: raw_date,
      date: date_str,
      url: url,
      canonical_url: header[:canonical_url],
      output: output,
      template: header[:template],
      extras: extras
    }
  end

  @spec compact(t()) :: map()
  def compact(%__MODULE__{} = post) do
    post
    |> Map.drop(~w(__struct__ file html output)a)
    |> Map.put(:type, :post)
  end

  @spec to_erl_datetime(term()) :: :calendar.datetime()
  defp to_erl_datetime(obj) do
    case Timex.to_erl(obj) do
      {{_y, _m, _d}, {_h, _i, _s}} = erl_datetime -> erl_datetime
      {_y, _m, _d} = erl_date -> {erl_date, {0, 0, 0}}
      _ -> {{0, 1, 1}, {0, 0, 0}}
    end
  end

  @spec url_and_output(binary(), Project.t()) :: {binary(), binary()}
  defp url_and_output(basename, proj) do
    if proj.pretty_urls in [true, :posts] do
      {
        Path.join([proj.base_url, proj.posts_path, basename]),
        Path.join([proj.dest, proj.posts_path, basename, "index.html"])
      }
    else
      {
        Path.join([proj.base_url, proj.posts_path, basename <> ".html"]),
        Path.join([proj.dest, proj.posts_path, basename <> ".html"])
      }
    end
  end

  @spec to_fragment(t()) :: Result.t(Fragment.t())
  def to_fragment(post) do
    metadata = compact(post)
    template_name = post.template || "post"
    bindings = [page: metadata, contents: post.html]

    with %Template{} = template <- TS.get(template_name, :template),
         {:ok, html} <- Renderer.render_fragment(template, bindings) do
      Fragment.new(post.file, post.output, metadata, html)
    else
      nil -> {:error, "the template \"#{template_name}\" is not available"}
      {:error, _} = error -> error
    end
  end

  defimpl Fragment.Source do
    alias Serum.Post
    alias Serum.Result

    @spec to_fragment(Post.t()) :: Result.t(Fragment.t())
    def to_fragment(post) do
      Post.to_fragment(post)
    end
  end
end

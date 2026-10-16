defmodule Mercator.Pdf do
  @moduledoc """
  PDF documents with Typst (#17, #104): offers and order confirmations.

  The `typst` program runs as a separate process (`config :mercator,
  :typst`, default `typst` from the PATH; pinned in `.tool-versions`).
  A template from `priv/typst/` is compiled in a temporary directory
  together with its data as `data.json` and the brand logo, so the
  template sees nothing else of the file system.
  """

  @doc """
  Renders `priv/typst/<template>.typ` with `data` (JSON-encodable; the
  template reads it as `data.json`). The brand logo is available to the
  template as `data.brand.logo`. Returns `{:ok, pdf_binary}` or
  `{:error, message}`.
  """
  # sobelow_skip ["Traversal.FileModule"]
  def render(template, data) when is_binary(template) do
    dir = Path.join(System.tmp_dir!(), "mercator-pdf-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)

    try do
      File.cp!(template_path(template), Path.join(dir, "document.typ"))
      data = put_logo(data, dir)
      File.write!(Path.join(dir, "data.json"), Jason.encode!(data))
      compile(dir)
    after
      File.rm_rf(dir)
    end
  end

  defp template_path(template),
    do: Application.app_dir(:mercator, ["priv", "typst", "#{template}.typ"])

  # copies the brand logo next to the document, if Typst can read it
  # sobelow_skip ["Traversal.FileModule"]
  defp put_logo(%{brand: brand} = data, dir) do
    logo =
      with path when is_binary(path) <- Mercator.Brand.image_path(:logo),
           source = Application.app_dir(:mercator, Path.join("priv/static", path)),
           true <- File.regular?(source),
           name = "logo" <> Path.extname(source),
           :ok <- File.cp(source, Path.join(dir, name)) do
        name
      else
        _ -> nil
      end

    %{data | brand: Map.put(brand, :logo, logo)}
  end

  defp put_logo(data, _dir), do: data

  # sobelow_skip ["CI.System", "Traversal.FileModule"]
  defp compile(dir) do
    args = ["compile", "--root", dir, Path.join(dir, "document.typ"), Path.join(dir, "out.pdf")]

    case System.cmd(executable(), args, stderr_to_stdout: true) do
      {_output, 0} -> File.read(Path.join(dir, "out.pdf"))
      {output, _status} -> {:error, String.trim(output)}
    end
  rescue
    error in ErlangError -> {:error, "typst could not be started: #{Exception.message(error)}"}
  end

  defp executable, do: Application.get_env(:mercator, :typst, "typst")
end

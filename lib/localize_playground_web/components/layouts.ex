defmodule LocalizePlaygroundWeb.Layouts do
  use LocalizePlaygroundWeb, :html

  embed_templates("layouts/*")

  def tab_href(nil, path), do: path
  def tab_href("", path), do: path

  def tab_href(locale, path) when is_binary(locale) do
    if locale == "en", do: path, else: path <> "?locale=" <> URI.encode_www_form(locale)
  end

  def tab_href(_, path), do: path
end

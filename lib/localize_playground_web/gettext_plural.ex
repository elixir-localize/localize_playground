defmodule LocalizePlaygroundWeb.GettextPlural do
  @moduledoc """
  Custom `Gettext.Plural` adapter for the playground. Delegates to
  `Gettext.Plural` for known locales, but transparently strips the
  script/territory suffix so locales like `zh-Hans`, `zh-Hant`,
  `pt-BR`, `en-GB` etc. fall back to their language-only plural rules.
  """

  @behaviour Gettext.Plural

  @impl true
  def nplurals(locale) do
    Gettext.Plural.nplurals(locale)
  rescue
    Gettext.Plural.UnknownLocaleError -> Gettext.Plural.nplurals(base(locale))
  end

  @impl true
  def plural(locale, n) do
    Gettext.Plural.plural(locale, n)
  rescue
    Gettext.Plural.UnknownLocaleError -> Gettext.Plural.plural(base(locale), n)
  end

  defp base(locale) when is_binary(locale) do
    locale |> String.split(~r/[-_]/) |> hd()
  end
end

defmodule LocalizePlaygroundWeb.UiLocale do
  @moduledoc """
  Playground UI locale — the language the labels, field names, and
  display-name values are shown in. Distinct from the "explored"
  locale being demonstrated on each tab.

  Curated list of supported UI locales with their native display
  names (written in the locale itself) and an optional flag emoji
  used when the locale carries an unambiguous territory.
  """

  @catalog [
    %{id: "ar", territory: :SA},
    %{id: "de", territory: :DE},
    %{id: "en", territory: nil, flag: "🇺🇸🇬🇧"},
    %{id: "en-GB", territory: :GB},
    %{id: "es", territory: :ES},
    %{id: "es-MX", territory: :MX},
    %{id: "fr", territory: :FR},
    %{id: "fr-CA", territory: :CA},
    %{id: "he", territory: :IL},
    %{id: "hi", territory: :IN},
    %{id: "it", territory: :IT},
    %{id: "ja", territory: :JP},
    %{id: "ko", territory: :KR},
    %{id: "nl", territory: :NL},
    %{id: "pl", territory: :PL},
    %{id: "pt", territory: :PT},
    %{id: "pt-BR", territory: :BR},
    %{id: "ru", territory: :RU},
    %{id: "sv", territory: :SE},
    %{id: "th", territory: :TH},
    %{id: "tr", territory: :TR},
    %{id: "uk", territory: :UA},
    %{id: "vi", territory: :VN},
    %{id: "zh-Hans", territory: :CN},
    %{id: "zh-Hant", territory: :TW}
  ]

  @default "en"
  # Matches Localize.Plug.PutLocale's default session key so the plug's
  # `:session` source reads what we write.
  @session_key "localize_locale"

  @doc "Session key used for persisting the user's picked locale."
  def session_key, do: @session_key

  @doc "Default UI locale atom used when nothing else matches."
  def default, do: @default

  @doc "All locale IDs the picker offers."
  @spec all() :: [String.t()]
  def all, do: Enum.map(@catalog, & &1.id)

  @doc """
  Returns a `{id, label, flag_or_nil}` list suitable for rendering the
  picker. The label is the locale's display name *in its own language*
  (language_display: :dialect so that e.g. `en-GB` shows as
  "British English" rather than "English (United Kingdom)"). The flag
  is a regional-indicator emoji when the locale carries a single
  territory, otherwise `nil`.
  """
  @spec picker_options() :: [{String.t(), String.t(), String.t() | nil}]
  def picker_options do
    Enum.map(@catalog, fn entry ->
      label = native_display_name(entry.id)
      {entry.id, label, flag_for(entry)}
    end)
  end

  @doc """
  Returns the locale's display name in its own language (`locale:`
  option = the locale itself, `language_display: :dialect`).
  """
  @spec native_display_name(String.t()) :: String.t()
  def native_display_name(locale_id) do
    options = [locale: locale_id, language_display: :dialect]

    case Localize.Locale.LocaleDisplay.display_name(locale_id, options) do
      {:ok, name} -> name
      _ -> locale_id
    end
  rescue
    _ -> locale_id
  end

  @doc """
  Returns `true` when the picker's catalog knows about this locale.
  """
  def known?(locale_id), do: Enum.any?(@catalog, &(&1.id == locale_id))

  @doc """
  Builds a flag emoji from a 2-letter territory atom. Returns `nil`
  when no territory is associated.
  """
  def flag_for(%{flag: flag}) when is_binary(flag), do: flag
  def flag_for(%{territory: nil}), do: nil

  def flag_for(%{territory: territory}) when is_atom(territory),
    do: flag_emoji(Atom.to_string(territory))

  defp flag_emoji(<<a, b>>) when a in ?A..?Z and b in ?A..?Z do
    <<127_397 + a::utf8, 127_397 + b::utf8>>
  end

  defp flag_emoji(_), do: nil
end

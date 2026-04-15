defmodule LocalizePlaygroundWeb.UiLocaleHook do
  @moduledoc """
  LiveView on_mount hook: pull the UI locale out of the session, apply
  it to the process with `Localize.put_locale/1`, and stash it as
  `@ui_locale` / `@ui_locale_label` / `@ui_locale_flag` /
  `@ui_locale_options` on the socket so the layout can render the
  picker.
  """

  import Phoenix.Component, only: [assign: 3]

  alias LocalizePlaygroundWeb.UiLocale

  def on_mount(:default, _params, session, socket) do
    ui_locale = resolve(session)
    Localize.put_locale(ui_locale)
    Gettext.put_locale(LocalizePlaygroundWeb.Gettext, ui_locale)

    {:cont,
     socket
     |> assign(:ui_locale, ui_locale)
     |> assign(:ui_locale_label, UiLocale.native_display_name(ui_locale))
     |> assign(:ui_locale_flag, flag_for(ui_locale))
     |> assign(:ui_locale_options, UiLocale.picker_options())
     |> assign(:current_path, "/")}
  end

  defp resolve(session) do
    desired = Map.get(session || %{}, UiLocale.session_key()) || Localize.default_locale()

    case Localize.LanguageTag.best_match(desired, UiLocale.all()) do
      {:ok, matched, _distance} -> matched
      _ -> UiLocale.default()
    end
  rescue
    _ -> UiLocale.default()
  end

  defp flag_for(locale_id) do
    Enum.find_value(UiLocale.picker_options(), fn {id, _label, flag} ->
      if id == locale_id, do: flag
    end)
  end
end

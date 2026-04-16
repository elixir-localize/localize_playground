defmodule LocalizePlaygroundWeb.Gettext do
  @moduledoc """
  Gettext backend for the playground's static UI text.

  All translatable strings belong to the `"localize_playground"` domain
  (we set `default_domain:` below so `gettext/1,2` automatically routes
  there without needing `dgettext/3` at every call site).

  Interpolation is delegated to `Localize.Gettext.Interpolation`, which
  treats the msgid as an ICU MessageFormat 2 (MF2) message and formats
  it via `Localize.Message`. This means every message in our `.po`
  files is a valid MF2 message — we dogfood both Gettext and MF2.

  """

  use Gettext.Backend,
    otp_app: :localize_playground,
    default_domain: "localize_playground",
    interpolation: Localize.Gettext.Interpolation,
    plural_forms: LocalizePlaygroundWeb.GettextPlural,
    split_module_by: [:locale],
    split_module_compilation: :parallel
end

# NOTE: We never call Gettext's `ngettext/3` in this app — pluralization
# is the job of MF2, which has built-in `.match` selectors for plural
# categories. The `plural_forms` module above exists purely so Gettext
# can compile .po headers for locales whose BCP-47 form (like
# `zh-Hans` or `pt-BR`) isn't in the default `Gettext.Plural` table.

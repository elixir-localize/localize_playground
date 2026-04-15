defmodule LocalizePlaygroundWeb.PatternReference do
  @moduledoc """
  Slide-out reference panel listing CLDR date/time/zone pattern characters,
  their meaning, and short examples. Opened from the Custom pattern kind on
  the Dates & Times tab.
  """

  use Phoenix.Component

  @sections [
    %{
      title: "Year",
      rows: [
        {"y", "Calendar year. Truncates to min digits.", "2026 · 26"},
        {"yy", "2-digit year.", "26"},
        {"yyyy", "4-digit year (zero-padded).", "2026"},
        {"Y", "Week-based year (ISO).", "2026"},
        {"u", "Extended year.", "2026"},
        {"U", "Cyclic year name (e.g., Chinese zodiac).", "丙午"},
        {"r", "Related Gregorian year.", "2026"}
      ]
    },
    %{
      title: "Quarter",
      rows: [
        {"Q", "Quarter number.", "2"},
        {"QQ", "Quarter number, 2-digit.", "02"},
        {"QQQ", "Abbreviated quarter name.", "Q2"},
        {"QQQQ", "Wide quarter name.", "2nd quarter"},
        {"q", "Stand-alone quarter (same but in isolation).", "2"}
      ]
    },
    %{
      title: "Month",
      rows: [
        {"M", "Month number.", "4"},
        {"MM", "Month number, 2-digit.", "04"},
        {"MMM", "Abbreviated month name.", "Apr"},
        {"MMMM", "Wide month name.", "April"},
        {"MMMMM", "Narrow month name.", "A"},
        {"L", "Stand-alone month number.", "4"},
        {"LLLL", "Stand-alone wide month name.", "April"}
      ]
    },
    %{
      title: "Week",
      rows: [
        {"w", "Week of year.", "15"},
        {"ww", "Week of year, 2-digit.", "15"},
        {"W", "Week of month.", "3"}
      ]
    },
    %{
      title: "Day",
      rows: [
        {"d", "Day of month.", "15"},
        {"dd", "Day of month, 2-digit.", "15"},
        {"D", "Day of year.", "105"},
        {"F", "Day of week in month (e.g., 3rd Tuesday).", "3"},
        {"g", "Modified Julian Day.", "2460785"}
      ]
    },
    %{
      title: "Weekday",
      rows: [
        {"E", "Abbreviated day name.", "Wed"},
        {"EEEE", "Wide day name.", "Wednesday"},
        {"EEEEE", "Narrow day name.", "W"},
        {"e", "Local day of week (locale-dependent start).", "4"},
        {"c", "Stand-alone day of week.", "4"},
        {"cccc", "Stand-alone wide day name.", "Wednesday"}
      ]
    },
    %{
      title: "Period / AM-PM",
      rows: [
        {"a", "AM/PM marker.", "PM"},
        {"aaaa", "Wide AM/PM marker.", "in the afternoon"},
        {"b", "AM/PM + noon/midnight.", "noon"},
        {"B", "Flexible day period.", "in the afternoon"}
      ]
    },
    %{
      title: "Hour",
      rows: [
        {"h", "Hour 1–12.", "6"},
        {"hh", "Hour 1–12, 2-digit.", "06"},
        {"H", "Hour 0–23.", "18"},
        {"HH", "Hour 0–23, 2-digit.", "18"},
        {"K", "Hour 0–11.", "6"},
        {"k", "Hour 1–24.", "18"},
        {"j", "Locale's preferred hour field (use in skeletons).", "6 PM"},
        {"J", "Locale's preferred hour without day period.", "18"}
      ]
    },
    %{
      title: "Minute / Second",
      rows: [
        {"m", "Minute.", "9"},
        {"mm", "Minute, 2-digit.", "09"},
        {"s", "Second.", "7"},
        {"ss", "Second, 2-digit.", "07"},
        {"S", "Fractional second.", "1"},
        {"SSS", "Milliseconds.", "123"},
        {"A", "Milliseconds of day.", "65430000"}
      ]
    },
    %{
      title: "Time zone — specific",
      rows: [
        {"z", "Short specific non-location.", "PT"},
        {"zzzz", "Long specific non-location.", "Pacific Time"},
        {"Z", "ISO 8601 basic (-0800).", "-0800"},
        {"ZZZZ", "Long localized GMT.", "GMT-08:00"},
        {"ZZZZZ", "ISO 8601 extended (-08:00) or 'Z'.", "-08:00"},
        {"O", "Short localized GMT.", "GMT-8"},
        {"OOOO", "Long localized GMT.", "GMT-08:00"}
      ]
    },
    %{
      title: "Time zone — generic & location",
      rows: [
        {"v", "Short generic non-location.", "PT"},
        {"vvvv", "Long generic non-location.", "Pacific Time"},
        {"V", "Short time zone ID.", "uslax"},
        {"VV", "Long time zone ID.", "America/Los_Angeles"},
        {"VVV", "Exemplar city.", "Los Angeles"},
        {"VVVV", "Generic location format.", "Los Angeles Time"},
        {"X", "ISO 8601 with Z for UTC (-08, -0800, Z).", "-08"},
        {"x", "ISO 8601 numeric (-0800, no Z).", "-0800"}
      ]
    },
    %{
      title: "Era",
      rows: [
        {"G", "Era abbreviation.", "AD"},
        {"GGGG", "Era wide.", "Anno Domini"},
        {"GGGGG", "Era narrow.", "A"}
      ]
    },
    %{
      title: "Literals & escaping",
      rows: [
        {"'text'", "Literal text inside single quotes.", "'at' → at"},
        {"''", "Escaped single quote.", "it's → it''s"},
        {":", "Time separator placeholder (locale-adjusted).", ":"}
      ]
    }
  ]

  def panel(assigns) do
    assigns = assign(assigns, :sections, @sections)

    ~H"""
    <div id="pattern-reference-panel" class="lp-hexdocs-panel lp-pattern-panel" phx-hook="PatternReferencePanel" aria-hidden="true">
      <div class="lp-hexdocs-backdrop" data-pattern-close></div>
      <aside class="lp-hexdocs-aside" role="dialog" aria-modal="true" aria-label="CLDR pattern reference">
        <header class="lp-hexdocs-header">
          <strong class="lp-pattern-title">CLDR format pattern reference</strong>
          <button type="button" class="lp-hexdocs-close" data-pattern-close aria-label="Close">✕</button>
        </header>
        <div class="lp-pattern-body">
          <p class="lp-pattern-intro">
            Date/time patterns use unquoted letters as format codes. Repeat a letter to change width; wrap literal text in single quotes. See
            <a href="https://cldr.unicode.org/translation/date-time/date-time-patterns" target="_blank" rel="noopener">CLDR docs</a>
            for the full spec.
          </p>
          <section :for={section <- @sections} class="lp-pattern-section">
            <h3>{section.title}</h3>
            <table class="lp-pattern-table">
              <colgroup>
                <col class="lp-col-pattern" />
                <col />
                <col class="lp-col-example" />
              </colgroup>
              <thead>
                <tr><th>Pattern</th><th>Meaning</th><th>Example</th></tr>
              </thead>
              <tbody>
                <tr :for={{pat, desc, ex} <- section.rows}>
                  <td><code>{pat}</code></td>
                  <td>{desc}</td>
                  <td><code class="lp-pattern-example">{ex}</code></td>
                </tr>
              </tbody>
            </table>
          </section>
        </div>
      </aside>
    </div>
    """
  end
end

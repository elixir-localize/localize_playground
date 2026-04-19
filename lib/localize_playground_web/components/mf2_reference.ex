defmodule LocalizePlaygroundWeb.MF2Reference do
  @moduledoc """
  Slide-out reference panel summarising MessageFormat 2 (MF2) syntax.
  Opened from the Messages tab by clicking the 📖 button. The content is
  a curated cheat-sheet — see the
  [MF2 spec](https://messageformat.unicode.org/docs/) for the full grammar.
  """

  use Phoenix.Component

  @sections [
    %{
      title: "Simple vs complex messages",
      rows: [
        {"Hello, world!", "Simple message — plain text is a valid message.", "Hello, world!"},
        {"{{Hello, {$name}!}}",
         "Quoted pattern — required when the message has declarations, matchers, or starts with { or .",
         "Hello, Aoife!"},
        {".local $x = {1} {{Value: {$x}}}",
         "Complex message — declarations followed by a quoted pattern.", "Value: 1"}
      ]
    },
    %{
      title: "Placeholders",
      rows: [
        {"{$name}", "Variable reference — binds to the bindings map/keyword.", "Aoife"},
        {"{|literal text|}", "Literal — explicit quoted value. Rare in practice.",
         "literal text"},
        {"{42}", "Number literal.", "42"},
        {"{$x :number}", "Annotated variable — applies a function to the value.", "3"},
        {"{$x :number minimumFractionDigits=2}", "Annotated with options.", "3.00"}
      ]
    },
    %{
      title: "Built-in functions",
      rows: [
        {":string", "Selects/formats a string value (default for strings).", ""},
        {":number",
         "Formats a number. Options: minimumFractionDigits, maximumFractionDigits, minimumIntegerDigits, useGrouping, signDisplay, notation.",
         "1,234.50"},
        {":integer", "Formats an integer.", "1,234"},
        {":currency",
         "Formats as currency. Options: currency=ISO, currencyDisplay=code|symbol|name|narrowSymbol.",
         "$1,234.56"},
        {":date", "Formats a date. Options: dateStyle=short|medium|long|full.", "Apr 15, 2026"},
        {":time", "Formats a time. Options: timeStyle=short|medium|long|full.", "3:04 PM"},
        {":datetime", "Formats a date and time.", "Apr 15, 2026, 3:04 PM"}
      ]
    },
    %{
      title: "Declarations",
      rows: [
        {".local $x = {expr}", "Bind a local variable to an expression (placeholder).", ""},
        {".input {$x :number}", "Re-annotate an incoming binding with a function/options.", ""}
      ]
    },
    %{
      title: "Selection / matchers",
      rows: [
        {".match $count", "Select a variant based on one or more selectors.", ""},
        {"0 {{No items.}}", "Literal variant — matched when $count == 0.", "No items."},
        {"one {{1 item}}", "Plural keyword variant (:number selector).", "1 item"},
        {"* {{N items.}}", "Default/wildcard variant. Required.", "N items."},
        {".match $a $b\nhi hi {{both hi}}\n* * {{anything}}",
         "Multi-selector — one row per combination. Wildcards * act as catch-alls.", ""}
      ]
    },
    %{
      title: "Markup",
      rows: [
        {"{#link}Click here{/link}",
         "Open / close markup — the formatter can emit structured output (HTML, etc.).", ""},
        {"{#img src=|photo.jpg| /}", "Self-closing markup with options.", ""}
      ]
    },
    %{
      title: "Escaping",
      rows: [
        {"\\{", "Literal open brace.", "{"},
        {"\\}", "Literal close brace.", "}"},
        {"\\\\", "Literal backslash.", "\\"},
        {"\\|", "Literal pipe inside |...| literals.", "|"}
      ]
    },
    %{
      title: "Common patterns",
      rows: [
        {".match {$count :number}\none {{1 unread}}\n* {{{$count} unread}}",
         "Plural message using CLDR plural categories.", "3 unread"},
        {".match {$gender :string}\nfeminine {{She}}\nmasculine {{He}}\n* {{They}}",
         "Gender/string selection.", "They"},
        {"{{Total: {$amount :currency currency=USD}}}", "Currency formatting with options.",
         "Total: $1,234.56"},
        {"{{Today is {$d :date dateStyle=full}}}", "Long date.",
         "Today is Wednesday, April 15, 2026"}
      ]
    }
  ]

  def panel(assigns) do
    assigns = assign(assigns, :sections, @sections)

    ~H"""
    <div id="mf2-reference-panel" class="lp-hexdocs-panel lp-pattern-panel" phx-hook="MF2ReferencePanel" aria-hidden="true">
      <div class="lp-hexdocs-backdrop" data-mf2-close></div>
      <aside class="lp-hexdocs-aside" role="dialog" aria-modal="true" aria-label="MF2 syntax reference">
        <header class="lp-hexdocs-header">
          <strong class="lp-pattern-title">MessageFormat 2 syntax reference</strong>
          <button type="button" class="lp-hexdocs-close" data-mf2-close aria-label="Close">✕</button>
        </header>
        <div class="lp-pattern-body">
          <p class="lp-pattern-intro">
            MF2 is a two-level grammar: messages can be plain text (a simple message) or a pattern wrapped in <code>&#123;&#123;&#125;&#125;</code> with optional declarations and matchers. See the
            <a href="https://messageformat.unicode.org/docs/" target="_blank" rel="noopener">official spec</a>
            for the full grammar.
          </p>
          <section :for={section <- @sections} class="lp-pattern-section">
            <h3>{section.title}</h3>
            <table class="lp-pattern-table">
              <colgroup>
                <col class="lp-col-mf2-pattern" />
                <col />
                <col class="lp-col-example" />
              </colgroup>
              <thead>
                <tr><th>Syntax</th><th>Meaning</th><th>Example output</th></tr>
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

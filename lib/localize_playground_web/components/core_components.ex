defmodule LocalizePlaygroundWeb.CoreComponents do
  @moduledoc """
  Small shared components for the playground UI.
  """

  use Phoenix.Component

  @doc """
  A titled content section.
  """
  attr :title, :string, required: true
  attr :class, :string, default: nil
  slot :inner_block, required: true

  def section(assigns) do
    ~H"""
    <section class={["lp-section", @class]}>
      <h2>{@title}</h2>
      {render_slot(@inner_block)}
    </section>
    """
  end

  @doc """
  A labelled form control stacked vertically.
  """
  attr :label, :string, required: true
  attr :for, :string, default: nil
  attr :hint, :string, default: nil
  slot :inner_block, required: true

  def field(assigns) do
    ~H"""
    <label class="lp-field" for={@for}>
      <span class="lp-field-label">{@label}</span>
      {render_slot(@inner_block)}
      <span :if={@hint} class="lp-field-hint">{@hint}</span>
    </label>
    """
  end
end

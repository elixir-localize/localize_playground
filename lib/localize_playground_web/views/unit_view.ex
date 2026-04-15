defmodule LocalizePlaygroundWeb.UnitView do
  @moduledoc """
  Pure helpers that wrap `Localize.Unit` functions for the playground UI.

  Handles unit name composition from (power, prefix, base) tuples,
  formatting, conversion, and lookup of CLDR unit metadata.
  """

  alias Localize.Unit

  # A curated set of SI prefixes we expose as dropdown entries.
  # Arranged smallest → largest. Each entry is `{atom_id, cldr_name}`
  # where cldr_name is the prefix fragment in CLDR unit syntax.
  @si_prefixes [
    :none,
    :yocto,
    :zepto,
    :atto,
    :femto,
    :pico,
    :nano,
    :micro,
    :milli,
    :centi,
    :deci,
    :deka,
    :hecto,
    :kilo,
    :mega,
    :giga,
    :tera,
    :peta,
    :exa,
    :zetta,
    :yotta
  ]

  @powers [
    :none,
    :square,
    :cubic,
    :pow4,
    :pow5,
    :pow6,
    :pow7,
    :pow8,
    :pow9
  ]

  @doc """
  Returns the list of SI prefix option ids (e.g., `:none`, `:kilo`).
  """
  def si_prefixes, do: @si_prefixes

  @doc """
  Returns the list of power option ids.
  """
  def powers, do: @powers

  @doc """
  Returns a map of `category_string => [sorted unit names]` for
  selecting a base unit. Limited to the base unit name (no prefix
  or power applied).
  """
  @spec units_by_category() :: [{String.t(), [String.t()]}]
  def units_by_category do
    Unit.known_units_by_category()
    |> Enum.map(fn {cat, units} -> {cat, Enum.sort(units)} end)
    |> Enum.sort_by(fn {cat, _} -> cat end)
  end

  @doc """
  Returns a flat sorted list of all base unit names.
  """
  @spec all_units() :: [String.t()]
  def all_units do
    Unit.known_units_by_category()
    |> Enum.flat_map(fn {_cat, units} -> units end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  @doc """
  Composes a CLDR unit name from an optional power, prefix, and base.

  * `power` is one of `:none`, `:square`, `:cubic`, `:pow4`..`:pow9`.
  * `prefix` is one of the SI prefix ids or `:none`.
  * `base` is a base unit name string (e.g., `"meter"`).
  """
  @spec compose_unit(atom(), atom(), String.t()) :: String.t()
  def compose_unit(power, prefix, base) when is_binary(base) do
    prefix_str = prefix_fragment(prefix)
    power_str = power_fragment(power)
    power_str <> prefix_str <> base
  end

  @doc """
  Returns the CLDR prefix string for the given SI prefix id, or `""`.
  """
  def prefix_fragment(:none), do: ""
  def prefix_fragment(prefix) when is_atom(prefix), do: Atom.to_string(prefix)

  @doc """
  Returns the CLDR power prefix (e.g., `"square-"`) for the given id, or `""`.
  """
  def power_fragment(:none), do: ""
  def power_fragment(:square), do: "square-"
  def power_fragment(:cubic), do: "cubic-"

  def power_fragment(atom) when is_atom(atom) do
    case Atom.to_string(atom) do
      "pow" <> n -> "pow#{n}-"
      _ -> ""
    end
  end

  @doc """
  Builds a `Localize.Unit` struct and formats it using the locale.

  Returns `{:ok, %{unit: unit, formatted: string, display_name: string, category: string}}`
  or `{:error, message}`.
  """
  @spec build_and_format(number() | Decimal.t(), String.t(), atom() | String.t()) ::
          {:ok, map()} | {:error, String.t()}
  def build_and_format(value, unit_name, locale) when is_binary(unit_name) do
    with {:ok, unit} <- Unit.new(value, unit_name),
         {:ok, formatted} <- Unit.to_string(unit, locale: locale),
         {:ok, display} <- Unit.display_name(unit_name, locale: locale),
         {:ok, category} <- Unit.unit_category(unit_name) do
      {:ok, %{unit: unit, formatted: formatted, display_name: display, category: category}}
    else
      {:error, %{__exception__: true} = exception} ->
        {:error, Exception.message(exception)}

      {:error, message} when is_binary(message) ->
        {:error, message}

      {:error, other} ->
        {:error, inspect(other)}
    end
  end

  @doc """
  Converts a `Localize.Unit` struct to the target unit name and formats the result.

  Returns `{:ok, %{unit: converted, formatted: string}}` or `{:error, message}`.
  """
  @spec convert(Unit.t(), String.t(), atom() | String.t()) ::
          {:ok, map()} | {:error, String.t()}
  def convert(%Unit{} = unit, target, locale) when is_binary(target) do
    with {:ok, converted} <- Unit.convert(unit, target),
         {:ok, formatted} <- Unit.to_string(converted, locale: locale) do
      {:ok, %{unit: converted, formatted: formatted}}
    else
      {:error, %{__exception__: true} = exception} ->
        {:error, Exception.message(exception)}

      {:error, message} when is_binary(message) ->
        {:error, message}

      {:error, other} ->
        {:error, inspect(other)}
    end
  end

  @doc """
  Converts a unit to the preferred unit for the given measurement system.
  """
  @spec convert_measurement_system(Unit.t(), atom(), atom() | String.t()) ::
          {:ok, map()} | {:error, String.t()}
  def convert_measurement_system(%Unit{} = unit, system, locale)
      when system in [:metric, :us, :uk] do
    with {:ok, converted} <- Unit.convert_measurement_system(unit, system),
         {:ok, formatted} <- Unit.to_string(converted, locale: locale) do
      {:ok, %{unit: converted, formatted: formatted}}
    else
      {:error, %{__exception__: true} = exception} ->
        {:error, Exception.message(exception)}

      {:error, message} when is_binary(message) ->
        {:error, message}

      {:error, other} ->
        {:error, inspect(other)}
    end
  end

  @doc """
  Parses a numeric input string to a number.
  """
  @spec parse_number(String.t() | nil) :: {:ok, number()} | {:error, String.t()}
  def parse_number(nil), do: {:error, "Enter a number"}

  def parse_number(string) when is_binary(string) do
    trimmed = String.trim(string)

    cond do
      trimmed == "" ->
        {:error, "Enter a number"}

      true ->
        case Float.parse(trimmed) do
          {float, ""} ->
            case Integer.parse(trimmed) do
              {int, ""} -> {:ok, int}
              _ -> {:ok, float}
            end

          _ ->
            {:error, "Not a valid number: #{trimmed}"}
        end
    end
  end
end

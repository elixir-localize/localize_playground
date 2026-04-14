defmodule LocalizePlaygroundWeb.NumberView do
  @moduledoc """
  Pure helpers that wrap `Localize.Number` functions for the playground UI.

  All formatting is performed here so the LiveView can focus on state
  management. Functions return `{:ok, string}` or `{:error, message}`
  tuples ready for rendering.

  """

  alias Localize.Number
  alias Localize.Number.{Format, Rbnf, Symbol}
  alias Localize.Number.Format.Compiler

  @doc """
  Returns all CLDR locale identifiers as lower-cased strings sorted
  alphabetically. Suitable for populating a `<datalist>`.
  """
  @spec locale_options() :: [String.t()]
  def locale_options do
    Localize.all_locale_ids()
    |> Enum.map(&Atom.to_string/1)
    |> Enum.sort()
  end

  @doc """
  Returns the list of known ISO 4217 currency codes sorted alphabetically.
  """
  @spec currency_options() :: [String.t()]
  def currency_options do
    Localize.Currency.known_currency_codes()
    |> Enum.map(&Atom.to_string/1)
    |> Enum.sort()
  end

  @doc """
  Returns the list of RBNF rule names for a locale, or `[]` on any error.
  """
  @spec rbnf_rules(atom() | String.t()) :: [String.t()]
  def rbnf_rules(locale) do
    case Rbnf.rule_names_for_locale(locale) do
      {:ok, names} -> Enum.sort(names)
      _ -> []
    end
  end

  @doc """
  Parses a number from a user input string. Returns `{:ok, number}` or
  `{:error, message}`.
  """
  @spec parse_number(String.t() | nil) :: {:ok, number()} | {:error, String.t()}
  def parse_number(string) when is_binary(string) do
    trimmed = String.trim(string)

    cond do
      trimmed == "" ->
        {:error, "Enter a number"}

      true ->
        case Float.parse(trimmed) do
          {float, ""} ->
            if float == Float.round(float) and not String.contains?(trimmed, ".") do
              case Integer.parse(trimmed) do
                {int, ""} -> {:ok, int}
                _ -> {:ok, float}
              end
            else
              {:ok, float}
            end

          _ ->
            {:error, "Invalid number: #{inspect(trimmed)}"}
        end
    end
  end

  def parse_number(_), do: {:error, "Enter a number"}

  @doc """
  Formats a number using the supplied options. Returns `{:ok, string}` or
  `{:error, message}`.
  """
  @spec format(number(), keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def format(number, options) do
    case Number.to_string(number, options) do
      {:ok, string} -> {:ok, string}
      {:error, {_mod, message}} -> {:error, message}
      {:error, exception} -> {:error, Exception.message(exception)}
    end
  end

  @doc """
  Formats a range of numbers. Returns `{:ok, string}` or `{:error, message}`.
  """
  @spec format_range(number(), number(), keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def format_range(a, b, options) do
    case Number.to_range_string(a, b, options) do
      {:ok, string} -> {:ok, string}
      {:error, {_mod, message}} -> {:error, message}
      {:error, exception} -> {:error, Exception.message(exception)}
    end
  end

  @doc """
  Formats a number with one of the boundary functions
  (`:approximately`, `:at_least`, `:at_most`).
  """
  @spec format_boundary(atom(), number(), keyword()) ::
          {:ok, String.t()} | {:error, String.t()}
  def format_boundary(kind, number, options) do
    function =
      case kind do
        :approximately -> &Number.to_approximately_string/2
        :at_least -> &Number.to_at_least_string/2
        :at_most -> &Number.to_at_most_string/2
      end

    case function.(number, options) do
      {:ok, string} -> {:ok, string}
      {:error, {_mod, message}} -> {:error, message}
      {:error, exception} -> {:error, Exception.message(exception)}
    end
  end

  @doc """
  Formats a number using an RBNF rule.
  """
  @spec format_rbnf(number(), String.t(), atom() | String.t()) ::
          {:ok, String.t()} | {:error, String.t()}
  def format_rbnf(number, rule, locale) do
    case Rbnf.to_string(number, rule, locale: locale) do
      {:ok, string} ->
        {:ok, string}

      {:error, {_mod, message}} ->
        {:error, message}

      {:error, exception} when is_exception(exception) ->
        {:error, Exception.message(exception)}

      other ->
        {:error, inspect(other)}
    end
  end

  @doc """
  Resolves the pattern string associated with the given style and locale.

  Returns the pattern `{:ok, pattern_or_term}` or `{:error, message}`.
  """
  @spec resolve_pattern(atom() | String.t(), atom()) ::
          {:ok, term()} | {:error, String.t()}
  def resolve_pattern(locale, style) do
    case Format.formats_for(locale) do
      {:ok, formats} ->
        {:ok, Map.get(formats, style)}

      {:error, exception} when is_exception(exception) ->
        {:error, Exception.message(exception)}

      {:error, {_mod, message}} ->
        {:error, message}
    end
  end

  @doc """
  Parses a format pattern string into a `%Localize.Number.Format.Meta{}`
  struct, returning `{:ok, meta}` or `{:error, message}`.
  """
  @spec pattern_metadata(String.t()) :: {:ok, struct()} | {:error, String.t()}
  def pattern_metadata(pattern) when is_binary(pattern) do
    try do
      case Compiler.format_to_metadata(pattern) do
        {:ok, meta} -> {:ok, meta}
        {:error, exception} when is_exception(exception) -> {:error, Exception.message(exception)}
        {:error, {_mod, message}} -> {:error, message}
        %_{} = meta -> {:ok, meta}
      end
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  def pattern_metadata(_), do: {:error, "No pattern available"}

  defp canonical_locale_id(locale) do
    case Localize.validate_locale(locale) do
      {:ok, %Localize.LanguageTag{cldr_locale_id: id}} when not is_nil(id) -> id
      _ -> locale
    end
  end

  @doc """
  Extracts the Unicode U-extension subtags (e.g. `-u-nu-arab`, `-u-cu-eur`)
  from a locale string.

  Returns `{:ok, %{nu: atom, cu: atom, ...}}` with only the non-nil subtags
  present, or `:error` if the locale cannot be parsed.
  """
  @spec u_extensions(String.t() | atom()) :: {:ok, map()} | :error
  def u_extensions(locale) do
    case Localize.validate_locale(locale) do
      {:ok, %Localize.LanguageTag{locale: %_{} = u}} ->
        extensions =
          u
          |> Map.from_struct()
          |> Enum.reject(fn {_k, v} -> is_nil(v) end)
          |> Map.new()

        {:ok, extensions}

      _ ->
        :error
    end
  end

  @doc """
  Returns the number symbols (decimal, group, percent, etc.) for a
  locale, or `nil` on any error. Picks the `:latn` system if present,
  otherwise the first available system.
  """
  @spec locale_symbols(atom() | String.t(), atom() | nil) ::
          {atom(), Localize.Number.Symbol.t()} | nil
  def locale_symbols(locale, preferred_system \\ nil) do
    locale_id = canonical_locale_id(locale)

    case Symbol.number_symbols_for(locale_id) do
      {:ok, systems} when map_size(systems) > 0 ->
        system =
          cond do
            preferred_system && Map.has_key?(systems, preferred_system) -> preferred_system
            Map.has_key?(systems, :latn) -> :latn
            true -> systems |> Map.keys() |> List.first()
          end

        {system, Map.get(systems, system)}

      _ ->
        nil
    end
  end
end

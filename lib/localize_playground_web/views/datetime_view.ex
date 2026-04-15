defmodule LocalizePlaygroundWeb.DateTimeView do
  @moduledoc """
  Pure helpers for the Dates & Times, Intervals, and Durations tabs.
  Wraps Localize.Date / Time / DateTime / Interval / Duration and
  provides skeleton resolution, pattern tokenization, and calendar
  introspection for the UI.
  """

  alias Localize.DateTime.Format
  alias Localize.DateTime.Format.{Match, Compiler}

  @standard_styles [:short, :medium, :long, :full]
  @duration_styles [:long, :short, :narrow]

  @interval_formats [:short, :medium, :long]
  @interval_styles [:date, :month, :month_and_day, :year_and_month]

  @doc "Four standard style atoms — ordered from compact to verbose."
  def standard_styles, do: @standard_styles

  @doc "Duration-style atoms."
  def duration_styles, do: @duration_styles

  @doc "Interval format atoms (controls tightness)."
  def interval_formats, do: @interval_formats

  @doc "Interval style atoms (controls which components render)."
  def interval_styles, do: @interval_styles

  @doc "CLDR calendar atoms Localize will happily format through."
  def calendar_options do
    [
      {:gregorian, "Gregorian"},
      {:buddhist, "Buddhist"},
      {:chinese, "Chinese"},
      {:coptic, "Coptic"},
      {:dangi, "Dangi"},
      {:ethiopic, "Ethiopic"},
      {:ethiopic_amete_alem, "Ethiopic Amete Alem"},
      {:hebrew, "Hebrew"},
      {:indian, "Indian National"},
      {:islamic, "Hijri"},
      {:islamic_civil, "Hijri (civil)"},
      {:islamic_tbla, "Hijri (tabular, astronomical)"},
      {:islamic_umalqura, "Hijri (Umm al-Qura)"},
      {:japanese, "Japanese"},
      {:persian, "Persian"},
      {:roc, "Minguo (ROC)"}
    ]
  end

  @doc """
  Returns the Elixir calendar module to convert a date into before
  formatting, when the user has selected a non-Gregorian CLDR calendar.
  Returns `nil` when no conversion is needed.
  """
  @spec calendar_module(atom()) :: module() | nil
  def calendar_module(:gregorian), do: nil
  def calendar_module(:coptic), do: Calendrical.Coptic
  def calendar_module(:ethiopic), do: Calendrical.Ethiopic
  def calendar_module(:ethiopic_amete_alem), do: Calendrical.Ethiopic.AmeteAlem
  def calendar_module(:japanese), do: Calendrical.Japanese
  def calendar_module(:roc), do: Calendrical.Roc
  def calendar_module(_), do: nil

  @doc """
  Returns the list of available CLDR skeleton atoms for a locale and
  calendar type. Used to populate a `<datalist>` autocomplete.
  """
  @spec available_skeletons(atom() | String.t(), atom()) :: [atom()]
  def available_skeletons(locale, calendar_type \\ :gregorian) do
    try do
      with {:ok, _tag} <- Localize.validate_locale(locale),
           {:ok, formats} <- Format.available_formats(locale, calendar_type) do
        formats |> Map.keys() |> Enum.sort_by(&Atom.to_string/1)
      else
        _ -> []
      end
    rescue
      _ -> []
    end
  end

  @doc """
  Given a skeleton atom and a locale, returns `%{requested:,
  resolved:, pattern:}`. The `resolved` skeleton may differ from the
  requested one when CLDR's best-match algorithm picks a close
  alternative. `pattern` is the CLDR pattern string the resolved
  skeleton produces.
  """
  @spec resolve_skeleton(atom(), atom() | String.t(), atom()) :: map()
  def resolve_skeleton(skeleton, locale, calendar_type \\ :gregorian)
      when is_atom(skeleton) do
    try do
      with {:ok, _tag} <- Localize.validate_locale(locale),
           {:ok, resolved} <- Match.best_match(skeleton, locale, calendar_type),
           {:ok, formats} <- Format.available_formats(locale, calendar_type) do
        case resolved do
          {date_skel, time_skel} ->
            %{
              requested: skeleton,
              resolved: resolved,
              pattern: {Map.get(formats, date_skel), Map.get(formats, time_skel)}
            }

          atom when is_atom(atom) ->
            %{requested: skeleton, resolved: resolved, pattern: Map.get(formats, resolved)}
        end
      else
        {:error, exception} when is_exception(exception) -> %{error: Exception.message(exception)}
        {:error, message} when is_binary(message) -> %{error: message}
        _ -> %{error: "No match for #{inspect(skeleton)} in #{inspect(locale)}."}
      end
    rescue
      exception -> %{error: Exception.message(exception)}
    end
  end

  @doc """
  Tokenises a CLDR date/time pattern into a list of
  `{type, count_or_literal}` pairs for display.
  """
  @spec tokenize_pattern(String.t()) :: {:ok, [tuple()]} | {:error, String.t()}
  def tokenize_pattern(pattern) when is_binary(pattern) do
    case Compiler.tokenize(pattern) do
      {:ok, tokens, _end_line} ->
        simplified =
          Enum.map(tokens, fn
            {type, _line, count_or_literal} -> {type, count_or_literal}
          end)

        {:ok, simplified}

      {:error, {_line, _module, message}} ->
        {:error, IO.iodata_to_binary(message)}

      {:error, message} when is_binary(message) ->
        {:error, message}
    end
  end

  @doc """
  Runs Localize.Date.to_string with the given options, returning
  `{:ok, string}` or `{:error, message}`. Accepts a converted calendar
  by passing the Elixir calendar module via `:convert_to`.
  """
  def format_date(%Date{} = date, options) do
    safe(fn ->
      date = maybe_convert_date(date, options[:convert_to])
      clean = Keyword.delete(options, :convert_to)
      Localize.Date.to_string(date, clean)
    end)
  end

  def format_time(%Time{} = time, options) do
    safe(fn -> Localize.Time.to_string(time, options) end)
  end

  def format_datetime(%NaiveDateTime{} = datetime, options) do
    safe(fn ->
      datetime = maybe_convert_datetime(datetime, options[:convert_to])
      clean = Keyword.delete(options, :convert_to)
      Localize.DateTime.to_string(datetime, clean)
    end)
  end

  def format_datetime(%DateTime{} = datetime, options) do
    safe(fn ->
      clean = Keyword.delete(options, :convert_to)
      Localize.DateTime.to_string(datetime, clean)
    end)
  end

  def format_interval(from, to, options) do
    safe(fn -> Localize.Interval.to_string(from, to, options) end)
  end

  def format_duration(%Localize.Duration{} = duration, options) do
    safe(fn -> Localize.Duration.to_string(duration, options) end)
  end

  def format_duration_time(%Localize.Duration{} = duration, pattern) when is_binary(pattern) do
    safe(fn -> Localize.Duration.to_time_string(duration, format: pattern) end)
  end

  # Localize sometimes raises (rather than returning {:error, _}) when
  # the locale data isn't loaded or the format combination is unsupported.
  # Catch those so the LiveView can show a clean error card.
  defp safe(fun) do
    fun.() |> normalize_result()
  rescue
    exception -> {:error, Exception.message(exception)}
  end

  @doc "Construct a Localize.Duration from two date-likes."
  def duration_between(from, to), do: Localize.Duration.new(from, to)

  defp maybe_convert_date(date, nil), do: date

  defp maybe_convert_date(date, target) do
    case Date.convert(date, target) do
      {:ok, converted} -> converted
      _ -> date
    end
  end

  defp maybe_convert_datetime(datetime, nil), do: datetime

  defp maybe_convert_datetime(datetime, target) do
    case NaiveDateTime.convert(datetime, target) do
      {:ok, converted} -> converted
      _ -> datetime
    end
  end

  defp normalize_result({:ok, string}), do: {:ok, string}

  defp normalize_result({:error, exception}) when is_exception(exception),
    do: {:error, Exception.message(exception)}

  defp normalize_result({:error, {_mod, message}}), do: {:error, message}
  defp normalize_result({:error, message}) when is_binary(message), do: {:error, message}
  defp normalize_result(other), do: {:error, inspect(other)}
end

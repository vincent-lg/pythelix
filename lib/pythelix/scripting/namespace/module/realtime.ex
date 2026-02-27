defmodule Pythelix.Scripting.Namespace.Module.Realtime do
  @moduledoc """
  Module defining the realtime module for Pythello scripting.

  Provides access to real-world time.
  """

  use Pythelix.Scripting.Module, name: "realtime"

  alias Pythelix.Game.Epoch
  alias Pythelix.Scripting.Object.{GameTime, RealDateTime}

  defattr clock(_script, _self) do
    System.system_time(:second)
  end

  defmet now(script, _namespace), [] do
    dt = DateTime.utc_now() |> RealDateTime.to_local()
    {script, %RealDateTime{datetime: dt}}
  end

  defmet from_gametime(script, namespace), [
    {:gt, index: 0}
  ] do
    gt = Store.get_value(namespace.gt)

    case gt do
      %GameTime{epoch: game_epoch} ->
        scale = Epoch.get_scale()
        started_at = Epoch.get_started_at()

        if started_at == nil do
          message = "game epoch is not configured"
          {Script.raise(script, RuntimeError, message), :none}
        else
          real_unix = started_at + game_epoch / scale
          dt = DateTime.from_unix!(trunc(real_unix)) |> RealDateTime.to_local()
          {script, %RealDateTime{datetime: dt}}
        end

      _ ->
        message = "from_gametime expects a GameTime"
        {Script.raise(script, TypeError, message), :none}
    end
  end
end

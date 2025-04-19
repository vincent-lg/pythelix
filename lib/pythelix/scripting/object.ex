defmodule Pythelix.Scripting.Object do
  @moduledoc """
  Defines a Pythelix object, to be manipulated in-game.

  Defines an object in Pythelix.

  An object is a "piece of the game universe", although some might refer
  to external data. An objec contains both attributes and methods:
  these can be defined either in the code or in game through administrator
  commands. The game would be able to handle both.

  For instance, lists are defined in the Elixir code, but they're used
  in the game world to store data. Characters are defined in the Elixir code,
  but the game code can send messages to the connected client.
  Administrators can add attributes and methods to the character
  as well. They should both be used and called in the same way.
  """
end

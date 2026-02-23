defmodule Pumpkin.Parser do
  @moduledoc "Loads and parses all your `.feature` files."

  alias Gherkin

  @feature_glob "features/**/*.feature"

  def load_all do
    Path.wildcard(@feature_glob)
    |> Enum.map(&Gherkin.parse_file/1)
  end
end

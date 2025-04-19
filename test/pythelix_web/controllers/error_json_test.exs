defmodule PythelixWeb.ErrorJSONTest do
  use PythelixWeb.ConnCase, async: true

  test "renders 404" do
    assert PythelixWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert PythelixWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end

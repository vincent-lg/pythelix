defmodule Pythelix.Scripting.Module do
  defmacro __using__(opts) do
    quote do
      use Pythelix.Scripting.Namespace

      Module.register_attribute __MODULE__, :pythello_module, persist: true
      Module.register_attribute __MODULE__, :pythello_module_name, persist: true

      @pythello_module_name unquote(Keyword.fetch!(opts, :name))

      @before_compile Pythelix.Scripting.Module
    end
  end

  defmacro __before_compile__(env) do
    mod = env.module
    Module.put_attribute(mod, :pythello_module, true)
  end
end

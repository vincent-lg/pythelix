defmodule Pythelix.Scripting.Interpreter.VM do
  @moduledoc """
  Module to play the role of a small virtual machine to execute bytecodes.

  This module handles bytecodes with a dispatch tables, contrary to relying on pattern matching as it did previously.
  """

  alias Pythelix.Scripting.Interpreter.VM

  @dispatch %{
    put: {VM.Op, :put},
    +: {VM.Math, :add},
    -: {VM.Math, :sub},
    *: {VM.Math, :mul},
    /: {VM.Math, :div},
    <: {VM.Cmp, :lt},
    >: {VM.Cmp, :gt},
    <=: {VM.Cmp, :le},
    >=: {VM.Cmp, :ge},
    ==: {VM.Cmp, :eq},
    !=: {VM.Cmp, :ne},
    put_dict: {VM.Dict, :put},
    dict: {VM.Dict, :new},
    list: {VM.List, :new},
    iffalse: {VM.Jump, :iffalse},
    iftrue: {VM.Jump, :iftrue},
    popiffalse: {VM.Jump, :popiffalse},
    popiftrue: {VM.Jump, :popiftrue},
    goto: {VM.Jump, :goto},
    not: {VM.Op, :op_not},
    read: {VM.Op, :read},
    getattr: {VM.Op, :getattr},
    setattr: {VM.Op, :setattr},
    builtin: {VM.Op, :builtin},
    store: {VM.Op, :store},
    mkiter: {VM.Op, :mkiter},
    iter: {VM.Op, :iter},
    call: {VM.Op, :call},
    wait: {VM.Op, :wait},
    return: {VM.Op, :return},
    raw: {VM.Op, :raw},
    pop: {VM.Op, :pop},
    getitem: {VM.Item, :get},
    line: {VM.Op, :line}
  }

  def handle(script, {:noop, nil}), do: script
  def handle(script, {op_type, op_args}) do
    {module, dispatch} = @dispatch[op_type]

    apply(module, dispatch, [script, op_args])
  end
end

defmodule Pythelix.Scripting.Object.InputState do
  @moduledoc """
  Represents the state of a script waiting for user input.

  Used by the `ask` and `choice` builtins to capture user input
  without blocking other players.
  """

  defstruct [
    :client_id,
    :client_pid,
    :entity_id_or_key,
    :prompt,
    :timeout,
    :choices,
    :error_msg,
    task_id: nil
  ]

  @typedoc """
  Input state for a script waiting for user input.

  Fields:

  * `client_id` - the client ID to capture input from.
  * `client_pid` - the PID of the client's TCP process (for sending messages).
  * `entity_id_or_key` - the id or key of the controlled entity being asked
    (nil when asking a client entity directly, e.g. at login time).
  * `prompt` - optional prompt message to send to the client.
  * `timeout` - optional timeout in seconds; if nil, wait indefinitely.
  * `choices` - nil for `ask`, list of valid strings for `choice`.
  * `error_msg` - error message to send on invalid choice (only for `choice`).
  * `task_id` - the persistent task ID (set by the runner after saving).
  """
  @type t() :: %__MODULE__{
          client_id: integer(),
          client_pid: pid() | nil,
          entity_id_or_key: nil | integer() | String.t(),
          prompt: nil | String.t(),
          timeout: nil | number(),
          choices: nil | [String.t()],
          error_msg: nil | String.t(),
          task_id: nil | integer()
        }
end

defmodule Teiserver.Protocols.Tachyon.V1.Tachyon do
  @moduledoc """
  Used for library-like functions that are specific to a version.
  """

  alias Teiserver.{Client, User}
  alias Phoenix.PubSub
  alias Teiserver.Data.Types, as: T

  @spec protocol_in :: Teiserver.Protocols.Tachyon.V1.TachyonIn
  def protocol_in(), do: Teiserver.Protocols.Tachyon.V1.TachyonIn

  @spec protocol_out :: Teiserver.Protocols.Tachyon.V1.TachyonOut
  def protocol_out(), do: Teiserver.Protocols.Tachyon.V1.TachyonOut

  @doc """
  Used to convert objects into something that will be sent back over the wire. We use this
  as there might be internal fields we don't want sent out (e.g. email).
  """
  @spec convert_object(:user | :user_extended | :user_extended_icons | :client | :battle | :queue | :blog_post, Map.t() | nil) :: Map.t() | nil
  def convert_object(_, nil), do: nil
  def convert_object(:user, user), do: Map.take(user, ~w(id name bot clan_id springid country)a)
  def convert_object(:user_extended, user), do: Map.take(user, ~w(id name bot clan_id permissions
                    friends friend_requests ignores springid country)a)
  def convert_object(:user_extended_icons, user),
  do:
    Map.merge(convert_object(:user_extended, user),
    %{"icons" => Teiserver.Account.UserLib.generate_user_icons(user)}
  )
  def convert_object(:client, client), do: Map.take(client, ~w(userid in_game away ready player_number team_number
                    team_colour player bonus synced faction lobby_id)a)
  def convert_object(:queue, queue), do: Map.take(queue, ~w(id name team_size conditions settings map_list)a)
  def convert_object(:blog_post, post), do: Map.take(post, ~w(id short_content content url tags live_from)a)

  # Slightly more complex conversions
  def convert_object(:lobby, lobby) do
    lobby = %{lobby |
      password: lobby.password != nil
    }

    Map.take(lobby, [:id, :name, :founder_id, :type, :max_players, :game_name,
                    :locked, :engine_name, :engine_version, :players, :spectators, :bots, :ip, :settings, :map_name, :password,
                    :map_hash, :tags, :disabled_units, :in_progress, :started_at, :start_rectangles])
  end

  @spec do_action(atom, any(), T.tachyon_tcp_state()) :: T.tachyon_tcp_state()
  def do_action(:login_accepted, user, state) do
    # Login the client
    client = Client.login(user, state.ip)

    PubSub.unsubscribe(Central.PubSub, "teiserver_client_messages:#{user.id}")
    PubSub.unsubscribe(Central.PubSub, "teiserver_user_updates:#{user.id}")

    PubSub.subscribe(Central.PubSub, "teiserver_client_messages:#{user.id}")
    PubSub.subscribe(Central.PubSub, "teiserver_user_updates:#{user.id}")

    exempt_from_cmd_throttle = (User.is_moderator?(user) == true or User.is_bot?(user) == true)
    %{state |
      client: client,
      username: user.name,
      userid: user.id,
      exempt_from_cmd_throttle: exempt_from_cmd_throttle
    }
  end

  def do_action(:host_lobby, lobby_id, state) do
    PubSub.unsubscribe(Central.PubSub, "teiserver_lobby_host_message:#{lobby_id}")
    PubSub.unsubscribe(Central.PubSub, "teiserver_lobby_updates:#{lobby_id}")
    PubSub.unsubscribe(Central.PubSub, "teiserver_lobby_chat:#{lobby_id}")

    PubSub.subscribe(Central.PubSub, "teiserver_lobby_host_message:#{lobby_id}")
    PubSub.subscribe(Central.PubSub, "teiserver_lobby_updates:#{lobby_id}")
    PubSub.subscribe(Central.PubSub, "teiserver_lobby_chat:#{lobby_id}")
    %{state |
      lobby_id: lobby_id,
      lobby_host: true
    }
  end

  def do_action(:leave_lobby, lobby_id, state) do
    PubSub.unsubscribe(Central.PubSub, "teiserver_lobby_updates:#{lobby_id}")
    PubSub.unsubscribe(Central.PubSub, "teiserver_lobby_chat:#{lobby_id}")
    %{state | lobby_id: nil}
  end

  def do_action(:join_lobby, lobby_id, state) do
    Teiserver.Battle.Lobby.add_user_to_battle(state.userid, lobby_id, state.script_password)

    PubSub.unsubscribe(Central.PubSub, "teiserver_lobby_updates:#{lobby_id}")
    PubSub.unsubscribe(Central.PubSub, "teiserver_lobby_chat:#{lobby_id}")

    PubSub.subscribe(Central.PubSub, "teiserver_lobby_updates:#{lobby_id}")
    PubSub.subscribe(Central.PubSub, "teiserver_lobby_chat:#{lobby_id}")

    %{state | lobby_id: lobby_id}
  end

  def do_action(:watch_lobby, lobby_id, state) do
    Teiserver.Battle.Lobby.add_user_to_battle(state.userid, lobby_id, state.script_password)

    PubSub.unsubscribe(Central.PubSub, "teiserver_lobby_updates:#{lobby_id}")

    PubSub.subscribe(Central.PubSub, "teiserver_lobby_updates:#{lobby_id}")

    %{state | lobby_id: lobby_id}
  end
end

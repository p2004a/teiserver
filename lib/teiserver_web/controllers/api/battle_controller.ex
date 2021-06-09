defmodule TeiserverWeb.API.BattleController do
  use CentralWeb, :controller
  alias Teiserver.Battle

  plug(Bodyguard.Plug.Authorize,
    policy: Teiserver.Battle.ApiAuth,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}
  )

  def create(conn, battle = %{"outcome" => "completed"}) do
    {:ok, dbbattle} = Battle.create_battle_log(%{
      map: "map",
      data: battle,
      team_count: 1,
      players: [],
      spectators: [],
      started: Timex.now(),
      finished: Timex.now() |> Timex.shift(minutes: 20)
    })

    conn
    |> put_status(201)
    |> render("create.json", %{outcome: :success, id: dbbattle.id})
  end

  def create(conn, _battle) do
    conn
    |> put_status(400)
    |> render("create.json", %{outcome: :ignored, reason: "Not a completed battle"})
  end
end

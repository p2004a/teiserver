defmodule Teiserver.Account.SmurfKey do
  use CentralWeb, :schema

  schema "teiserver_account_smurf_keys" do
    belongs_to :user, Central.Account.User
    field :value, :string
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(Map.t(), Map.t()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    params = params
      |> trim_strings(~w(value)a)

    struct
      |> cast(params, ~w(value user_id)a)
      |> validate_required(~w(value user_id)a)
  end

  @spec authorize(Atom.t(), Plug.Conn.t(), Map.t()) :: Boolean.t()
  def authorize(_, conn, _), do: allow?(conn, "teiserver.moderator.account")
end

defmodule MyAppWeb.JsonApi.UserSessionController do
  use MyAppWeb, :controller

  alias MyApp.Accounts
  alias MyApp.Accounts.User
  # alias MyAppWeb.UserAuth
  alias MyApp.Guardian


  def create(conn, %{"email" => nil}) do
    conn
    |> put_status(401)
    |> render("error.json", message: "User could not be authenticated")
  end

  def create(conn, %{"email" => email, "password" => password}) do
    case Accounts.get_user_by_email_and_password(email, password) do
      %User{} = user ->
        {:ok, jwt, _full_claims} = Guardian.encode_and_sign(user, %{})

        conn
        |> render("create.json", user: user, jwt: jwt)
      nil ->
        conn
        |> put_status(401)
        |> render("error.json", message: "User could not be authenticated")
    end
  end
end
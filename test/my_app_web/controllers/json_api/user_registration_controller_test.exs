defmodule MyAppWeb.JsonApi.UserRegistrationControllerTest do
  use MyAppWeb.ConnCase, async: true

  import MyApp.AccountsFixtures

  describe "POST /users/register" do
    @tag :capture_log
    test "creates account and returns a JWT", %{conn: conn} do
      email = unique_user_email()

      conn =
        post(conn, Routes.json_api_user_registration_path(conn, :create), %{
          "user" => valid_user_attributes(email: email)
        })

        assert %{
          "data" => %{"token" => "" <> _},
          "message" => "You are successfully registered" <> _
        } = json_response(conn, 201)
    end

    test "returns errors for invalid data", %{conn: conn} do
      conn =
        post(conn, Routes.json_api_user_registration_path(conn, :create), %{
          "user" => %{"email" => "with spaces", "password" => "too short"}
        })

      assert %{"message" => %{"email" => ["must have the @ sign and no spaces"], "password" => ["should be at least 12 character(s)"]}} = json_response(conn, 401)
    end
  end
end

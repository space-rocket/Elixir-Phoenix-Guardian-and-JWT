defmodule MyAppWeb.JsonApi.UserResetPasswordControllerTest do
  use MyAppWeb.ConnCase, async: true

  alias MyApp.Accounts
  alias MyApp.Repo
  import MyApp.AccountsFixtures

  setup do
    %{user: user_fixture()}
  end

  describe "POST /users/reset_password" do
    @tag :capture_log
    test "sends a new reset password token", %{conn: conn, user: user} do
      conn =
        post(conn, Routes.json_api_user_reset_password_path(conn, :create), %{
          "user" => %{"email" => user.email}
        })

      assert %{
        "data" => %{},
        "message" => "If your email is in our system" <> _
      } = json_response(conn, 200)
      assert Repo.get_by!(Accounts.UserToken, user_id: user.id).context == "reset_password"
    end

    test "does not send reset password token if email is invalid", %{conn: conn} do
      conn =
        post(conn, Routes.json_api_user_reset_password_path(conn, :create), %{
          "user" => %{"email" => "unknown@example.com"}
        })

      assert %{
        "data" => %{},
        "message" => "If your email is in our system" <> _
      } = json_response(conn, 200)
      assert Repo.all(Accounts.UserToken) == []
    end
  end

  describe "PUT /users/reset_password/:token" do
    setup %{user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_reset_password_instructions(user, url)
        end)

      %{token: token}
    end

    test "resets password once", %{conn: conn, user: user, token: token} do
      conn =
        put(conn, Routes.json_api_user_reset_password_path(conn, :update, token), %{
          "user" => %{
            "password" => "new valid password",
            "password_confirmation" => "new valid password"
          }
        })

      assert %{
        "data" => %{},
        "message" => "Password reset successfully" <> _
      } = json_response(conn, :ok)
      assert Accounts.get_user_by_email_and_password(user.email, "new valid password")
    end

    test "does not reset password on invalid data", %{conn: conn, token: token} do
      conn =
        put(conn, Routes.json_api_user_reset_password_path(conn, :update, token), %{
          "user" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })

        assert %{"message" =>
          %{
            "password" => ["should be at least 12 character(s)"],
            "password_confirmation" => ["does not match password"]
          }
        } = json_response(conn, 200)
    end

    test "does not reset password with invalid token", %{conn: conn} do
      conn = put(conn, Routes.json_api_user_reset_password_path(conn, :update, "oops"))
      assert %{
        "data" => %{},
        "message" => "Reset password link is invalid or it has expired" <> _
      } = json_response(conn, 200)
    end
  end
end
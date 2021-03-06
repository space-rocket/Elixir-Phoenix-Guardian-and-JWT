## Elixir Phoenix Guardian JWT and mix phx.gen.auth

Goal:
 Use Phoenix framework's authentication generator as a base for using Guardian to generate a JWT for a frontend agnostic web application that is hosted on another domain.

I assume basic familarity with Elixir, Phoenix, mix phx.gen.auth, Guardian and JWT and skip right to implemenatation. 

Steps:
- Create a new app
- Use mix phx.gen.auth to generate authentication system
- Configure Guardian
- Update router
- Create test, controllers and views for user registration, session management and resetting password
- Add authenticated route


## Create a new app

```
mix phx.new my_app
```

```
cd my_app
```

```
mix ecto.create
```

Use mix phx.gen.auth to generate user authentication system, while we are in the mix.exs file, lets also add Guardian as well.

Add the `phx_gen_auth` dependency
```elixir
def deps do
  [
    {:phx_gen_auth, "~> 0.7", only: [:dev], runtime: false},
    {:guardian, "~> 2.0"}
    ...
  ]
end
```

Install the dependencies and compile
```bash
mix do deps.get, deps.compile
```

Run the generator
```bash
mix phx.gen.auth Accounts User users
```

Re fetch the dependencies
```bash
mix deps.get
```

Update the repo
```bash
mix ecto.migrate
```

## Configure Guardian

```bash
mix phx.gen.secret
# jmLFS2lrpiLffUt+2BXpQuaiv8DQuFvonME/QT49q7tAW2zIIYiJgGlN5RWLxiCt
```

```elixir
# config/config.exs
...

config :my_app, MyApp.Guardian,
  issuer: "my_app",
  secret_key: "jmLFS2lrpiLffUt+2BXpQuaiv8DQuFvonME/QT49q7tAW2zIIYiJgGlN5RWLxiCt",
  ttl: {3, :days}


...
```

Create `guardian.ex` file inside `lib/my_app/`.

```elixir
# lib/my_app/guardian.ex
defmodule MyApp.Guardian do
  use Guardian, otp_app: :my_app

  alias MyApp.Accounts

  def subject_for_token(resource, _claims) do
    # You can use any value for the subject of your token but
    # it should be useful in retrieving the resource later, see
    # how it being used on `resource_from_claims/1` function.
    # A unique `id` is a good subject, a non-unique email address
    # is a poor subject.
    sub = to_string(resource.id)
    {:ok, sub}
  end

  def resource_from_claims(claims) do
    # Here we'll look up our resource from the claims, the subject can be
    # found in the `"sub"` key. In `above subject_for_token/2` we returned
    # the resource id so here we'll rely on that to look it up.
    id = claims["sub"]
    resource = Accounts.get_user!(id)
    {:ok,  resource}
  end
end
```


## Add JSON API User Routes


```elixir
# lib/my_app_web/router.ex
defmodule MyAppWeb.Router do
  ...
  pipeline :require_jwt do
    plug Guardian.Plug.EnsureAuthenticated
  end
  ...

  # JSON Authentication routes
  scope "/api/v1", MyAppWeb.JsonApi, as: :json_api do
    pipe_through :api

    post "/users/register", UserRegistrationController, :create
    post "/users/log_in", UserSessionController, :create

    post "/users/reset_password", UserResetPasswordController, :create
    get "/users/reset_password/:token", UserResetPasswordController, :edit
    put "/users/reset_password/:token", UserResetPasswordController, :update
  end

  # JWT Protected routes
  scope "/api/v1", MyAppWeb.JsonApi, as: :json_api do
    pipe_through [:api, :require_jwt]

    # Add protected routes here...
  end
  ...
end
```


## Registration

Now we need create some controller, views and tests. Lets start with tests. Create a `json_api` folder inside `test/my_app_web/controllers/`.

**User Registration Controller Test**

Create file named `test/my_app_web/controllers/user_registration_controller_test.exs`, with this as its contents:

```elixir
# test/my_app_web/controllers/json_api/user_registration_controller_test.exs
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
```

**User Registration Controller**

We run our tests, and it obvisouly fails, we haven't created any controllers or views for JsonApi namespace. Lets fix that by adding our controller and view.
```elixir
# lib/my_app_web/controllers/json_api/user_registration_controller.ex
defmodule MyAppWeb.JsonApi.UserRegistrationController do
  use MyAppWeb, :controller

  alias MyApp.Accounts
  alias MyApp.Accounts.User
  alias MyApp.Guardian

  def new(conn, _params) do
    changeset = Accounts.change_user_registration(%User{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"user" => user_params}) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->

        {:ok, _} =
          Accounts.deliver_user_confirmation_instructions(
            user,
            &Routes.user_confirmation_url(conn, :confirm, &1)
          )
          {:ok, jwt, _full_claims} = Guardian.encode_and_sign(user, %{})

        conn
        |> put_status(:created)
        |> render("create.json", user: user, jwt: jwt)

      {:error, %Ecto.Changeset{} = changeset} ->

        conn
        |> put_status(401)
        |> render("error.json", message: changeset)
    end
  end
end
```

**User Registration View**

```elixir
# lib/my_app_web/views/json_api/user_registration_view.ex
defmodule MyAppWeb.JsonApi.UserRegistrationView do
  use MyAppWeb, :view

  def translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, &translate_error/1)
  end

  def render("create.json", %{user: user, jwt: jwt}) do
    %{
      status: :ok,
      data: %{
        token: jwt,
        email: user.email
        },
        message: "You are successfully registered! Add this token to authorization header to make authorized requests."
      }
    end

    def render("error.json", %{message: message}) do
      %{
        status: :not_found,
        data: %{},
        message: translate_errors(message)
      }
    end
end
```

## Login

**User Session Controller Test**
```elixir
# test/my_app_web/controllers/json_api/user_session_controller_test.exs
defmodule MyAppWeb.JsonApi.UserSessionControllerTest do
  use MyAppWeb.ConnCase, async: true

  import MyApp.AccountsFixtures

  setup do
    %{user: user_fixture()}
  end

  describe "POST /api/session" do
    test "with no credentials user can't login", %{conn: conn} do
      conn = post(conn, Routes.json_api_user_session_path(conn, :create), email: nil, password: nil)
      assert %{"message" => "User could not be authenticated"} = json_response(conn, 401)
    end

    test "with invalid password user cant login", %{conn: conn, user: user} do
      conn =
        post(conn, Routes.json_api_user_session_path(conn, :create),
          email: user.email,
          password: "wrongpass"
        )

      assert %{"message" => "User could not be authenticated"} = json_response(conn, 401)
    end

    test "with valid password user can login", %{conn: conn, user: user} do
      conn =
        post(conn, Routes.json_api_user_session_path(conn, :create),
          email: user.email,
          password: valid_user_password()
        )

      assert %{
        "data" => %{"token" => "" <> _},
        "message" => "You are successfully logged in" <> _
      } = json_response(conn, 200)
    end
  end
end
```

**User Session Controller**
```elixir
# lib/my_app_web/controllers/json_api/user_session_controller.ex
defmodule MyAppWeb.JsonApi.UserSessionController do
  use MyAppWeb, :controller

  alias MyApp.Accounts
  alias MyApp.Accounts.User
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
```

**User Session View**
```elixir
# lib/my_app_web/views/json_api/user_session_view.ex
defmodule MyAppWeb.JsonApi.UserSessionView do
  use MyAppWeb, :view

  def render("create.json", %{user: user, jwt: jwt}) do
    %{
    status: :ok,
    data: %{
      token: jwt,
      email: user.email
      },
      message: "You are successfully logged in! Add this token to authorization header to make authorized requests."
    }
  end

  def render("error.json", %{message: message}) do
    %{
      status: :not_found,
      data: %{},
      message: message
    }
  end
end
```

## Reset Password

**User Reset Password Controller Test**
```elixir
# test/my_app_web/controllers/json_api/user_reset_password_controller_test.exs
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
```

**User Reset Password Controller**
```elixir
# lib/my_app_web/controllers/json_api/user_reset_password_controller.ex
defmodule MyAppWeb.JsonApi.UserResetPasswordController do
  use MyAppWeb, :controller

  alias MyApp.Accounts

  plug :get_user_by_reset_password_token when action in [:edit, :update]

  def new(conn, _params) do
    render(conn, "new.html")
  end

  def create(conn, %{"user" => %{"email" => email}}) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_user_reset_password_instructions(
        user,
        &Routes.user_reset_password_url(conn, :edit, &1)
      )
    end

    conn
    |> render("create.json",
      message: "If your email is in our system, you will receive instructions to reset your password shortly.")
  end

  def edit(conn, _params) do
    render(conn, "edit.html", changeset: Accounts.change_user_password(conn.assigns.user))
  end

  # Do not log in the user after reset password to avoid a
  # leaked token giving the user access to the account.
  def update(conn, %{"user" => user_params}) do
    case Accounts.reset_user_password(conn.assigns.user, user_params) do
      {:ok, _} ->
        conn
        |> render("create.json", message: "Password reset successfully.")

      {:error, changeset} ->
        render(conn, "error.json", changeset: changeset)
    end
  end

  defp get_user_by_reset_password_token(conn, _opts) do
    %{"token" => token} = conn.params

    if user = Accounts.get_user_by_reset_password_token(token) do
      conn |> assign(:user, user) |> assign(:token, token)
    else
      conn
      |> render("create.json", message: "Reset password link is invalid or it has expired.")
      |> halt()
    end
  end
end
```

**User Reset Password View**
```elixir
# lib/my_app_web/views/json_api/user_reset_password_view.ex
defmodule MyAppWeb.JsonApi.UserResetPasswordView do
  use MyAppWeb, :view

  def translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, &translate_error/1)
  end

  def render("create.json", %{message: message}) do
    %{
      status: :ok,
      data: %{},
      message: message
    }
  end

  def render("update.json", %{message: message}) do
    %{
      status: :ok,
      data: %{},
      message: message
    }
  end

  def render("error.json", %{changeset: changeset}) do
    %{
      status: :not_found,
      data: %{},
      message: translate_errors(changeset)
    }
  end
end
```

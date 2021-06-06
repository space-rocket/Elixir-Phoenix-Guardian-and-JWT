## Elixir Phoenix Guardian JWT and mix phx.gen.auth

Goal:
Use mix `mix phx.gen.auth` as a base for using Guardian to generate a JWT for an agnositce  cross orign web application to that communicates with an authenticated backend.

I assume basic familarity with Elixir, Phoenix, mix phx.gen.auth, Guardian and JWT and skip right to implemenatation. 


Steps:
- Create a new app
- Use mix phx.gen.auth to generate authentication system
- Install Guardian
- Create a JsonApi namespace in router.ex


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
```
def deps do
  [
    {:phx_gen_auth, "~> 0.7", only: [:dev], runtime: false},
    {:guardian, "~> 2.0"}
    ...
  ]
end
```

Install the dependencies and compile
```
mix do deps.get, deps.compile
```

Run the generator
```
mix phx.gen.auth Accounts User users
```

Re fetch the dependencies
```
mix deps.get
```

Update the repo
```
mix ecto.migrate
```

## Configure Guardian


```
# config/config.exs
...

config :my_app, MyApp.Guardian,
  issuer: "my_app",
  secret_key: "EI2tyig/pR4E5LD/PbEpU+aMGlbGR5g6JCktEqrVzU6dVO8YK/QkLGCWFM4lPWAE",
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

  # def subject_for_token(_, _) do
  #   {:error, :reason_for_error}
  # end

  def resource_from_claims(claims) do
    # Here we'll look up our resource from the claims, the subject can be
    # found in the `"sub"` key. In `above subject_for_token/2` we returned
    # the resource id so here we'll rely on that to look it up.
    id = claims["sub"]
    resource = Accounts.get_user!(id)
    {:ok,  resource}
  end
  # def resource_from_claims(_claims) do
  #   {:error, :reason_for_error}
  # end
end
```


## Update Router.ex


```elixir
defmodule MyAppWeb.Router do
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

  ...
end
```


## Add Controller Tests

Now we need create some controller, views and tests. Lets start with tests. Create a `json_api` folder inside `test/my_app_web/controllers/` and create file named `user_registration_controller_test.exs`. Here are first tests:

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

We run our tests, and it obvisouly fails, we haven't created any controllers or views for JsonApi namespace. Lets fix that by adding our controller and view.

```
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



```
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
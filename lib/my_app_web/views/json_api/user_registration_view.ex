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

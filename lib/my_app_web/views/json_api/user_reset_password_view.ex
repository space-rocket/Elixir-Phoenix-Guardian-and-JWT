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
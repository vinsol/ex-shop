defmodule ExShop.Router do
  use ExShop.Web, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :admin_browser_auth do
    plug Guardian.Plug.VerifySession, key: :admin
    plug Guardian.Plug.LoadResource, key: :admin
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ExShop do
    pipe_through :browser # Use the default browser stack

    get "/", PageController, :index
  end

  scope "/admin", ExShop.Admin, as: :admin do
    pipe_through [:browser, :admin_browser_auth]

    get "/", HomeController, :index
    resources "/countries", CountryController do
      resources "/states", StateController, only: [:create, :delete]
    end
    resources "/zones", ZoneController do
      resources "/members", ZoneMemberController, only: [:create, :delete]
    end

    resources "/sessions", SessionController, only: [:new, :create]
    delete "/logout", SessionController, :logout
  end

  # Other scopes may use custom stacks.
  # scope "/api", ExShop do
  #   pipe_through :api
  # end
end

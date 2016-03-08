defmodule ExShop.Admin.CartController do
  use ExShop.Web, :admin_controller

  plug Guardian.Plug.EnsureAuthenticated, handler: ExShop.Auth.HandleUnauthenticated, key: :admin

  alias ExShop.Order
  alias ExShop.Repo
  alias ExShop.LineItem
  alias ExShop.Product

  import Ecto.Query


  def new(conn, _params) do
    users = ExShop.Repo.all(ExShop.User)
    render(conn, "new.html", users: users)
  end

  def edit(conn, %{"id" => id}) do
    {:ok, order} = Repo.get!(ExShop.Order, id) |> ExShop.CheckoutManager.back("cart")
    products  =
      Product
      |> Repo.all
      |> Repo.preload([variants: [option_values: :option_type]])

    line_items =
      LineItem
      |> LineItem.in_order(order)
      |> Repo.all
      |> Repo.preload([variant: [:product, [option_values: :option_type]]])

    render(conn, "edit.html", order: order, products: products, line_items: line_items)
  end

end

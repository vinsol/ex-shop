defmodule ExShop.Admin.CheckoutController do
  use ExShop.Web, :admin_controller

  plug Guardian.Plug.EnsureAuthenticated, handler: ExShop.Auth.HandleAdminUnauthenticated, key: :admin
  plug :go_back_to_cart_if_empty when action in [:checkout, :next, :back]

  alias ExShop.CheckoutManager
  alias ExShop.Order

  def checkout(conn, _params) do
    order = Repo.get!(Order, conn.params["order_id"])
    changeset = CheckoutManager.next_changeset(order)
    render(conn, "checkout.html", order: order, changeset: changeset)
  end

  def next(conn, %{"order" => order_params}) do
    order = Repo.get!(Order, conn.params["order_id"])
    case CheckoutManager.next(order, order_params) do
      {:error, updated_changeset} ->
        render(conn, "checkout.html", order: order, changeset: updated_changeset)
      {:ok, updated_order} ->
        render(conn, "checkout.html", order: updated_order, changeset: CheckoutManager.next_changeset(updated_order))
    end
  end

  def back(conn, _params) do
    order = Repo.get!(Order, conn.params["order_id"])
    case CheckoutManager.back(order) do
      {:ok, updated_order} ->
        redirect(conn, to: admin_order_checkout_path(conn, :checkout, order))
    end
  end

  def go_back_to_cart_if_empty(conn, _params) do
    order = Repo.get!(Order, conn.params["order_id"])
    if ExShop.Order.cart_empty? order do
      conn
      |> put_flash(:error, "please add some products to cart before continuing")
      |> redirect(to: admin_cart_path(conn, :edit, order))
    else
      conn
    end
  end

end

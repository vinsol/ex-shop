defmodule ExShop.CheckoutController do
  use ExShop.Web, :controller
  alias ExShop.CheckoutManager
  alias ExShop.Order

  plug Guardian.Plug.EnsureAuthenticated, handler: __MODULE__
  plug :go_back_to_cart_if_empty when action in [:checkout, :next, :back]

  def checkout(conn, _params) do
    order = conn.assigns.current_order
    changeset = CheckoutManager.next_changeset(order)
    render(conn, "checkout.html", order: order, changeset: changeset)
  end

  def next(conn, %{"order" => order_params}) do
    order = conn.assigns.current_order
    case CheckoutManager.next(order, order_params) do
      {:error, updated_changeset} ->
        render(conn, "checkout.html", order: order, changeset: updated_changeset)
      {:ok, %ExShop.Order{state: "confirmation"} = updated_order} ->
        redirect(conn, to: order_path(conn, :show, updated_order))
      {:ok, updated_order} ->
        render(conn, "checkout.html", order: updated_order, changeset: CheckoutManager.next_changeset(updated_order))
    end
  end

  def back(conn, _params) do
    order = conn.assigns.current_order
    case CheckoutManager.back(order) do
      {:ok, updated_order} ->
        redirect(conn, to: checkout_path(conn, :checkout))
    end
  end

  def unauthenticated(conn, _params) do
    order = conn.assigns.current_order
    conn
    |> put_flash(:error, "Please login before continuing checkout")
    |> put_session(:next_page, cart_path(conn, :show))
    |> redirect(to: session_path(conn, :new))
  end

  def go_back_to_cart_if_empty(conn, _params) do
    order = conn.assigns.current_order |> Repo.preload([:line_items])
    case order.line_items do
      [] -> redirect(conn, to: cart_path(conn, :show))
      true -> conn
    end
  end

end

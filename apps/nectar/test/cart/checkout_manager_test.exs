defmodule Nectar.CheckoutManagerTest do
  use Nectar.ModelCase

  alias Nectar.Order
  alias Nectar.CheckoutManager
  alias Nectar.Country
  alias Nectar.State
  alias Nectar.Product
  alias Nectar.CartManager

  import Nectar.TestSetup.Country,        only: [create_country: 0]
  import Nectar.TestSetup.State,          only: [create_state: 1]
  import Nectar.TestSetup.PaymentMethod,  only: [create_payment_methods: 0]
  import Nectar.TestSetup.ShippingMethod, only: [create_shipping_methods: 0]
  import Nectar.TestSetup.Tax,            only: [create_taxes: 0]
  import Nectar.TestSetup.Order,          only: [create_cart: 0]
  import Nectar.TestSetup.Product,        only: [create_product: 0, create_products: 0]

  test "assert cart is not empty before each step" do
    cart = setup_cart_without_product
    {status, order} = CheckoutManager.next(cart, %{})
    assert status == :error
    assert order.errors[:line_items] == "Please add some item to your cart to proceed"
  end

  test "move to address state missing parameters" do
    {status, order} = CheckoutManager.next(setup_cart, %{})
    assert status == :error
    assert order.model.state == "cart"
    assert order.errors[:order_billing_address] == "can't be blank"
    assert order.errors[:order_shipping_address] == "can't be blank"
  end

  test "move to address state invalid parameters" do
    {status, order} = CheckoutManager.next(setup_cart, %{"order_shipping_address" =>  %{"address_line_1" => "asd", "country_id" => 1},
                                                         "order_billing_address" => %{}})
    assert status == :error
    assert order.model.state == "cart"
    assert order.errors == []
    assert order.changes[:order_shipping_address].errors[:address_line_1] == {"should be at least %{count} character(s)", [count: 10]}
    assert order.changes[:order_billing_address].errors[:country_id] == "can't be blank"
  end

  test "move to address state with valid parameters" do
    {status, order} = CheckoutManager.next(setup_cart, valid_address_params)
    assert status == :ok
    assert order.state == "address"
    assert order.order_shipping_address.id
    assert order.order_billing_address.id
  end

  test "move to address state with same_as_shipping copies creates two seperate addresses with same data" do
    {status, order} = CheckoutManager.next(setup_cart, valid_address_params_same_as_billing)
    assert status == :ok
    assert order.state == "address"
    assert order.order_shipping_address.address_id
    assert order.order_shipping_address.address_id
    assert order.order_shipping_address.address_id == order.order_billing_address.address_id
  end

  test "move to address state invalid parameters with same_as billing" do
    {status, order} = CheckoutManager.next(setup_cart, %{"order_shipping_address" =>  %{"address_line_1" => "asd", "country_id" => 1},
                                                         "order_billing_address" => %{}, "same_as_billing" => true})
    assert status == :error
    assert order.model.state == "cart"
    assert order.errors == []
    assert order.changes[:order_billing_address].errors[:country_id] == "can't be blank"
  end

  test "move to shipping_state creates a single shipment units" do
    cart = setup_cart
    {:ok, cart_in_addr_state} = move_cart_to_address_state(cart)
    cart_in_addr_state = cart_in_addr_state |> Repo.preload([:shipment_units])
    assert Enum.count(cart_in_addr_state.shipment_units) == 1
  end

  test "move to shipping_state creates a single shipment units for multiple line items by default" do
    cart = setup_cart_with_multiple_products
    {:ok, cart_in_addr_state} = move_cart_to_address_state(cart)
    cart_in_addr_state = cart_in_addr_state |> Repo.preload([:shipment_units])
    assert Enum.count(cart_in_addr_state.shipment_units) == 1
  end


  test "move to shipping_state creates shipment units with configured splitter" do
    Application.put_env(:nectar, :shipment_splitter, Nectar.Shipment.Splitter.SplitAll)
    cart = setup_cart
    {:ok, cart_in_addr_state} = move_cart_to_address_state(cart)
    cart_in_addr_state = cart_in_addr_state |> Repo.preload([:shipment_units])
    assert Enum.count(cart_in_addr_state.shipment_units) == 1
    Application.delete_env(:nectar, :shipment_splitter)
  end

  test "move to shipping_state may create multiple shipments with configured splitter" do
    Application.put_env(:nectar, :shipment_splitter, Nectar.Shipment.Splitter.SplitAll)
    cart = setup_cart_with_multiple_products
    {:ok, cart_in_addr_state} = move_cart_to_address_state(cart)
    cart_in_addr_state = cart_in_addr_state |> Repo.preload([:shipment_units])
    assert Enum.count(cart_in_addr_state.shipment_units) == 2
    Application.delete_env(:nectar, :shipment_splitter)
  end

  test "move to shipping state missing parameters" do
    cart = setup_cart
    {:ok, cart_in_addr_state} = move_cart_to_address_state(cart)
    {status, order} = CheckoutManager.next(cart_in_addr_state, %{})
    assert status == :error
    assert order.errors[:shipment_units] == "are required"
  end

  test "move to shipping state valid parameters" do
    {_, c_addr} = move_cart_to_address_state(setup_cart)
    {status, c_shipp} = move_cart_to_shipping_state(c_addr)

    assert status == :ok
    assert c_shipp.state == "shipping"
  end

  test "move to shipping state requires shipment details for all shipping units" do
    Application.put_env(:nectar, :shipment_splitter, Nectar.Shipment.Splitter.SplitAll)
    {_, c_addr} = move_cart_to_address_state(setup_cart_with_multiple_products)
    {status, c_shipp} = CheckoutManager.next(c_addr, valid_shipping_params_for_multiple_units(c_addr))

    assert status == :ok
    assert c_shipp.state == "shipping"

    Application.delete_env(:nectar, :shipment_splitter)
  end

  test "move to shipping state valid parameters adds tax adjustments" do
    {_, c_addr} = move_cart_to_address_state(setup_cart)
    {_status, c_shipp} = move_cart_to_shipping_state(c_addr)

    assert Enum.count(c_shipp.adjustments) == 2
  end

  test "move to tax state missing parameters" do
    {_, c_addr} = move_cart_to_address_state(setup_cart)
    {_, c_shipp} = move_cart_to_shipping_state(c_addr)
    {status, failed_change} = CheckoutManager.next(c_shipp, %{})
    assert status == :error
    assert failed_change.errors[:tax_confirm] == "Please confirm to proceed"
  end

  test "move to tax state valid parameters" do
    {_, c_addr} = move_cart_to_address_state(setup_cart)
    {_, c_shipp} = move_cart_to_shipping_state(c_addr)
    {status, c_tax} = move_cart_to_tax_state(c_shipp)
    assert status == :ok
    assert c_tax.state == "tax"
  end

  test "move to tax state valid parameters but no taxes present" do
    {_, c_addr} = move_cart_to_address_state(setup_cart)
    # delete taxes before moving to shipping since it calculates the taxes.
    Repo.delete_all(Nectar.Tax)
    {_, c_shipp} = move_cart_to_shipping_state(c_addr)
    {status, c_tax} = move_cart_to_tax_state(c_shipp)
    assert status == :ok
    assert c_tax.state == "tax"
  end

  test "move to tax state valid parameters but no taxes present calculates the order total" do
    {_, c_addr} = move_cart_to_address_state(setup_cart)
    # delete taxes before moving to shipping since it calculates the taxes.
    Repo.delete_all(Nectar.Tax)
    {_, c_shipp} = move_cart_to_shipping_state(c_addr)
    {status, c_tax} = move_cart_to_tax_state(c_shipp)
    assert status == :ok
    assert c_tax.state == "tax"
    assert c_tax.total > 0
  end

  test "move to tax state calculates the order total" do
    {_, c_addr} = move_cart_to_address_state(setup_cart)
    {_status, c_shipp} = move_cart_to_shipping_state(c_addr)
    {_status, c_tax} = move_cart_to_tax_state(c_shipp)
    assert c_tax.total
  end

  test "move to payment state missing parameters" do
    {_, c_addr} = move_cart_to_address_state(setup_cart)
    {_status, c_shipp} = move_cart_to_shipping_state(c_addr)
    {_status, c_tax} = move_cart_to_tax_state(c_shipp)
    {status, c_payment} = CheckoutManager.next(c_tax, %{})
    assert status == :error
    assert c_payment.errors[:payment] == "can't be blank"
  end

  test "move to payment state valid parameters" do
    {_, c_addr} = move_cart_to_address_state(setup_cart)
    {_status, c_shipp} = move_cart_to_shipping_state(c_addr)
    {_status, c_tax} = move_cart_to_tax_state(c_shipp)
    {status, c_payment} = move_cart_to_payment_state(c_tax)
    assert status == :ok
    assert c_payment.state == "payment"
  end

  test "move to confirmation state missing parameters" do
    {_, c_addr} = move_cart_to_address_state(setup_cart)
    {_status, c_shipp} = move_cart_to_shipping_state(c_addr)
    {_status, c_tax} = move_cart_to_tax_state(c_shipp)
    {_status, c_payment} = move_cart_to_payment_state(c_tax)
    {status,  c_confirm} = CheckoutManager.next(c_payment, %{})
    assert status == :error
    assert c_confirm.errors[:confirm] == "Please confirm to finalise the order"
  end

  test "move to confirmation state valid parameters" do
    {_, c_addr} = move_cart_to_address_state(setup_cart)
    {_status, c_shipp} = move_cart_to_shipping_state(c_addr)
    {_status, c_tax} = move_cart_to_tax_state(c_shipp)
    {_status, c_payment} = move_cart_to_payment_state(c_tax)
    {status,  c_confirm} = move_cart_to_confirmation_state(c_payment)
    assert status == :ok
    assert c_confirm.state == "confirmation"
  end

  test "cannot move back from confirmation state" do
    {_, c_addr} = move_cart_to_address_state(setup_cart)
    {_status, c_shipp} = move_cart_to_shipping_state(c_addr)
    {_status, c_tax} = move_cart_to_tax_state(c_shipp)
    {_status, c_payment} = move_cart_to_payment_state(c_tax)
    {status,  c_confirm} = move_cart_to_confirmation_state(c_payment)
    assert status == :ok
    assert c_confirm.state == "confirmation"
    {:ok, backed_order} = CheckoutManager.back(c_confirm)
    assert backed_order.state == c_confirm.state
  end

  test "moving back from payment state goes to tax state" do
    {_, c_addr} = move_cart_to_address_state(setup_cart)
    {_status, c_shipp} = move_cart_to_shipping_state(c_addr)
    {_status, c_tax} = move_cart_to_tax_state(c_shipp)
    {status, c_payment} = move_cart_to_payment_state(c_tax)
    assert status == :ok
    assert c_payment.state == "payment"
    {:ok, backed_order} = CheckoutManager.back(c_payment)
    assert backed_order.state == "tax"
  end

  test "moving back from payment state deletes the payment" do
    {_, c_addr} = move_cart_to_address_state(setup_cart)
    {_status, c_shipp} = move_cart_to_shipping_state(c_addr)
    {_status, c_tax} = move_cart_to_tax_state(c_shipp)
    {status, c_payment} = move_cart_to_payment_state(c_tax)
    {:ok, backed_order} = CheckoutManager.back(c_payment)
    assert backed_order.state == "tax"
    assert Repo.all(Nectar.Payment.for_order(backed_order)) == []
  end

  test "moving back from tax state goes to shipping state" do
    {_, c_addr} = move_cart_to_address_state(setup_cart)
    {_status, c_shipp} = move_cart_to_shipping_state(c_addr)
    {status, c_tax} = move_cart_to_tax_state(c_shipp)
    assert status == :ok
    assert c_tax.state == "tax"
    {:ok, backed_order} = CheckoutManager.back(c_tax)
    assert backed_order.state == "shipping"
  end

  test "moving back from shipping state goes to address state" do
    {_, c_addr} = move_cart_to_address_state(setup_cart)
    {status, c_shipp} = move_cart_to_shipping_state(c_addr)
    assert status == :ok
    assert c_shipp.state == "shipping"
    {:ok, backed_order} = CheckoutManager.back(c_shipp)
    assert backed_order.state == "address"
  end

  test "moving back from shipping state deletes shipping and adjustments" do
    {_, c_addr} = move_cart_to_address_state(setup_cart)
    {status, c_shipp} = move_cart_to_shipping_state(c_addr)
    assert status == :ok
    assert c_shipp.state == "shipping"
    {:ok, backed_order} = CheckoutManager.back(c_shipp)
    assert backed_order.state == "address"
    assert Repo.all(Nectar.Shipping.for_order(backed_order)) == []
    assert Repo.all(Nectar.Adjustment.for_order(backed_order)) == []
  end


  test "moving back from address state goes to cart state" do
    {status, c_addr} = move_cart_to_address_state(setup_cart)
    assert status == :ok
    assert c_addr.state == "address"
    {:ok, backed_order} = CheckoutManager.back(c_addr)
    assert backed_order.state == "cart"
  end

  test "cannot move back from cart state" do
    cart = setup_cart
    assert cart.state == "cart"
    {:ok, backed_order} = CheckoutManager.back(cart)
    assert backed_order.state == "cart"
  end

  defp setup_cart_without_product do
    create_shipping_methods
    create_taxes
    create_payment_methods
    create_cart
  end

  defp setup_cart do
    cart = setup_cart_without_product
    product = create_product
    master_variant = product.master
    quantity = 2
    {_status, _line_item} = CartManager.add_to_cart(cart.id, %{"variant_id" => master_variant.id, "quantity" => quantity})
    cart
  end

  def setup_cart_with_multiple_products do
    cart = setup_cart_without_product
    [product1, product2] = create_products
    [master_variant1, master_variant2] = [product1.master, product2.master]
    quantity = 2
    {_status, _line_item} = CartManager.add_to_cart(cart.id, %{"variant_id" => master_variant1.id, "quantity" => quantity})
    {_status, _line_item} = CartManager.add_to_cart(cart.id, %{"variant_id" => master_variant2.id, "quantity" => quantity})
    cart
  end

  @address_parameters  %{"address_line_1" => "address line 12", "address_line_2" => "address line 22"}
  defp valid_address_params do
    address = Dict.merge(@address_parameters, valid_country_and_state_ids)
    %{"order_shipping_address" => address, "order_billing_address" => address}
  end

  defp valid_address_params_same_as_billing do
    Map.merge(valid_address_params, %{"same_as_billing" => true})
  end

  defp valid_country_and_state_ids do
    country = create_country
    state = create_state(country)
    %{"country_id" => country.id, "state_id" => state.id}
  end


  defp move_cart_to_address_state(cart) do
    CheckoutManager.next(cart, valid_address_params)
  end

  defp move_cart_to_shipping_state(cart) do
    CheckoutManager.next(cart, valid_shipping_params(cart))
  end

  defp move_cart_to_tax_state(cart) do
    CheckoutManager.next(cart, %{"tax_confirm" => true})
  end

  defp move_cart_to_payment_state(cart) do
    CheckoutManager.next(cart, valid_payment_params(cart))
  end

  defp move_cart_to_confirmation_state(cart) do
    CheckoutManager.next(cart, %{"confirm" => true})
  end

  defp valid_shipping_params(cart) do
    shipping_method_id = create_shipping_methods |> List.first |> Map.get(:id)
    shipment_unit_id =
      cart
      |> Repo.preload([:shipment_units])
      |> Map.get(:shipment_units)
      |> List.first
      |> Map.get(:id)
    %{"shipment_units" => %{ "0" => %{"shipment" => %{"shipping_method_id" => shipping_method_id}, "id" => shipment_unit_id}}}
  end

  defp valid_shipping_params_for_multiple_units(cart) do
    shipping_method_id = create_shipping_methods |> List.first |> Map.get(:id)
    shipment_units =
      cart
      |> Repo.preload([:shipment_units])
      |> Map.get(:shipment_units)
    %{"shipment_units" => Enum.reduce(shipment_units, %{}, fn (shipment_unit, acc) ->
      Map.put_new(acc, Integer.to_string(shipment_unit.id), %{"shipment" => %{"shipping_method_id" => shipping_method_id}, "id" => shipment_unit.id})
       end)}
  end

  defp valid_payment_params(_cart) do
    payment_method_id = create_payment_methods |> List.first |> Map.get(:id)
    %{"payment" => %{"payment_method_id" => payment_method_id}, "payment_method" => %{}}
  end
end

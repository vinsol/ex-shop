defmodule ExShop.Order do
  use ExShop.Web, :model

  alias __MODULE__

  schema "orders" do
    field :slug, :string
    field :state, :string, default: "cart"
    field :confirm, :boolean, virtual: true
    field :total, :decimal
    field :tax_confirm, :boolean, virtual: true

    field :applicable_shipping_methods, {:array, :map}, virtual: true
    field :applicable_payment_methods,  {:array, :map}, virtual: true

    has_many :line_items, ExShop.LineItem
    has_many :adjustments, ExShop.Adjustment
    has_one :shipping, ExShop.Shipping
    has_many :variants, through: [:line_items, :variant]
    has_many :payments, ExShop.Payment

    has_one  :billing_address, ExShop.Address
    has_one  :shipping_address, ExShop.Address

    timestamps
  end

  @required_fields ~w(state)
  @optional_fields ~w(slug total)

  @states ~w(cart address shipping tax payment confirmation)

  def confirmed?(%Order{state: "confirmation"}), do: true
  def confirmed?(%Order{state: _}), do: false

  def cart_changeset(model, params \\ :empty) do
    model
    |> cast(params, @required_fields, @optional_fields)
  end

  def move_back_to_cart_state(order) do
    ExShop.Repo.transaction(fn ->
      order
      |> delete_shippings
      |> delete_tax_adjustments
      |> delete_payments
      |> delete_addresses
      |> cast(%{state: "cart"}, ~w(state), ~w())
      |> ExShop.Repo.update!
    end)
  end

  def move_back_to_address_state(order) do
    ExShop.Repo.transaction(fn ->
      order
      |> delete_shippings
      |> delete_tax_adjustments
      |> delete_payments
      |> cast(%{state: "address"}, ~w(state), ~w())
      |> ExShop.Repo.update!
    end)
  end

  def move_back_to_shipping_state(order) do
    ExShop.Repo.transaction(fn ->
      order
      |> delete_payments
      |> delete_shippings
      |> cast(%{state: "shipping"}, ~w(state), ~w())
      |> ExShop.Repo.update!
    end)
  end

  def move_back_to_tax_state(order) do
    ExShop.Repo.transaction(fn ->
      order
      |> reset_payments
      |> cast(%{state: "tax"}, ~w(state), ~w())
      |> ExShop.Repo.update!
    end)
  end

  def move_back_to_payment_state(order) do
    ExShop.Repo.transaction(fn ->
      order
      |> cast(%{state: "payment"}, ~w(state), ~w())
      |> ExShop.Repo.update!
    end)
  end

  alias ExShop.Repo

  defp delete_shippings(order) do
    shipping_ids = Repo.all(from o in assoc(order, :shipping), select: o.id)
    Repo.delete_all(from o in assoc(order, :adjustments), where: o.shipping_id in ^shipping_ids)
    Repo.delete_all(from o in assoc(order, :shipping))
    order
  end

  defp delete_tax_adjustments(order) do
    Repo.delete_all(from o in assoc(order, :adjustments), where: not(is_nil(o.tax_id)))
    order
  end

  defp delete_payments(order) do
    # will want to create a refund here
    Repo.delete_all(from o in assoc(order, :payments))
    order
  end

  defp delete_addresses(order) do
    # Caution, dangerous bug, since assoc will load with where order_id
    # both of these actions have same impact
    Repo.delete_all(from o in assoc(order, :billing_address))
    Repo.delete_all(from o in assoc(order, :shipping_address))
    order
  end

  def reset_payments(order) do
    Repo.update_all((from o in assoc(order, :payments)), set: [selected: false])
    order
  end

  def confirm_availability(order) do
    {sufficient_quantity_available, oos_items} =
      ExShop.LineItem
      |> ExShop.LineItem.in_order(order.model)
      |> ExShop.Repo.all
      |> ExShop.Repo.preload(:variant)
      |> Enum.reduce({true, []}, fn (ln_item, {status, out_of_stock}) ->
                                   {available, _} = ExShop.LineItem.sufficient_quantity_available?(ln_item)
                                   if available do
                                     {status, out_of_stock}
                                   else
                                     {false, [ln_item|out_of_stock]}
                                   end
                                 end)
    if sufficient_quantity_available do
      order
    else
      name_of_oos =
       oos_items
       |> Enum.reduce("", fn (item, acc) -> acc <> ExShop.Variant.display_name(item.variant) <> "," end)
      add_error(order, :line_items, "#{name_of_oos} are out of stock")
    end
  end

  # returns the appropriate changeset required based on the next state
  def transition_changeset(model, next_state, params \\ :empty) do
    case params do
      :empty -> apply(ExShop.Order, String.to_atom("#{next_state}_changeset"), [with_preloaded_assoc(model, next_state)])
        _    -> apply(ExShop.Order,
                      String.to_atom("#{next_state}_changeset"),
                      [with_preloaded_assoc(model, next_state), Dict.merge(%{"state" => next_state}, params)])
    end
  end

  def with_preloaded_assoc(model, "address") do
    ExShop.Repo.get!(Order, model.id)
    |> ExShop.Repo.preload([:shipping_address, :billing_address, :line_items])
  end

  def with_preloaded_assoc(model, "shipping") do
    order = ExShop.Repo.get!(Order, model.id) |> Repo.preload([:shipping])
    %Order{order|applicable_shipping_methods: ExShop.ShippingCalculator.calculate_applicable_shippings(order)}
  end

  def with_preloaded_assoc(model, "tax") do
    ExShop.Repo.get!(Order, model.id)
    |> ExShop.Repo.preload([adjustments: [:tax, shipping: :shipping_method]])
  end

  def with_preloaded_assoc(model, "payment") do
    ExShop.Repo.get!(Order, model.id)
    |> ExShop.Repo.preload([payments: :payment_method])
  end

  def with_preloaded_assoc(model, "confirmation") do
    ExShop.Repo.get!(Order, model.id)
    |> ExShop.Repo.preload([line_items: :variant])
  end

  def with_preloaded_assoc(model, _) do
    model
  end

  def settle_adjustments_and_product_payments(model) do
    total =
      shipping_total(model)
      |> Decimal.add(tax_total(model))
      |> Decimal.add(product_total(model))

    model
    |> cast(%{total: total}, @required_fields, @optional_fields)
    |> ExShop.Repo.update!
  end

  def shipping_total(model) do
    ExShop.Repo.one(
      from shipping_adj in assoc(model, :adjustments),
      where: not is_nil(shipping_adj.shipping_id),
      select: sum(shipping_adj.amount)
    )
  end

  def tax_total(model) do
    ExShop.Repo.one(
      from tax_adj in assoc(model, :adjustments),
      where: not is_nil(tax_adj.tax_id),
      select: sum(tax_adj.amount)
    )
  end

  def product_total(model) do
    ExShop.Repo.one(
      from line_item in assoc(model, :line_items),
      select: sum(line_item.total)
    )
  end

  def acquire_variant_stock(model) do
    Enum.each(model.line_items, &ExShop.LineItem.acquire_stock_from_variant/1)
    model
  end

  def restock_unfullfilled_line_items(model) do
    Enum.each(model.line_items, &ExShop.LineItem.restock_variant/1)
    model
  end

  def address_changeset(model, params \\ :empty) do
    model
    |> cast(params, @required_fields, @optional_fields)
    |> ensure_cart_is_not_empty
    |> cast_assoc(:shipping_address, required: true)
    |> cast_assoc(:billing_address, required: true)
  end

  # use this to set shipping
  def shipping_changeset(model, params \\ :empty) do
    model
    |> cast(shipping_params(model, params), @required_fields, @optional_fields)
    |> cast_assoc(:shipping, required: true, with: &ExShop.Shipping.applicable_shipping_changeset/2)
  end

  defp shipping_params(order, %{"shipping" => shipping_params} = params) do
    shipping_method = ExShop.Repo.get(ExShop.ShippingMethod, shipping_params["shipping_method_id"])
    %{params | "shipping" => %{shipping_method_id: shipping_method.id,
                              adjustment: %{amount: ExShop.ShippingCalculator.shipping_cost(shipping_method, order), order_id: order.id}}}
  end
  defp shipping_params(order, params), do: params

  # no changes to be made with tax
  def tax_changeset(model, params \\ :empty) do
    model
    |> cast(params, ~w(tax_confirm state), @optional_fields)
    |> validate_tax_confirmed
  end

  # select payment method from list of payments
  def payment_changeset(model, params \\ :empty) do
    model
    |> cast(params, @required_fields, @optional_fields)
    |> cast_assoc(:payments, required: true)
    |> ensure_only_one_payment_selected
  end

  # Check availability and othe stuff here
  def confirmation_changeset(model, params \\ :empty) do
    model
    |> cast(params, ~w(confirm state), ~w())
    |> validate_order_confirmed
  end

  defp ensure_only_one_payment_selected(model) do
    selected =
      get_field(model, :payments)
      |> Enum.filter(&(&1.selected))

    case selected do
      []  -> add_error(model, :payments, "Please select one payment method")
      [_] -> model
      _   -> add_error(model, :payments, "Please select only 1 payment method")
    end

  end

  defp validate_order_confirmed(model) do
    confirmed = get_field(model, :confirm)
    if confirmed do
      model
    else
      add_error(model, :confirm, "Please confirm to finalise the order")
    end
  end

  defp validate_tax_confirmed(model) do
    confirmed = get_field(model, :tax_confirm)
    if confirmed do
      model
    else
      add_error(model, :tax_confirm, "Please confirm to proceed")
    end
  end

  defp ensure_cart_is_not_empty(model) do
    line_items = get_field(model, :line_items)
    case line_items do
      []  -> add_error(model, :line_items, "Please add some item to your cart to proceed")
      _   -> model
    end
  end

end

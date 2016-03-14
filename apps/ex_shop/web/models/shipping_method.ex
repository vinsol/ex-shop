defmodule ExShop.ShippingMethod do
  use ExShop.Web, :model

  schema "shipping_methods" do
    field :name
    field :enabled, :boolean, default: false

    has_many :shippings, ExShop.Shipping
    field :shipping_cost, :decimal, virtual: true, default: Decimal.new("0")

    timestamps
  end

  @required_fields ~w(name)
  @optional_fields ~w(enabled)

  def changeset(model, params \\ :empty) do
    model
    |> cast(params, @required_fields, @optional_fields)
  end

  def enabled_shipping_methods do
    from shipp in ExShop.ShippingMethod,
    where: shipp.enabled
  end

  def enable(shipping_method_ids) do
    from shipping in ExShop.ShippingMethod,
    where: shipping.id in ^shipping_method_ids,
    update: [set: [enabled: true]]
  end

  def disable_other_than(shipping_method_ids) do
    from shipping in ExShop.ShippingMethod,
    where: not shipping.id in ^shipping_method_ids,
    update: [set: [enabled: false]]
  end

end

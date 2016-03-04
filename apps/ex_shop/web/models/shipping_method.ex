defmodule ExShop.ShippingMethod do
  use ExShop.Web, :model

  schema "shipping_methods" do
    field :name
    has_many :shippings, ExShop.Shipping

    field :shipping_cost, :decimal, virtual: true, default: Decimal.new("0")

    timestamps
  end

  @required_fields ~w(name)
  @optional_fields ~w()

  def changeset(model, params \\ :empty) do
    model
    |> cast(params, @required_fields, @optional_fields)
  end


end

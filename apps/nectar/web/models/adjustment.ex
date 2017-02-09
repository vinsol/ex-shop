defmodule Nectar.Adjustment do
  use Nectar.Web, :model

  schema "adjustments" do
    belongs_to :shipment, Nectar.Shipment
    belongs_to :tax,      Nectar.Tax
    belongs_to :order,    Nectar.Order

    field :amount, :decimal

    timestamps()
    extensions()
  end

  @required_fields ~w(amount)a
  @optional_fields ~w(shipment_id tax_id order_id)a

  def changeset(model, params \\ %{}) do
    model
    |> cast(params, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
  end

end

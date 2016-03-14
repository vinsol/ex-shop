defmodule ExShop.PaymentMethod do

  use ExShop.Web, :model

  schema "payment_methods" do
    field :name, :string
    has_many :payments, ExShop.Payment
    field :enabled, :boolean, default: false
  end

  @required_fields ~w(name)
  @optional_fields ~w(enabled)

  def changeset(model, params \\ :empty) do
    model
    |> cast(params, @required_fields, @optional_fields)
  end

  def enabled_payment_methods do
    from pay in ExShop.PaymentMethod,
    where: pay.enabled
  end

  def enable(payment_method_ids) do
    from payment in ExShop.PaymentMethod,
    where: payment.id in ^payment_method_ids,
    update: [set: [enabled: true]]
  end

  def disable_other_than(payment_method_ids) do
    from payment in ExShop.PaymentMethod,
    where: not payment.id in ^payment_method_ids,
    update: [set: [enabled: false]]
  end
end

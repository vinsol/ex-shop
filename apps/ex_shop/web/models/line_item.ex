defmodule ExShop.LineItem do
  use ExShop.Web, :model
  alias ExShop.Order
  alias ExShop.Variant
  alias ExShop.Repo

  schema "line_items" do
    belongs_to :variant, ExShop.Variant
    belongs_to :order, ExShop.Order
    field :quantity, :integer
    field :total, :decimal
    field :fullfilled, :boolean, default: true
    timestamps
  end

  # @required_fields ~w()
  # @optional_fields ~w()

  def changeset(model, params \\ :empty) do
    model
    |> order_id_changeset(params)
    |> quantity_changeset(params)
  end

  def fullfillment_changeset(model, params \\ :empty) do
    model
    |> cast(params, ~w(fullfilled), ~w())
  end

  def order_id_changeset(model, params \\ :empty) do
    model
    |> cast(params, ~w(order_id), ~w())
    |> foreign_key_constraint(:order_id)
  end

  def quantity_changeset(model, params \\ :empty) do
    model
    |> cast(params, ~w(quantity), ~w(fullfilled))
    |> validate_number(:quantity, greater_than: 0)
    |> preload_assoc
    |> validate_product_availability
    |> update_total_changeset(params)
  end

  defp update_total_changeset(model, params) do
    quantity = get_field(model, :quantity)
    variant  = get_field(model, :variant)
    cost = Decimal.mult(Decimal.new(quantity), variant.cost_price)
    cast(model, Map.merge(params, %{total: cost}), ~w(total), ~w())
  end

  def move_stock(%ExShop.LineItem{fullfilled: true} = line_item) do
    remove_stock_from_variant(line_item)
  end
  def move_stock(%ExShop.LineItem{fullfilled: false} = line_item) do
    move_stock_back_to_variant(line_item)
  end

  def remove_stock_from_variant(%ExShop.LineItem{variant: variant, quantity: quantity, fullfilled: true}) do
    variant
    |> Variant.buy_changeset(%{buy_count: quantity})
    |> Repo.update!
  end

  def remove_stock_from_variant(%ExShop.LineItem{variant: variant, quantity: quantity}) do
    variant
  end

  def move_stock_back_to_variant(%ExShop.LineItem{variant: variant, quantity: quantity, fullfilled: false}) do
    variant
    |> Variant.restocking_changeset(%{restock_count: quantity})
    |> Repo.update!
  end

  def move_stock_back_to_variant(%ExShop.LineItem{variant: variant, quantity: quantity}) do
    variant
  end

  def in_order(query, %Order{id: order_id}) do
    from c in query, where: c.order_id == ^order_id
  end

  def with_variant(query, %Variant{id: variant_id}) do
    from c in query, where: c.variant_id == ^variant_id
  end

  # assures that the product is preloaded before validation
  # of the quantity
  defp preload_assoc(%Ecto.Changeset{} = changeset) do
    %Ecto.Changeset{changeset| model: preload_assoc(changeset.model)}
  end

  defp preload_assoc(%ExShop.LineItem{} = line_item) do
    Repo.preload(line_item, [:variant, :order])
  end

  def sufficient_quantity_available?(%ExShop.LineItem{} = line_item) do
    requested_quantity = line_item.quantity
    sufficient_quantity_available?(line_item, requested_quantity)
  end

  def sufficient_quantity_available?(%ExShop.LineItem{} = line_item, requested_quantity) do
    available_product_quantity = line_item.variant |> Variant.available_quantity
    {requested_quantity <= available_product_quantity, available_product_quantity}
  end

  def validate_product_availability(changeset) do
    case sufficient_quantity_available?(changeset.model, changeset.changes[:quantity]) do
      {true, _} -> changeset
      {false, 0} -> add_error(changeset, :variant, "out of stock")
      {false, available_product_quantity} -> add_error(changeset, :quantity, "only #{available_product_quantity} available")
    end
  end

end

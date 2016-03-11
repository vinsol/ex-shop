defmodule ExShop.ProductCategory do
  use ExShop.Web, :model

  schema "product_categories" do
    belongs_to :product, ExShop.Product
    belongs_to :category, ExShop.Category

    field :delete, :boolean, virtual: true, default: false

    timestamps
  end

  @required_fields ~w(product_id category_id)
  @optional_fields ~w()

  @doc """
  Creates a changeset based on the `model` and `params`.

  If no params are provided, an invalid changeset is returned
  with no validation performed.
  """
  def changeset(model, params \\ :empty) do
    model
    |> cast(params, @required_fields, @optional_fields)
  end

  def from_product_changeset(model, params \\ :empty) do
    cast(model, params, ~w(category_id), ~w(delete))
    |> set_delete_action
    |> unique_constraint(:category_id, name: :unique_product_category)
  end

  def set_delete_action(changeset) do
    if get_change(changeset, :delete) do
      %{changeset| action: :delete}
    else
      changeset
    end
  end

end

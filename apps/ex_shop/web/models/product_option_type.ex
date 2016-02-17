defmodule ExShop.ProductOptionType do
  use ExShop.Web, :model

  schema "product_option_types" do
    field :delete, :boolean, virtual: true

    belongs_to :product, ExShop.Product
    belongs_to :option_type, ExShop.OptionType

    timestamps
  end

  @required_fields ~w(product_id option_type_id)
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
    cast(model, params, ~w(option_type_id), ~w(delete))
    |> set_delete_action
  end

  def set_delete_action(changeset) do
    if get_change(changeset, :delete) do
      %{changeset | action: :delete}
    else
      changeset
    end
  end
end

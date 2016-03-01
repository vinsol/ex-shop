defmodule ExShop.Product do
  use ExShop.Web, :model
  use Arc.Ecto.Model

  schema "products" do
    field :name, :string
    field :description, :string
    field :available_on, Ecto.Date
    field :discontinue_on, Ecto.Date
    field :slug, :string

    has_one :master, ExShop.Variant, on_delete: :nilify_all # As this and below association same, how to handle on_delete
    has_many :variants, ExShop.Variant, on_delete: :nilify_all

    has_many :product_option_types, ExShop.ProductOptionType
    has_many :option_types, through: [:product_option_types, :option_type]

    timestamps
  end

  @required_fields ~w(name description available_on)
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

  def create_changeset(model, params \\ :empty) do
    model
    |> cast(params, @required_fields, @optional_fields)
    |> ExShop.Slug.generate_slug()
    |> cast_assoc(:master, required: true, with: &create_master_changeset/2)
    |> cast_assoc(:product_option_types, required: true, with: &ExShop.ProductOptionType.from_product_changeset/2)
    |> unique_constraint(:slug)
  end

  def update_changeset(model, params \\ :empty) do
    model
    |> cast(params, @required_fields, @optional_fields)
    |> ExShop.Slug.generate_slug()
    |> cast_assoc(:master, required: true, with: &update_master_changeset/2)
    |> cast_assoc(:product_option_types, required: true, with: &ExShop.ProductOptionType.from_product_changeset/2)
    |> unique_constraint(:slug)
  end

  def create_master_changeset(model, params \\ :empty) do
    cast(model, params, ~w(cost_price), ~w())
    |> put_change(:is_master, true)
    |> cast_attachments(params, ~w(), ~w(image))
  end

  def master_variant(model) do
    from variant in all_variants_including_master(model), where: variant.is_master
  end

  def all_variants(model) do
    from variant in all_variants(model), where: not(variant.is_master)
  end

  def all_variants_including_master(model) do
    from variant in assoc(model, :variants)
  end

  def update_master_changeset(model, params \\ :empty) do
    cast(model, params, ~w(cost_price), ~w())
    |> put_change(:is_master, true)
    |> check_is_master_changed
    # Even if changset is invalid, cast_attachments does it work :(
    |> cast_attachments(params, ~w(), ~w(image))
  end

  defp check_is_master_changed(changeset) do
    if get_change(changeset, :is_master) do
      add_error(changeset, :is_master, "appears to assign another variant as master variant")
      |> add_error(:base, "Please check whether your Master Variant is deleted :(")
    else
      changeset
    end
  end
end

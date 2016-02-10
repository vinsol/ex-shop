defmodule ExShop.Setting do
  use ExShop.Web, :model

  schema "settings" do
    field :name, :string
    field :slug, :string
    embeds_many :settings, ExShop.SettingPair
  end

  @required_fields ~w(name)
  @optional_fields ~w(slug)

  def changeset(model, params \\ :empty) do
    model
    |> cast(params, @required_fields, @optional_fields)
    |> generate_slug()
    |> cast_embed(:settings)
  end

  defp generate_slug(changeset) do
    if name = get_change(changeset, :name) do
      put_change(changeset, :slug, slugify(name))
    else
      changeset
    end
  end

  defp slugify(str) do
    str
    |> String.downcase()
    |> String.replace(~r/[^\w-]+/, "-")
  end

end

defimpl Phoenix.Param, for: ExShop.Setting do
  def to_param(%{slug: slug}) do
    slug
  end
end

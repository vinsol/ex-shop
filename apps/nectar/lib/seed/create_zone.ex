defmodule Seed.CreateZone do
  import Ecto.Query

  def seed! do
    seed_eu_zone!()
    seed_north_america!()
  end

  @eu_zone_members ~w(PL FI PT RO DE FR SK HU SI IE AT ES IT BE SE LV BG GB LT CY LU MT DK NL EE)

  defp seed_eu_zone! do
    eu_zone_model =
      Nectar.Zone.changeset(%Nectar.Zone{}, %{ name: "EU_VAT", description: "Countries that make up the EU VAT zone.", type: "Country"})
      |> Nectar.Repo.insert!()

    Enum.each(@eu_zone_members,
      fn(zone_member) ->
        load_country(zone_member)
        |> Ecto.build_assoc(:zone_members)
        |> Nectar.ZoneMember.changeset(%{zone_id: eu_zone_model.id})
        |> Nectar.Repo.insert!
      end
    )
  end

  @north_america_zone_members ~w(US CA)

  defp seed_north_america! do
    north_america_zone_model =
      Nectar.Zone.changeset(%Nectar.Zone{}, %{ name: "North America", description: "USA + Canada", type: "Country"})
      |> Nectar.Repo.insert!()

    Enum.each(@north_america_zone_members,
      fn(zone_member) ->
        load_country(zone_member)
        |> Ecto.build_assoc(:zone_members)
        |> Nectar.ZoneMember.changeset(%{zone_id: north_america_zone_model.id})
        |> Nectar.Repo.insert!
      end
    )
  end

  defp load_country(country_code) do
    query = from c in Nectar.Country, where: c.iso == ^country_code
    Nectar.Repo.one(query)
  end
end

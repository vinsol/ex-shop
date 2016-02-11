defmodule ExShop.Admin.ZoneController do
  use ExShop.Web, :controller

  alias ExShop.Zone

  plug :scrub_params, "zone" when action in [:create, :update]

  def index(conn, _params) do
    zones = Repo.all(Zone)
    render(conn, "index.html", zones: zones)
  end

  def new(conn, _params) do
    changeset = Zone.changeset(%Zone{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"zone" => zone_params}) do
    changeset = Zone.changeset(%Zone{}, zone_params)
    case Repo.insert(changeset) do
      {:ok, _zone} ->
        conn
        |> put_flash(:info, "Zone created successfully.")
        |> redirect(to: admin_zone_path(conn, :index))
      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    zone = Repo.get!(Zone, id)
    zone_members = Repo.all Zone.members(zone)
    zoneables = Zone.zoneables(zone)
    render(conn, "show.html", zone: zone, zone_members: zone_members, zoneables: zoneables)
  end

  def edit(conn, %{"id" => id}) do
    zone = Repo.get!(Zone, id)
    changeset = Zone.changeset(zone)
    render(conn, "edit.html", zone: zone, changeset: changeset)
  end

  def update(conn, %{"id" => id, "zone" => zone_params}) do
    zone = Repo.get!(Zone, id)
    changeset = Zone.changeset(zone, zone_params)
    case Repo.update(changeset) do
      {:ok, zone} ->
        conn
        |> put_flash(:info, "Zone updated successfully.")
        |> redirect(to: admin_zone_path(conn, :show, zone))
      {:error, changeset} ->
        render(conn, "edit.html", zone: zone, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    zone = Repo.get!(Zone, id)

    # Here we use delete! (with a bang) because we expect
    # it to always work (and if it does not, it will raise).
    Repo.delete!(zone)

    conn
    |> put_flash(:info, "Zone deleted successfully.")
    |> redirect(to: admin_zone_path(conn, :index))
  end


end

defmodule ExShop.TaxCalculator do

  alias ExShop.Order
  alias ExShop.Repo
  import Ecto.Query

  def calculate_taxes(%Order{} = order) do
    order
    |> create_tax_adjustments
  end

  defp create_tax_adjustments(%Order{adjustments: adjustments} = order) do
    taxes = Repo.all(ExShop.Tax)
    tax_adjustments = Enum.map(taxes, fn (tax) ->
      order
      |> Ecto.build_assoc(:adjustments)
      |> ExShop.Adjustment.changeset(%{amount: 20.00, tax_id: tax.id})
      |> ExShop.insert
    end)
    %Order{order | adjustments: [adjustments | tax_adjustments]}
  end

end

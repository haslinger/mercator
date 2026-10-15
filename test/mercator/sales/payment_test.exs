defmodule Mercator.Sales.PaymentTest do
  # the database: whether online payment is active is a setting (only read here)
  use Mercator.DataCase, async: true

  alias Mercator.Sales.Payment

  test "everybody can pay in advance, on pickup only when picking up (no online payment active)" do
    customer = %{invoice_allowed: false}

    assert Payment.methods_for(customer, :parcel) == [:prepayment]
    assert Payment.methods_for(customer, :pickup) == [:prepayment, :on_pickup]
  end

  test "invoice only for approved customers" do
    approved = %{invoice_allowed: true}

    assert Payment.methods_for(approved, :freight) == [:prepayment, :invoice]
    assert Payment.methods_for(approved, :pickup) == [:prepayment, :invoice, :on_pickup]
  end

  test "labels" do
    assert Payment.label(:prepayment) == "Vorauskasse"
  end
end

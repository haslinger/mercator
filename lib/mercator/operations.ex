defmodule Mercator.Operations do
  @moduledoc """
  Running the shop (#105): incidents for the back office. Problems the
  system notices (a PDF that could not be created, a background job that
  failed for good, …) and problems staff record by hand (#107) become
  incidents that someone looks into and resolves.

  The system reports through `Mercator.Operations.Incidents.report/1`.
  """
  use Ash.Domain,
    otp_app: :mercator,
    extensions: [AshAdmin.Domain, AshPhoenix]

  admin do
    show? true
  end

  resources do
    resource Mercator.Operations.Incident do
      define :get_incident, action: :read, get_by: [:id]
      define :search_incidents, action: :search
      define :create_incident, action: :create
      define :update_incident, action: :update
      define :resolve_incident, action: :resolve
      define :reopen_incident, action: :reopen
    end
  end
end

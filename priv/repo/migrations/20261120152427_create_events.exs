defmodule TeamCalendar.Repo.Migrations.CreateEvents do
  use Ecto.Migration

  def change do
    create table(:events) do
      add :title, :string, null: false
      add :starts_on, :date, null: false
      add :ends_on, :date, null: false
      add :color, :string, null: false, default: "purple"
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create constraint(:events, :ends_on_not_before_starts_on, check: "ends_on >= starts_on")
    create index(:events, [:starts_on, :ends_on])
  end
end

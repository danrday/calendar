defmodule TeamCalendar.Events.Event do
  @moduledoc """
  An all-day event spanning one or more whole days (`starts_on..ends_on`, inclusive).
  """
  use Ecto.Schema
  import Ecto.Changeset

  @colors ~w(purple blue green orange red gray)

  schema "events" do
    field :title, :string
    field :starts_on, :date
    field :ends_on, :date
    field :color, :string, default: "purple"
    field :notes, :string

    timestamps(type: :utc_datetime)
  end

  def colors, do: @colors

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:title, :starts_on, :ends_on, :color, :notes])
    |> validate_required([:title, :starts_on, :ends_on, :color])
    |> validate_length(:title, max: 200)
    |> validate_inclusion(:color, @colors)
    |> validate_date_order()
    |> check_constraint(:ends_on,
      name: :ends_on_not_before_starts_on,
      message: "can't be before the start date"
    )
  end

  defp validate_date_order(changeset) do
    starts_on = get_field(changeset, :starts_on)
    ends_on = get_field(changeset, :ends_on)

    if starts_on && ends_on && Date.compare(ends_on, starts_on) == :lt do
      add_error(changeset, :ends_on, "can't be before the start date")
    else
      changeset
    end
  end
end

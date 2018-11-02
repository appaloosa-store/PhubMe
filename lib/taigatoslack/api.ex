defmodule TaigaToSlack.Api do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(TaigaToSlack.Web, []),
      Cron
    ]

    opts = [strategy: :one_for_one, name: TaigaToSlack.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

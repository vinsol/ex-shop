defmodule Nectar do
  use Application
  import Supervisor.Spec, warn: false

  if Mix.env == :test do
    def children, do: [
      # Start the endpoint when the application starts
      # Commented to Avoid - repo Nectar.Repo is not started, please ensure it is part of your supervision tree
      supervisor(Nectar.Endpoint, []),
      # Start the Ecto repository
      supervisor(Nectar.Repo, []),
      # Here you could define other workers and supervisors as children
      # worker(Nectar.Worker, [arg1, arg2, arg3]),

      worker(Commerce.Billing.Worker, stripe_worker_configuration, id: :stripe),
      worker(Commerce.Billing.Worker, braintree_worker_configuration, id: :braintree)
    ]

  else
   def children, do: [
        # Start the endpoint when the application starts
        # Commented to Avoid - repo Nectar.Repo is not started, please ensure it is part of your supervision tree
        # supervisor(Nectar.Endpoint, []),
        # Start the Ecto repository
        supervisor(Nectar.Repo, []),
        # Here you could define other workers and supervisors as children
        # worker(Nectar.Worker, [arg1, arg2, arg3]),

        worker(Commerce.Billing.Worker, stripe_worker_configuration, id: :stripe),
        worker(Commerce.Billing.Worker, braintree_worker_configuration, id: :braintree)
    ]
  end

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do


    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Nectar.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    Nectar.Endpoint.config_change(changed, removed)
    :ok
  end

  def stripe_worker_configuration do
    worker_config = Application.get_env(:nectar, :stripe)
    gateway_type = worker_config[:type]
    settings = %{credentials: worker_config[:credentials],
                 default_currency: worker_config[:default_currency]}
    [gateway_type, settings, [name: :stripe]]
  end

  def braintree_worker_configuration do
    worker_config = Application.get_env(:nectar, :braintree)
    gateway_type = worker_config[:type]
    settings = %{}
    [gateway_type, settings, [name: :braintree]]
  end

  # when running nectar tests we need the nectar endpoint running.

end

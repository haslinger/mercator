defmodule MercatorWeb.Router do
  use MercatorWeb, :router

  use AshAuthentication.Phoenix.Router

  import AshAuthentication.Plug.Helpers

  pipeline :browser do
    plug :accepts, ["html"]
    # old page paths redirect permanently, before any session work
    plug MercatorWeb.Plugs.PageRedirect
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MercatorWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_from_session
    plug MercatorWeb.Locale
    plug MercatorWeb.Navigation
    plug MercatorWeb.BasketSession
  end

  # Content-Security-Policy for the shop and the admin area; not for the dev
  # tools (LiveDashboard, mailbox), which bring their own inline scripts
  pipeline :csp do
    plug MercatorWeb.Plugs.ContentSecurityPolicy
  end

  # the client IP for the rate limits of sign-in and auth emails (#126)
  pipeline :auth_context do
    plug MercatorWeb.Plugs.AuthContext
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :load_from_bearer
    plug :set_actor, :user
  end

  scope "/brand", MercatorWeb do
    get "/:image", BrandController, :show
  end

  scope "/", MercatorWeb do
    get "/manifest.webmanifest", ManifestController, :show
    get "/sitemap.xml", SitemapController, :index
    get "/robots.txt", SitemapController, :robots
  end

  scope "/uploads", MercatorWeb do
    get "/*path", UploadController, :show
  end

  # payment providers report status changes here (phase 7): no session, no
  # CSRF token; the status is always fetched from the provider
  scope "/payments", MercatorWeb do
    post "/:provider/webhook", PaymentWebhookController, :create
  end

  scope "/", MercatorWeb do
    pipe_through [:browser, :csp]

    # printable offers (#99), offer and order PDFs (#17)
    get "/account/offers/:id/print", OfferPrintController, :customer
    get "/account/offers/:id/pdf", OfferPrintController, :customer_pdf
    get "/admin/offers/:id/print", OfferPrintController, :staff
    get "/admin/offers/:id/pdf", OfferPrintController, :staff_pdf
    get "/account/orders/:number/pdf", OrderPdfController, :show
    get "/admin/orders/:number/pdf", OrderPdfController, :show

    ash_authentication_live_session :authenticated_routes,
      on_mount_prepend: [{MercatorWeb.Locale, :default}, {MercatorWeb.Navigation, :default}],
      on_mount: [
        {MercatorWeb.BasketSession, :default},
        {MercatorWeb.LiveUserAuth, :require_name},
        {MercatorWeb.IncidentBadge, :default},
        {MercatorWeb.HelpLink, :default}
      ] do
      # in each liveview, add one of the following at the top of the module:
      #
      # If an authenticated user must be present:
      # on_mount {MercatorWeb.LiveUserAuth, :live_user_required}
      #
      # If an authenticated user *may* be present:
      # on_mount {MercatorWeb.LiveUserAuth, :live_user_optional}
      #
      # If an authenticated user must *not* be present:
      # on_mount {MercatorWeb.LiveUserAuth, :live_no_user}

      live "/", PageLive, :home
      live "/categories/:slug", CategoryLive
      live "/products/:slug", ProductLive
      live "/search", SearchLive
      live "/basket", BasketLive
      live "/terms", GtcLive
      # help for shop visitors (phase 9, #125)
      live "/help", HelpLive, :index
      live "/help/:slug", HelpLive, :show
      live "/pages/*path", PageLive

      live "/account", AccountLive
      live "/account/name", NameLive
      live "/account/addresses", AddressesLive
      live "/account/orders", OrdersLive
      live "/account/orders/:number", OrderLive, :show
      # back from the payment provider (phase 7)
      live "/account/orders/:number/payment", OrderLive, :payment
      # the payment simulator's "payment page" (dev, tests, demo)
      live "/payments/simulator/:id", PaymentSimulatorLive
      live "/account/offers", OffersLive
      live "/account/offers/:id", OfferLive
      live "/checkout", CheckoutLive

      live "/admin", Admin.DashboardLive
      live "/admin/products", Admin.ProductIndexLive, :index
      live "/admin/products/new", Admin.ProductIndexLive, :new
      live "/admin/products/:id", Admin.ProductEditLive
      live "/admin/categories", Admin.CategoryTreeLive, :index
      live "/admin/categories/new", Admin.CategoryTreeLive, :new
      live "/admin/categories/:id/edit", Admin.CategoryTreeLive, :edit
      live "/admin/desk", Admin.DeskLive
      live "/admin/desk/:id", Admin.DeskLive
      live "/admin/conversations", Admin.ConversationArchiveLive
      live "/admin/orders", Admin.OrderIndexLive
      live "/admin/orders/:number", Admin.OrderShowLive
      live "/admin/offers", Admin.OfferIndexLive
      live "/admin/offers/:id", Admin.OfferEditLive
      live "/admin/pages", Admin.PageTreeLive, :index
      live "/admin/pages/new", Admin.PageTreeLive, :new
      live "/admin/pages/:id", Admin.PageEditLive
      live "/admin/media", Admin.MediaLive
      live "/admin/submissions", Admin.SubmissionLive
      live "/admin/terms", Admin.GtcLive
      live "/admin/tax-classes", Admin.TaxClassLive
      live "/admin/incidents", Admin.IncidentIndexLive, :index
      live "/admin/incidents/new", Admin.IncidentIndexLive, :new
      live "/admin/incidents/:id", Admin.IncidentLive
      live "/admin/payment-providers", Admin.PaymentProviderLive
      live "/admin/users", Admin.UserIndexLive
      live "/admin/users/:id", Admin.UserEditLive
      # the documentation (phase 9)
      live "/admin/help", Admin.HelpLive, :index
      live "/admin/help/:part/:slug", Admin.HelpLive, :show
    end
  end

  scope "/", MercatorWeb do
    pipe_through [:browser, :csp, :auth_context]

    get "/checkout/sign-in", CheckoutController, :sign_in
    # one-click sign-in to a public demo account (demo mode only)
    post "/demo/sign-in", AuthController, :demo_sign_in
    auth_routes AuthController, Mercator.Accounts.User, path: "/auth"

    sign_out_route AuthController, "/sign-out",
      live_view: MercatorWeb.SignOutLive,
      on_mount_prepend: [{MercatorWeb.Locale, :default}]

    # Remove these if you'd like to use your own authentication views
    sign_in_route register_path: "/register",
                  live_view: MercatorWeb.SignInLive,
                  reset_path: "/reset",
                  auth_routes_prefix: "/auth",
                  gettext_backend: {MercatorWeb.Gettext, "auth"},
                  on_mount_prepend: [{MercatorWeb.Locale, :default}],
                  on_mount: [{MercatorWeb.LiveUserAuth, :live_no_user}],
                  overrides: [
                    MercatorWeb.AuthOverrides,
                    AshAuthentication.Phoenix.Overrides.Default
                  ]

    # Remove this if you do not want to use the reset password feature
    reset_route auth_routes_prefix: "/auth",
                gettext_backend: {MercatorWeb.Gettext, "auth"},
                on_mount_prepend: [{MercatorWeb.Locale, :default}],
                overrides: [
                  MercatorWeb.AuthOverrides,
                  AshAuthentication.Phoenix.Overrides.Default
                ]

    # Remove this if you do not use the confirmation strategy
    confirm_route Mercator.Accounts.User, :confirm_new_user,
      auth_routes_prefix: "/auth",
      gettext_backend: {MercatorWeb.Gettext, "auth"},
      on_mount_prepend: [{MercatorWeb.Locale, :default}],
      overrides: [MercatorWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]

    # Remove this if you do not use the magic link strategy.
    magic_sign_in_route(Mercator.Accounts.User, :magic_link,
      auth_routes_prefix: "/auth",
      gettext_backend: {MercatorWeb.Gettext, "auth"},
      on_mount_prepend: [{MercatorWeb.Locale, :default}],
      overrides: [MercatorWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]
    )
  end

  # Other scopes may use custom stacks.
  # scope "/api", MercatorWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:mercator, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: MercatorWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  # Raw-data tool for development only (#61); staff use /admin.
  if Application.compile_env(:mercator, :dev_routes) do
    import AshAdmin.Router

    scope "/dev" do
      pipe_through :browser

      ash_admin "/ash-admin"
    end
  end
end

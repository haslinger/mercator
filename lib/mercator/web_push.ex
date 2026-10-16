defmodule Mercator.WebPush do
  @moduledoc """
  Web Push (#151–#153): notifications to the browsers of staff, also when
  the shop is not open, through the browser's push service (Google's for
  Chrome, Mozilla's, Apple's). Free, no account: the shop identifies itself
  with its own key pair (VAPID, RFC 8292). Payloads are encrypted for the
  device (RFC 8291), so the push service cannot read them.

  Implemented with `:crypto` and `Req`, no library:

      config :mercator, Mercator.WebPush,
        public_key: "B…",   # base64url, uncompressed P-256 point
        private_key: "…",   # base64url, 32 bytes
        subject: "mailto:shop@example.com",
        # tests: req_options: [plug: {Req.Test, Mercator.WebPush}]
        req_options: []

  Without keys Web Push is off (`enabled?/0`). New keys: `mix mercator.gen.vapid`.
  """

  # messages older than this are dropped by the push service (#151: a
  # "customer waiting" notice from hours ago is useless)
  @ttl 900
  @record_size 4096

  @type subscription :: %{endpoint: String.t(), p256dh: String.t(), auth: String.t()}

  @doc "Whether keys are configured."
  def enabled?, do: is_binary(config(:public_key)) and is_binary(config(:private_key))

  @doc "The public key for `pushManager.subscribe` (base64url), or nil."
  def public_key, do: config(:public_key)

  @doc "A new key pair `{public, private}`, base64url (for `mix mercator.gen.vapid`)."
  def generate_keys do
    {public, private} = :crypto.generate_key(:ecdh, :prime256v1)
    {encode(public), encode(private)}
  end

  @doc """
  Sends `payload` (a map, sent as JSON) to a subscription. `:topic` lets the
  push service replace an undelivered message with the same topic.

  Returns `:ok`, `{:error, :gone}` when the subscription no longer exists
  (the device unsubscribed; delete it), or `{:error, reason}`.
  """
  @spec deliver(subscription(), map(), keyword()) :: :ok | {:error, term()}
  def deliver(subscription, payload, opts \\ []) do
    if enabled?() do
      body = encrypt(Jason.encode!(payload), subscription.p256dh, subscription.auth)

      [
        method: :post,
        url: subscription.endpoint,
        body: body,
        headers:
          [
            {"content-encoding", "aes128gcm"},
            {"content-type", "application/octet-stream"},
            {"ttl", Integer.to_string(@ttl)},
            # delivered at once, also while Android dozes
            {"urgency", "high"},
            {"authorization", authorization(subscription.endpoint)}
          ] ++ topic_header(opts[:topic]),
        retry: false
      ]
      |> Keyword.merge(config(:req_options, []))
      |> Req.request()
      |> handle_response()
    else
      {:error, :not_configured}
    end
  end

  defp topic_header(nil), do: []
  defp topic_header(topic), do: [{"topic", topic}]

  defp handle_response({:ok, %Req.Response{status: status}}) when status in 200..299, do: :ok

  defp handle_response({:ok, %Req.Response{status: status}}) when status in [404, 410],
    do: {:error, :gone}

  defp handle_response({:ok, %Req.Response{status: status, body: body}}),
    do: {:error, {:http, status, body}}

  defp handle_response({:error, exception}), do: {:error, exception}

  # --- VAPID (RFC 8292) ---

  defp authorization(endpoint) do
    %URI{scheme: scheme, host: host, port: port} = URI.parse(endpoint)
    audience = "#{scheme}://#{host}" <> if(port in [80, 443, nil], do: "", else: ":#{port}")
    exp = System.system_time(:second) + 12 * 3600
    "vapid t=#{jwt(audience, exp)}, k=#{config(:public_key)}"
  end

  @doc false
  def jwt(audience, exp) do
    header = encode(Jason.encode!(%{typ: "JWT", alg: "ES256"}))
    claims = encode(Jason.encode!(%{aud: audience, exp: exp, sub: subject()}))
    input = header <> "." <> claims

    {:"ECDSA-Sig-Value", r, s} =
      :ecdsa
      |> :crypto.sign(:sha256, input, [decode(config(:private_key)), :prime256v1])
      |> then(&:public_key.der_decode(:"ECDSA-Sig-Value", &1))

    # JWS wants r and s as two 32-byte numbers, not DER
    input <> "." <> encode(<<r::unsigned-big-256, s::unsigned-big-256>>)
  end

  defp subject do
    config(:subject) ||
      case Application.get_env(:mercator, :mail_from) do
        {_name, address} when is_binary(address) -> "mailto:" <> address
        _none -> "mailto:noreply@example.com"
      end
  end

  # --- encryption (RFC 8291, content coding aes128gcm of RFC 8188) ---

  @doc """
  Encrypts `plaintext` for a device: `p256dh` is its public key, `auth` its
  secret (both base64url, from the subscription). `server_keys` and `salt`
  are random unless given (tests).
  """
  def encrypt(plaintext, p256dh, auth, server_keys \\ nil, salt \\ nil) do
    ua_public = decode(p256dh)
    auth_secret = decode(auth)
    {as_public, as_private} = server_keys || :crypto.generate_key(:ecdh, :prime256v1)
    salt = salt || :crypto.strong_rand_bytes(16)

    shared = :crypto.compute_key(:ecdh, ua_public, as_private, :prime256v1)
    prk_key = hmac(auth_secret, shared)
    ikm = hmac(prk_key, "WebPush: info" <> <<0>> <> ua_public <> as_public <> <<1>>)
    prk = hmac(salt, ikm)
    <<cek::binary-16, _rest::binary>> = hmac(prk, "Content-Encoding: aes128gcm" <> <<0, 1>>)
    <<nonce::binary-12, _rest::binary>> = hmac(prk, "Content-Encoding: nonce" <> <<0, 1>>)

    # one record; 0x02 marks the last record (no further padding)
    {ciphertext, tag} =
      :crypto.crypto_one_time_aead(:aes_128_gcm, cek, nonce, plaintext <> <<2>>, "", true)

    salt <>
      <<@record_size::unsigned-big-32, byte_size(as_public)::8>> <> as_public <> ciphertext <> tag
  end

  defp hmac(key, data), do: :crypto.mac(:hmac, :sha256, key, data)

  @doc false
  def encode(binary), do: Base.url_encode64(binary, padding: false)

  @doc false
  def decode(string), do: Base.url_decode64!(string, padding: false)

  defp config(key, default \\ nil),
    do: :mercator |> Application.get_env(__MODULE__, []) |> Keyword.get(key, default)
end

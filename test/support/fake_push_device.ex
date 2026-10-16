defmodule Mercator.FakePushDevice do
  @moduledoc """
  A browser receiving Web Push in tests: its key pair and auth secret, and
  the decryption of what `Mercator.WebPush` sends (RFC 8291/8188 from the
  receiving side).
  """

  @doc "A new device; `subscription/2` gives what its browser would send to the shop."
  def new do
    {public, private} = :crypto.generate_key(:ecdh, :prime256v1)
    %{public: public, private: private, auth: :crypto.strong_rand_bytes(16)}
  end

  @doc "The browser's subscription params for this device."
  def subscription(device, endpoint) do
    %{
      "endpoint" => endpoint,
      "p256dh" => Base.url_encode64(device.public, padding: false),
      "auth" => Base.url_encode64(device.auth, padding: false),
      "user_agent" => "FakePushDevice"
    }
  end

  @doc "Decrypts a request body sent to this device."
  def decrypt(device, body) do
    <<salt::binary-16, _rs::32, 65, as_public::binary-65, rest::binary>> = body
    shared = :crypto.compute_key(:ecdh, as_public, device.private, :prime256v1)
    prk_key = hmac(device.auth, shared)
    ikm = hmac(prk_key, "WebPush: info" <> <<0>> <> device.public <> as_public <> <<1>>)
    prk = hmac(salt, ikm)
    <<cek::binary-16, _::binary>> = hmac(prk, "Content-Encoding: aes128gcm" <> <<0, 1>>)
    <<nonce::binary-12, _::binary>> = hmac(prk, "Content-Encoding: nonce" <> <<0, 1>>)
    size = byte_size(rest) - 16
    <<ciphertext::binary-size(^size), tag::binary-16>> = rest

    :aes_128_gcm
    |> :crypto.crypto_one_time_aead(cek, nonce, ciphertext, "", tag, false)
    |> String.trim_trailing(<<2>>)
  end

  defp hmac(key, data), do: :crypto.mac(:hmac, :sha256, key, data)
end

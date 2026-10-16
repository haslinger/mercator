defmodule Mercator.WebPushTest do
  # Req.Test stubs are owned by the test process, so this can run async
  use ExUnit.Case, async: true

  alias Mercator.{FakePushDevice, WebPush}

  # RFC 8291, Appendix A
  @plaintext "When I grow up, I want to be a watermelon"
  @as_public "BP4z9KsN6nGRTbVYI_c7VJSPQTBtkgcy27mlmlMoZIIgDll6e3vCYLocInmYWAmS6TlzAC8wEqKK6PBru3jl7A8"
  @as_private "yfWPiYE-n46HLnH0KqZOF1fJJU3MYrct3AELtAQ-oRw"
  @ua_public "BCVxsr7N_eNgVRqvHtD0zTZsEc6-VV-JvLexhqUzORcxaOzi6-AYWXvTBHm4bjyPjs7Vd8pZGH6SRpkNtoIAiw4"
  @ua_private "q1dXpw3UpT5VOmu_cf_v6ih07Aems3njxI-JWgLcM94"
  @auth "BTBZMqHH6r4Tts7J_aSIgg"
  @salt "DGv6ra1nlYgDCS1FRnbzlw"
  @message "DGv6ra1nlYgDCS1FRnbzlwAAEABBBP4z9KsN6nGRTbVYI_c7VJSPQTBtkgcy27mlmlMoZIIgDll6e3vCYLocInmYWAmS6TlzAC8wEqKK6PBru3jl7A_yl95bQpu6cVPTpK4Mqgkf1CXztLVBSt2Ks3oZwbuwXPXLWyouBWLVWGNWQexSgSxsj_Qulcy4a-fN"

  describe "encrypt/5" do
    test "matches the example of RFC 8291" do
      body =
        WebPush.encrypt(
          @plaintext,
          @ua_public,
          @auth,
          {WebPush.decode(@as_public), WebPush.decode(@as_private)},
          WebPush.decode(@salt)
        )

      assert WebPush.encode(body) == @message
    end

    test "the device can decrypt it" do
      body = WebPush.encrypt(~s({"title":"Hallo"}), @ua_public, @auth)
      assert decrypt(body) == ~s({"title":"Hallo"})
    end
  end

  describe "jwt/2" do
    test "is an ES256 token the public key verifies" do
      [header, claims, signature] =
        "https://fcm.googleapis.com" |> WebPush.jwt(1_900_000_000) |> String.split(".")

      assert %{"alg" => "ES256"} = header |> WebPush.decode() |> Jason.decode!()

      assert %{
               "aud" => "https://fcm.googleapis.com",
               "exp" => 1_900_000_000,
               "sub" => "mailto:" <> _
             } =
               claims |> WebPush.decode() |> Jason.decode!()

      <<r::unsigned-big-256, s::unsigned-big-256>> = WebPush.decode(signature)
      der = :public_key.der_encode(:"ECDSA-Sig-Value", {:"ECDSA-Sig-Value", r, s})

      assert :crypto.verify(:ecdsa, :sha256, header <> "." <> claims, der, [
               WebPush.decode(WebPush.public_key()),
               :prime256v1
             ])
    end
  end

  describe "deliver/3" do
    @subscription %{
      endpoint: "https://push.example.com/send/abc",
      p256dh: @ua_public,
      auth: @auth
    }

    test "posts the encrypted payload with the VAPID header" do
      Req.Test.stub(WebPush, fn conn ->
        assert conn.request_path == "/send/abc"
        # (Req's test plug consumes the content-encoding header itself)
        assert Plug.Conn.get_req_header(conn, "urgency") == ["high"]
        assert Plug.Conn.get_req_header(conn, "topic") == ["abc123"]
        assert ["vapid t=" <> _] = Plug.Conn.get_req_header(conn, "authorization")
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        send(self(), {:payload, decrypt(body)})
        Plug.Conn.send_resp(conn, 201, "")
      end)

      assert :ok = WebPush.deliver(@subscription, %{title: "Hallo"}, topic: "abc123")
      assert_received {:payload, ~s({"title":"Hallo"})}
    end

    test "reports subscriptions that are gone" do
      Req.Test.stub(WebPush, &Plug.Conn.send_resp(&1, 410, "gone"))
      assert {:error, :gone} = WebPush.deliver(@subscription, %{title: "Hallo"})
    end

    test "reports other failures" do
      Req.Test.stub(WebPush, &Plug.Conn.send_resp(&1, 429, "slow down"))
      assert {:error, {:http, 429, _body}} = WebPush.deliver(@subscription, %{title: "Hallo"})
    end
  end

  defp decrypt(body) do
    FakePushDevice.decrypt(
      %{
        public: WebPush.decode(@ua_public),
        private: WebPush.decode(@ua_private),
        auth: WebPush.decode(@auth)
      },
      body
    )
  end
end

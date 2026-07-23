import gleam/dict
import gleam/http.{Get, Head, Options}
import gleam/http/request
import gleam/http/response
import gleam/httpc
import gleam/string
import gleeunit
import mock_server

pub fn main() {
  mock_server.start()
  gleeunit.main()
}

pub fn request_test() {
  let req =
    request.new()
    |> request.set_method(Get)
    |> request.set_scheme(http.Http)
    |> request.set_host("localhost")
    |> request.set_port(mock_server.http_port())
    |> request.set_path("/")
    |> request.prepend_header("accept", "text/plain")

  let assert Ok(http_resp) = httpc.send(req)
  assert http_resp.status == 200
  assert response.get_header(http_resp, "content-type")
    == Ok("application/json")

  let resp = mock_server.decode_response(http_resp.body)
  assert resp.method == "GET"
  assert resp.path == "/"
  assert dict.get(resp.headers, "accept") == Ok("text/plain")
}

pub fn get_request_discards_body_test() {
  let assert Ok(req) = request.to(mock_server.url("/"))
  let req = request.set_body(req, "This gets dropped")

  let assert Ok(http_resp) = httpc.send(req)
  assert http_resp.status == 200

  let resp = mock_server.decode_response(http_resp.body)
  assert resp.method == "GET"
  assert resp.path == "/"
  assert resp.body == ""
}

pub fn head_request_discards_body_test() {
  let assert Ok(req) = request.to(mock_server.url("/"))
  let req =
    req
    |> request.set_method(Head)
    |> request.set_body("This gets dropped")

  let assert Ok(resp) = httpc.send(req)
  assert resp.status == 200
  assert resp.body == ""
}

pub fn options_request_discards_body_test() {
  let assert Ok(req) = request.to(mock_server.url("/"))
  let req =
    req
    |> request.set_method(Options)
    |> request.set_body("This gets dropped")

  let assert Ok(http_resp) = httpc.send(req)
  assert http_resp.status == 200

  let resp = mock_server.decode_response(http_resp.body)
  assert resp.method == "OPTIONS"
  assert resp.path == "/"
  assert resp.body == ""
}

pub fn invalid_tls_test() {
  let assert Ok(req) = request.to("https://expired.badssl.com")

  // This will fail because of invalid TLS
  let assert Error(httpc.FailedToConnect(
    ip4: httpc.TlsAlert("certificate_expired", _),
    ip6: _,
  )) = httpc.send(req)

  // This will fail because of invalid TLS
  let assert Error(httpc.FailedToConnect(
    ip4: httpc.TlsAlert("certificate_expired", _),
    ip6: _,
  )) =
    httpc.configure()
    |> httpc.verify_tls(True)
    |> httpc.dispatch(req)

  let assert Ok(response) =
    httpc.configure()
    |> httpc.verify_tls(False)
    |> httpc.dispatch(req)
  assert 200 == response.status
}

pub fn ipv6_test() {
  let assert Ok(req) = request.to(mock_server.ipv6_url("/"))
  let assert Ok(http_resp) = httpc.send(req)
  assert 200 == http_resp.status

  let resp = mock_server.decode_response(http_resp.body)
  assert resp.path == "/"
}

pub fn follow_redirects_option_test() {
  let assert Ok(req) = request.to(mock_server.url("/redirect"))

  let assert Ok(http_resp) = httpc.send(req)
  assert http_resp.status == 308

  let assert Ok(http_resp) =
    httpc.configure()
    |> httpc.follow_redirects(False)
    |> httpc.dispatch(req)
  assert http_resp.status == 308

  let assert Ok(http_resp) =
    httpc.configure()
    |> httpc.follow_redirects(True)
    |> httpc.dispatch(req)
  assert http_resp.status == 200

  let resp = mock_server.decode_response(http_resp.body)
  assert resp.path == "/redirected"
}

pub fn default_user_agent_test() {
  let assert Ok(req) = request.to(mock_server.url("/"))
  let assert Ok(http_resp) = httpc.send(req)

  let resp = mock_server.decode_response(http_resp.body)
  let assert Ok(user_agent) = dict.get(resp.headers, "user-agent")
  assert string.starts_with(user_agent, "gleam_httpc/")
}

pub fn custom_user_agent_test() {
  let assert Ok(req) = request.to(mock_server.url("/"))
  let assert Ok(http_resp) =
    httpc.send(request.set_header(req, "user-agent", "gleam-test"))

  let resp = mock_server.decode_response(http_resp.body)
  assert dict.get(resp.headers, "user-agent") == Ok("gleam-test")
}

pub fn timeout_success_test() {
  let assert Ok(req) = request.to(mock_server.url("/delay/100"))

  let assert Ok(http_resp) =
    httpc.configure()
    |> httpc.timeout(500)
    |> httpc.dispatch(req)

  assert http_resp.status == 200
}

pub fn timeout_error_test() {
  let assert Ok(req) = request.to(mock_server.url("/delay/500"))

  assert httpc.configure()
    |> httpc.timeout(200)
    |> httpc.dispatch(req)
    == Error(httpc.ResponseTimeout)
}

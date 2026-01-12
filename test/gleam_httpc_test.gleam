import gleam/erlang/process
import gleam/http.{Get, Head, Options}
import gleam/http/request
import gleam/http/response
import gleam/httpc
import gleam/string
import gleeunit

pub fn main() {
  gleeunit.main()
}

pub fn request_test() {
  let req =
    request.new()
    |> request.set_method(Get)
    |> request.set_host("test-api.service.hmrc.gov.uk")
    |> request.set_path("/hello/world")
    |> request.prepend_header("accept", "application/vnd.hmrc.1.0+json")

  let assert Ok(resp) = httpc.send(req)
  assert 200 == resp.status
  assert response.get_header(resp, "content-type") == Ok("application/json")
  assert resp.body == "{\"message\":\"Hello World\"}"
}

pub fn get_request_discards_body_test() {
  let req =
    request.new()
    |> request.set_method(Get)
    |> request.set_host("test-api.service.hmrc.gov.uk")
    |> request.set_path("/hello/world")
    |> request.set_body("This gets dropped")
    |> request.prepend_header("accept", "application/vnd.hmrc.1.0+json")

  let assert Ok(resp) = httpc.send(req)
  assert 200 == resp.status
  assert Ok("application/json") == response.get_header(resp, "content-type")
  assert "{\"message\":\"Hello World\"}" == resp.body
}

pub fn head_request_discards_body_test() {
  let req =
    request.new()
    |> request.set_method(Head)
    |> request.set_host("postman-echo.com")
    |> request.set_path("/get")
    |> request.set_body("This gets dropped")

  let assert Ok(resp) = httpc.send(req)
  assert 200 == resp.status
  assert Ok("application/json; charset=utf-8")
    == response.get_header(resp, "content-type")
  assert "" == resp.body
}

pub fn options_request_discards_body_test() {
  let req =
    request.new()
    |> request.set_method(Options)
    |> request.set_host("postman-echo.com")
    |> request.set_path("/get")
    |> request.set_body("This gets dropped")

  let assert Ok(resp) = httpc.send(req)
  assert 200 == resp.status
  assert Ok("text/html; charset=utf-8")
    == response.get_header(resp, "content-type")
  assert "GET,HEAD,PUT,POST,DELETE,PATCH" == resp.body
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
  // This URL is ipv6 only
  let assert Ok(req) = request.to("https://ipv6.google.com")
  let assert Ok(resp) = httpc.send(req)
  assert 200 == resp.status
}

pub fn follow_redirects_option_test() {
  // This redirects to https://
  let assert Ok(req) = request.to("http://packages.gleam.run")

  // disabled by default
  let assert Ok(resp) = httpc.send(req)
  assert 308 == resp.status

  let assert Ok(resp) =
    httpc.configure()
    |> httpc.follow_redirects(False)
    |> httpc.dispatch(req)
  assert 308 == resp.status

  let assert Ok(resp) =
    httpc.configure()
    |> httpc.follow_redirects(True)
    |> httpc.dispatch(req)
  assert 200 == resp.status
}

pub fn default_user_agent_test() {
  let assert Ok(req) = request.to("https://echo.free.beeceptor.com")
  let assert Ok(resp) = httpc.send(req)
  assert string.contains(resp.body, "\"User-Agent\": \"gleam_httpc/")
}

pub fn custom_user_agent_test() {
  let assert Ok(req) = request.to("https://echo.free.beeceptor.com")
  let assert Ok(resp) =
    httpc.send(request.set_header(req, "user-agent", "gleam-test"))
  assert string.contains(resp.body, "\"User-Agent\": \"gleam-test")
}

pub fn timeout_success_test() {
  let req =
    request.new()
    |> request.set_method(Get)
    |> request.set_host("httpbin.org")
    |> request.set_path("/delay/1")

  let assert Ok(resp) =
    httpc.configure()
    |> httpc.timeout(5000)
    |> httpc.dispatch(req)

  assert 200 == resp.status
}

pub fn timeout_error_test() {
  let req =
    request.new()
    |> request.set_method(Get)
    |> request.set_host("httpbin.org")
    |> request.set_path("/delay/1")

  assert httpc.configure()
    |> httpc.timeout(200)
    |> httpc.dispatch(req)
    == Error(httpc.ResponseTimeout)
}

pub fn send_stream_request_test() {
  let req =
    request.new()
    |> request.set_method(Get)
    |> request.set_host("postman-echo.com")
    |> request.set_path("/stream/1")

  let assert Ok(request_id) =
    httpc.configure()
    |> httpc.dispatch_stream_request(req)

  let selector =
    process.new_selector()
    |> httpc.select_stream_messages(httpc.raw_stream_mapper())

  let assert Ok(httpc.StreamStart(request_id_, _headers, pid)) =
    process.selector_receive(selector, 1000)
  assert request_id_ == request_id

  httpc.receive_next_stream_message(pid)
  let assert Ok(httpc.StreamChunk(request_id_, _binary_part)) =
    process.selector_receive(selector, 1000)
  assert request_id_ == request_id

  httpc.receive_next_stream_message(pid)
  let assert Ok(httpc.StreamEnd(request_id_, _headers)) =
    process.selector_receive(selector, 1000)
  assert request_id_ == request_id
}

pub fn dispatch_stream_request_test() {
  let req =
    request.new()
    |> request.set_method(Get)
    |> request.set_host("postman-echo.com")
    |> request.set_path("/stream/1")

  let config =
    httpc.configure()
    |> httpc.timeout(5000)

  let assert Ok(request_id) = httpc.dispatch_stream_request(config, req)

  let selector =
    process.new_selector()
    |> httpc.select_stream_messages(httpc.raw_stream_mapper())

  let assert Ok(httpc.StreamStart(request_id_, _headers, pid)) =
    process.selector_receive(selector, 1000)
  assert request_id_ == request_id

  httpc.receive_next_stream_message(pid)
  let assert Ok(httpc.StreamChunk(request_id_, _binary_part)) =
    process.selector_receive(selector, 1000)
  assert request_id_ == request_id

  httpc.receive_next_stream_message(pid)
  let assert Ok(httpc.StreamEnd(request_id_, _headers)) =
    process.selector_receive(selector, 1000)
  assert request_id_ == request_id
}

pub fn send_stream_request_error_test() {
  // httpstat.us has a special “500?fail=true” mode that closes the
  // connection mid-response.  This results in httpc reporting a
  // SocketClosedRemotely
  let req =
    request.new()
    |> request.set_method(Get)
    |> request.set_host("httpstat.us")
    |> request.set_path("/500?fail=true")

  let selector =
    process.new_selector()
    |> httpc.select_stream_messages(httpc.raw_stream_mapper())

  let assert Ok(request_id) =
    httpc.configure()
    |> httpc.dispatch_stream_request(req)

  assert process.selector_receive(selector, 1000)
    == Ok(httpc.StreamError(request_id, httpc.SocketClosedRemotely))
}

import gleam/httpc
import gleam/http.{Get, Head, Options}
import gleam/list
import gleeunit
import gleam/erlang
import gleam/erlang/atom

pub fn main() {
  // Start the required applications
  // TODO: Only start gleam_httpc this once this is implemented
  // https://github.com/gleam-lang/gleam/issues/650
  assert Ok(_) =
    erlang.ensure_all_started(atom.create_from_string("gleam_httpc"))

  // Run the tests
  gleeunit.main()
}

pub fn request_test() {
  let req =
    http.default_req()
    |> http.set_method(Get)
    |> http.set_host("test-api.service.hmrc.gov.uk")
    |> http.set_path("/hello/world")
    |> http.prepend_req_header("accept", "application/vnd.hmrc.1.0+json")

  assert Ok(resp) = httpc.send(req)
  assert 200 = resp.status
  assert Ok("application/json") = http.get_resp_header(resp, "content-type")
  assert "{\"message\":\"Hello World\"}" = resp.body
}

pub fn get_request_discards_body_test() {
  let req =
    http.default_req()
    |> http.set_method(Get)
    |> http.set_host("test-api.service.hmrc.gov.uk")
    |> http.set_path("/hello/world")
    |> http.set_req_body("This gets dropped")
    |> http.prepend_req_header("accept", "application/vnd.hmrc.1.0+json")

  assert Ok(resp) = httpc.send(req)
  assert 200 = resp.status
  assert Ok("application/json") = http.get_resp_header(resp, "content-type")
  assert "{\"message\":\"Hello World\"}" = resp.body
}

pub fn head_request_discards_body_test() {
  let req =
    http.default_req()
    |> http.set_method(Head)
    |> http.set_host("postman-echo.com")
    |> http.set_path("/get")
    |> http.set_req_body("This gets dropped")

  assert Ok(resp) = httpc.send(req)
  assert 200 = resp.status
  assert Ok("application/json; charset=utf-8") =
    http.get_resp_header(resp, "content-type")
  assert "" = resp.body
}

pub fn options_request_discards_body_test() {
  let req =
    http.default_req()
    |> http.set_method(Options)
    |> http.set_host("postman-echo.com")
    |> http.set_path("/get")
    |> http.set_req_body("This gets dropped")

  assert Ok(resp) = httpc.send(req)
  assert 200 = resp.status
  assert Ok("text/html; charset=utf-8") =
    http.get_resp_header(resp, "content-type")
  assert "GET,HEAD,PUT,POST,DELETE,PATCH" = resp.body
}

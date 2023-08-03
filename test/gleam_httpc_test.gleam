import gleam/httpc
import gleam/http.{Get, Head, Options}
import gleam/http/request
import gleam/http/response
import gleeunit
import gleam/erlang
import gleam/erlang/atom

pub fn main() {
  // Start the required applications
  let assert Ok(_) =
    "gleam_httpc"
    |> atom.create_from_string
    |> erlang.ensure_all_started

  // Run the tests
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
  let assert 200 = resp.status
  let assert Ok("application/json") = response.get_header(resp, "content-type")
  let assert "{\"message\":\"Hello World\"}" = resp.body
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
  let assert 200 = resp.status
  let assert Ok("application/json") = response.get_header(resp, "content-type")
  let assert "{\"message\":\"Hello World\"}" = resp.body
}

pub fn head_request_discards_body_test() {
  let req =
    request.new()
    |> request.set_method(Head)
    |> request.set_host("postman-echo.com")
    |> request.set_path("/get")
    |> request.set_body("This gets dropped")

  let assert Ok(resp) = httpc.send(req)
  let assert 200 = resp.status
  let assert Ok("application/json; charset=utf-8") =
    response.get_header(resp, "content-type")
  let assert "" = resp.body
}

pub fn options_request_discards_body_test() {
  let req =
    request.new()
    |> request.set_method(Options)
    |> request.set_host("postman-echo.com")
    |> request.set_path("/get")
    |> request.set_body("This gets dropped")

  let assert Ok(resp) = httpc.send(req)
  let assert 200 = resp.status
  let assert Ok("text/html; charset=utf-8") =
    response.get_header(resp, "content-type")
  let assert "GET,HEAD,PUT,POST,DELETE,PATCH" = resp.body
}

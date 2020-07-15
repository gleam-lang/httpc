import gleam/httpc
import gleam/http.{Get, Head, Options, Post, Response}
import gleam/list
import gleam/should

pub fn request_test() {
  let req = http.default_req()
    |> http.set_method(Get)
    |> http.set_host("test-api.service.hmrc.gov.uk")
    |> http.set_path("/hello/world")
    |> http.prepend_req_header("accept", "application/vnd.hmrc.1.0+json")

  assert Ok(resp) = httpc.send(req)

  resp.status
  |> should.equal(200)

  resp
  |> http.get_resp_header("content-type")
  |> should.equal(Ok("application/json"))

  resp.body
  |> should.equal("{\"message\":\"Hello World\"}")
}

pub fn get_request_discards_body_test() {
  let req = http.default_req()
    |> http.set_method(Get)
    |> http.set_host("test-api.service.hmrc.gov.uk")
    |> http.set_path("/hello/world")
    |> http.set_req_body("This gets dropped")
    |> http.prepend_req_header("accept", "application/vnd.hmrc.1.0+json")

  assert Ok(resp) = httpc.send(req)

  resp.status
  |> should.equal(200)

  resp
  |> http.get_resp_header("content-type")
  |> should.equal(Ok("application/json"))

  resp.body
  |> should.equal("{\"message\":\"Hello World\"}")
}

pub fn head_request_discards_body_test() {
  let req = http.default_req()
    |> http.set_method(Head)
    |> http.set_host("postman-echo.com")
    |> http.set_path("/get")
    |> http.set_req_body("This gets dropped")

  assert Ok(resp) = httpc.send(req)

  resp.status
  |> should.equal(200)

  resp
  |> http.get_resp_header("content-type")
  |> should.equal(Ok("application/json; charset=utf-8"))

  resp.body
  |> should.equal("")
}

pub fn options_request_discards_body_test() {
  let req = http.default_req()
    |> http.set_method(Options)
    |> http.set_host("postman-echo.com")
    |> http.set_path("/get")
    |> http.set_req_body("This gets dropped")

  assert Ok(resp) = httpc.send(req)

  resp.status
  |> should.equal(200)

  resp
  |> http.get_resp_header("content-type")
  |> should.equal(Ok("text/html; charset=utf-8"))

  resp.body
  |> should.equal("GET,HEAD,PUT,POST,DELETE,PATCH")
}

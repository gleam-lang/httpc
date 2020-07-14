import gleam/httpc
import gleam/http.{Get, Head, Options, Post, Response}
import gleam/list
import gleam/should

pub fn request_test() {
  let url = "https://test-api.service.hmrc.gov.uk/hello/world"
  assert Ok(req) = http.request(Get, url)

  assert Ok(
    resp,
  ) = req
    |> http.prepend_req_header("accept", "application/vnd.hmrc.1.0+json")
    |> httpc.send

  resp.status
  |> should.equal(200)

  resp
  |> http.get_resp_header("content-type")
  |> should.equal(Ok("application/json"))

  resp.body
  |> should.equal("{\"message\":\"Hello World\"}")
}

pub fn get_request_discards_body_test() {
  assert Ok(
    req,
  ) = http.request(Get, "https://test-api.service.hmrc.gov.uk/hello/world")
  assert Ok(
    resp,
  ) = req
    |> http.prepend_req_header("accept", "application/vnd.hmrc.1.0+json")
    |> http.prepend_req_header("content-type", "application-json")
    |> httpc.send

  resp.status
  |> should.equal(200)

  resp
  |> http.get_resp_header("content-type")
  |> should.equal(Ok("application/json"))

  resp.body
  |> should.equal("{\"message\":\"Hello World\"}")
}

pub fn head_request_discards_body_test() {
  assert Ok(req) = http.request(Head, "https://postman-echo.com/get")
  assert Ok(
    resp,
  ) = req
    |> http.set_req_body("This gets dropped")
    |> httpc.send

  resp.status
  |> should.equal(200)

  resp
  |> http.get_resp_header("content-type")
  |> should.equal(Ok("application/json; charset=utf-8"))

  resp.body
  |> should.equal("")
}

pub fn options_request_discards_body_test() {
  assert Ok(req) = http.request(Options, "https://postman-echo.com/get")
  assert Ok(
    resp,
  ) = req
    |> http.set_req_body("This gets dropped")
    |> httpc.send

  resp.status
  |> should.equal(200)

  resp
  |> http.get_resp_header("content-type")
  |> should.equal(Ok("text/html; charset=utf-8"))

  resp.body
  |> should.equal("GET,HEAD,PUT,POST,DELETE,PATCH")
}

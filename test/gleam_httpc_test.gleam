import gleam/httpc.{NoBody, StringBody}
import gleam/http.{Get, Head, Options}
import gleam/list
import gleam/should

pub fn request_test() {
  let Ok(
    response,
  ) = httpc.request(
    method: Get,
    url: "https://test-api.service.hmrc.gov.uk/hello/world",
    headers: [tuple("accept", "application/vnd.hmrc.1.0+json")],
    body: NoBody,
  )
  let httpc.Response(status, headers, body) = response
  should.equal(status, 200)
  should.equal(list.key_find(headers, "content-type"), Ok("application/json"))
  should.equal(body, "{\"message\":\"Hello World\"}")
}

pub fn get_request_discards_body_test() {
  let Ok(
    response,
  ) = httpc.request(
    method: Get,
    url: "https://test-api.service.hmrc.gov.uk/hello/world",
    headers: [tuple("accept", "application/vnd.hmrc.1.0+json")],
    body: StringBody(content_type: "application/json", body: "{}"),
  )
  let httpc.Response(status, headers, body) = response
  should.equal(status, 200)
  should.equal(list.key_find(headers, "content-type"), Ok("application/json"))
  should.equal(body, "{\"message\":\"Hello World\"}")
}

pub fn head_request_discards_body_test() {
  let Ok(
    response,
  ) = httpc.request(
    method: Head,
    url: "https://postman-echo.com/get",
    headers: [],
    body: StringBody(content_type: "application/json", body: "{}"),
  )
  let httpc.Response(status, headers, body) = response
  should.equal(status, 200)
  should.equal(
    list.key_find(headers, "content-type"),
    Ok("application/json; charset=utf-8"),
  )
  should.equal(body, "")
}

pub fn options_request_discards_body_test() {
  let Ok(
    response,
  ) = httpc.request(
    method: Options,
    url: "https://postman-echo.com/get",
    headers: [],
    body: StringBody(content_type: "application/json", body: "{}"),
  )
  let httpc.Response(status, headers, body) = response
  should.equal(status, 200)
  should.equal(
    list.key_find(headers, "content-type"),
    Ok("text/html; charset=utf-8"),
  )
  should.equal(body, "GET,HEAD,PUT,POST,DELETE,PATCH")
}

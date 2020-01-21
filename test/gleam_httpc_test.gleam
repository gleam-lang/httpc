import gleam/httpc.{None}
import gleam/http.{Get}
import gleam/list
import gleam/expect

pub fn request_test() {
  let Ok(response) = httpc.request(
    method: Get,
    url: "https://test-api.service.hmrc.gov.uk/hello/world",
    headers: [tuple("accept", "application/vnd.hmrc.1.0+json")],
    body: None,
  )
  let httpc.Response(status, headers, body) = response
  expect.equal(status, 200)
  expect.equal(list.key_find(headers, "content-type"), Ok("application/json"))
  expect.equal(body, "{\"message\":\"Hello World\"}")
}

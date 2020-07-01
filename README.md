# httpc

Bindings to Erlang's built in HTTP client, `httpc`.

```rust
import gleam/httpc.{Response, NoBody}
import gleam/http.{Get}
import gleam/bit_string
import gleam/should

pub fn request_test() {
  // Make a HTTP request
  try response = httpc.request(
    method: Get,
    url: "https://test-api.service.hmrc.gov.uk/hello/world",
    headers: [tuple("accept", "application/vnd.hmrc.1.0+json")],
    body: NoBody,
  )

  // We get back a Response record
  should.equal(response, Response(
    status: 200,
    headers: [tuple("content-type", "application/json")],
    body: <<"{\"message\":\"Hello World\"}">>,
  ))

  // We can convert the response body into a String if it is valid utf-8
  bit_string.to_string(response.body)
}
```

## Installation

This package can be installed by adding `gleam_httpc` to your `rebar.config`
dependencies:

```erlang
{deps, [
    gleam_httpc
]}.
```

You may also need to add the `gleam_httpc` OTP application to your `.app.src`
file, depending on how you run your program.

```erlang
{applications, [
  kernel,
  stdlib,
  ssl,
  inets,
  gleam_stdlib,
  gleam_httpc
]},
```

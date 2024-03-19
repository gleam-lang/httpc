# httpc
<a href="https://github.com/gleam-lang/httpc/releases"><img src="https://img.shields.io/github/release/gleam-lang/httpc" alt="GitHub release"></a>
<a href="https://discord.gg/Fm8Pwmy"><img src="https://img.shields.io/discord/768594524158427167?color=blue" alt="Discord chat"></a>
![CI](https://github.com/gleam-lang/httpc/workflows/test/badge.svg?branch=main)

Bindings to Erlang's built in HTTP client, `httpc`.

```gleam
import gleam/httpc
import gleam/http.{Get}
import gleam/http/request
import gleam/http/response
import gleam/result
import gleeunit/should

pub fn send_request() {
  // Prepare a HTTP request record
  let assert Ok(request) =
    request.to("https://test-api.service.hmrc.gov.uk/hello/world")

  // Send the HTTP request to the server
  use resp <- result.try(httpc.send(req))

  // We get a response record back
  resp.status
  |> should.equal(200)

  resp
  |> response.get_header("content-type")
  |> should.equal(Ok("application/json"))

  resp.body
  |> should.equal("{\"message\":\"Hello World\"}")

  Ok(resp)
}
```

## Installation

```shell
gleam add gleam_httpc
```

## Use with Erlang/OTP versions older than 26.0

Older versions of HTTPC do not verify TLS connections by default, so with them
your connection may not be secure when using this library. Consider upgrading to
a newer version of Erlang/OTP, or using a different HTTP client such as
[hackney](https://github.com/gleam-lang/hackney).

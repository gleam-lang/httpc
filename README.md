# httpc

Bindings to Erlang's built in HTTP client, `httpc`.

[![Package Version](https://img.shields.io/hexpm/v/gleam_httpc)](https://hex.pm/packages/gleam_httpc)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/gleam_httpc/)

```sh
gleam add gleam_httpc@5
```

```gleam
import gleam/http/request
import gleam/http/response
import gleam/httpc
import gleam/result

pub fn send_request() {
  // Prepare a HTTP request record
  let assert Ok(base_req) =
    request.to("https://test-api.service.hmrc.gov.uk/hello/world")

  let req =
    request.prepend_header(base_req, "accept", "application/vnd.hmrc.1.0+json")

  // Send the HTTP request to the server
  use resp <- result.try(httpc.send(req))

  // We get a response record back
  assert resp.status == 200

  let content_type = response.get_header(resp, "content-type")
  assert content_type == Ok("application/json")

  assert resp.body == "{\"message\":\"Hello World\"}"

  Ok(resp)
}
```

## Http streaming requests

`httpc.gleam` supports the `ErlOption`, `Stream(#(Self, Once))`, for accepting streamed responses.
In this mode, after receiving the `stream_pid`, from the `StreamStart` message, the caller
must explicitly request the next stream message using the `receive_next_stream_message`.

```gleam
import gleam/erlang/process.{type Pid}
import gleam/http.{Get}
import gleam/http/request
import gleam/httpc.{type StreamMessage}
import gleam/otp/actor

pub fn main() {
  let selector =
    process.new_selector()
    |> httpc.select_stream_messages(httpc.raw_stream_mapper())
  
  let req =
    request.new()
    |> request.set_method(Get)
    |> request.set_host("postman-echo.com")
    // stream 1 chunk
    |> request.set_path("/stream/1")

  let assert Ok(streamer) =
     actor.new_with_initialiser(100, fn(_) {
         let assert Ok(_request_id) =
            httpc.dispatch_stream_request(httpc.configure(), req)

         Ok(
            actor.initialised(process.self())
            |> actor.selecting(selector)
         )
     })
     |> actor.on_message(handle_stream_message)
     |> actor.start

  // We unlink streamer actor with main, to avoid crashing main
  // in the case our streamer crashes. 
  process.unlink(streamer.pid)

  // Trigger the stream messages letting the streamer actor handle them.
  process.selector_receive(selector, 10)
}

 fn handle_stream_message(
   stream_pid: Pid,
   message: StreamMessage,
   ) -> actor.Next(Pid, StreamMessage) {
   case message {
      httpc.StreamStart(_request_id, _headers, stream_pid) -> {
         httpc.receive_next_stream_message(stream_pid)
         actor.continue(stream_pid)
      }
      httpc.StreamChunk(_request_id, _chunk) -> {
         // Process the chunk here (write to file, parse, etc.)
         httpc.receive_next_stream_message(stream_pid)
         actor.continue(stream_pid)
      }
      httpc.StreamEnd(_request_id, _headers) -> {
         actor.stop()
      }
      httpc.StreamError(_request_id, _error) -> {
         actor.stop_abnormal("Http error")
      }
  }
} 
```

## Use with Erlang/OTP versions older than 26.0

Older versions of HTTPC do not verify TLS connections by default, so with them
your connection may not be secure when using this library. Consider upgrading to
a newer version of Erlang/OTP, or using a different HTTP client such as
[hackney](https://github.com/gleam-lang/hackney).

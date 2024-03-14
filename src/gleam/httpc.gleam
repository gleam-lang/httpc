import gleam/bit_array
import gleam/dynamic.{type Dynamic}
import gleam/http.{type Method}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response, Response}
import gleam/list
import gleam/result
import gleam/uri

type Charlist

@external(erlang, "erlang", "binary_to_list")
fn binary_to_list(a: String) -> Charlist

@external(erlang, "erlang", "list_to_binary")
fn list_to_binary(a: Charlist) -> String

type ErlHttpOption {
  Ssl(List(ErlSslOption))
}

type BodyFormat {
  Binary
}

type ErlOption {
  BodyFormat(BodyFormat)
}

type ErlSslOption {
  Verify(ErlVerifyOption)
}

type ErlVerifyOption {
  VerifyNone
}

@external(erlang, "httpc", "request")
fn erl_request(
  a: Method,
  b: #(Charlist, List(#(Charlist, Charlist)), Charlist, BitArray),
  c: List(ErlHttpOption),
  d: List(ErlOption),
) -> Result(
  #(#(Charlist, Int, Charlist), List(#(Charlist, Charlist)), BitArray),
  Dynamic,
)

@external(erlang, "httpc", "request")
fn erl_request_no_body(
  a: Method,
  b: #(Charlist, List(#(Charlist, Charlist))),
  c: List(ErlHttpOption),
  d: List(ErlOption),
) -> Result(
  #(#(Charlist, Int, Charlist), List(#(Charlist, Charlist)), BitArray),
  Dynamic,
)

fn charlist_header(header: #(String, String)) -> #(Charlist, Charlist) {
  let #(k, v) = header
  #(binary_to_list(k), binary_to_list(v))
}

fn string_header(header: #(Charlist, Charlist)) -> #(String, String) {
  let #(k, v) = header
  #(list_to_binary(k), list_to_binary(v))
}

// TODO: document
// TODO: test
// TODO: refine error type
pub fn send_bits(req: Request(BitArray)) -> Result(Response(BitArray), Dynamic) {
  configure()
  |> dispatch_bits(req)
}

// TODO: document
// TODO: test
// TODO: refine error type
pub fn dispatch_bits(
  config: Configuration,
  req: Request(BitArray),
) -> Result(Response(BitArray), Dynamic) {
  let erl_url =
    req
    |> request.to_uri
    |> uri.to_string
    |> binary_to_list
  let erl_headers = list.map(req.headers, charlist_header)
  let erl_http_options = case config.verify_tls {
    True -> []
    False -> [Ssl([Verify(VerifyNone)])]
  }
  let erl_options = [BodyFormat(Binary)]

  use response <- result.then(case req.method {
    http.Options | http.Head | http.Get -> {
      let erl_req = #(erl_url, erl_headers)
      erl_request_no_body(req.method, erl_req, erl_http_options, erl_options)
    }
    _ -> {
      let erl_content_type =
        req
        |> request.get_header("content-type")
        |> result.unwrap("application/octet-stream")
        |> binary_to_list
      let erl_req = #(erl_url, erl_headers, erl_content_type, req.body)
      erl_request(req.method, erl_req, erl_http_options, erl_options)
    }
  })

  let #(#(_version, status, _status), headers, resp_body) = response
  Ok(Response(status, list.map(headers, string_header), resp_body))
}

// TODO:: document
pub opaque type Configuration {
  Builder(verify_tls: Bool)
}

// TODO:: document
pub fn configure() -> Configuration {
  Builder(verify_tls: True)
}

// TODO:: document
// TODO:: test True
// TODO:: test False
pub fn verify_tls(_config: Configuration, which: Bool) -> Configuration {
  Builder(verify_tls: which)
}

pub fn dispatch(
  config: Configuration,
  request: Request(String),
) -> Result(Response(String), Dynamic) {
  let request = request.map(request, bit_array.from_string)
  use resp <- result.try(dispatch_bits(config, request))

  case bit_array.to_string(resp.body) {
    Ok(body) -> Ok(response.set_body(resp, body))
    Error(_) -> Error(dynamic.from("Response body was not valid UTF-8"))
  }
}

// TODO: refine error type
pub fn send(req: Request(String)) -> Result(Response(String), Dynamic) {
  configure()
  |> dispatch(req)
}

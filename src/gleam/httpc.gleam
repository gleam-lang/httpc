import gleam/dynamic.{Dynamic}
import gleam/http.{Method, Request, Response}
import gleam/bit_string
import gleam/result
import gleam/list
import gleam/uri

external type Charlist

external fn binary_to_list(String) -> Charlist =
  "erlang" "binary_to_list"

external fn list_to_binary(Charlist) -> String =
  "erlang" "list_to_binary"

external type ErlHttpOption

type BodyFormat {
  Binary
}

type ErlOption {
  BodyFormat(BodyFormat)
}

external fn erl_request(
  Method,
  tuple(Charlist, List(tuple(Charlist, Charlist)), Charlist, BitString),
  List(ErlHttpOption),
  List(ErlOption),
) -> Result(
  tuple(
    tuple(Charlist, Int, Charlist),
    List(tuple(Charlist, Charlist)),
    BitString,
  ),
  Dynamic,
) =
  "httpc" "request"

external fn erl_request_no_body(
  Method,
  tuple(Charlist, List(tuple(Charlist, Charlist))),
  List(ErlHttpOption),
  List(ErlOption),
) -> Result(
  tuple(
    tuple(Charlist, Int, Charlist),
    List(tuple(Charlist, Charlist)),
    BitString,
  ),
  Dynamic,
) =
  "httpc" "request"

fn charlist_header(header: tuple(String, String)) -> tuple(Charlist, Charlist) {
  let tuple(k, v) = header
  tuple(binary_to_list(k), binary_to_list(v))
}

fn string_header(header: tuple(Charlist, Charlist)) -> tuple(String, String) {
  let tuple(k, v) = header
  tuple(list_to_binary(k), list_to_binary(v))
}

// TODO: test
// TODO: refine error type
pub fn send_bits(
  req: Request(BitString),
) -> Result(Response(BitString), Dynamic) {
  let erl_url =
    req
    |> http.req_to_uri
    |> uri.to_string
    |> binary_to_list
  let erl_headers = list.map(req.headers, charlist_header)
  let erl_http_options = []
  let erl_options = [BodyFormat(Binary)]

  try response = case req.method {
    http.Options | http.Head | http.Get -> {
      let erl_req = tuple(erl_url, erl_headers)
      erl_request_no_body(req.method, erl_req, erl_http_options, erl_options)
    }
    _ -> {
      let erl_content_type =
        req
        |> http.get_req_header("content-type")
        |> result.unwrap("application/octet-stream")
        |> binary_to_list
      let erl_req = tuple(erl_url, erl_headers, erl_content_type, req.body)
      erl_request(req.method, erl_req, erl_http_options, erl_options)
    }
  }

  let tuple(tuple(_version, status, _status), headers, resp_body) = response
  Ok(Response(status, list.map(headers, string_header), resp_body))
}

// TODO: test
// TODO: refine error type
pub fn send(req: Request(String)) -> Result(Response(String), Dynamic) {
  try resp =
    req
    |> http.map_req_body(bit_string.from_string)
    |> send_bits

  case bit_string.to_string(resp.body) {
    Ok(body) -> Ok(http.set_resp_body(resp, body))
    Error(_) -> Error(dynamic.from("Response body was not valid UTF-8"))
  }
}

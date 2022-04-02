import gleam/dynamic.{Dynamic}
import gleam/http.{Method}
import gleam/http/response.{Response}
import gleam/http/request.{Request}
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
  #(Charlist, List(#(Charlist, Charlist)), Charlist, BitString),
  List(ErlHttpOption),
  List(ErlOption),
) -> Result(
  #(#(Charlist, Int, Charlist), List(#(Charlist, Charlist)), BitString),
  Dynamic,
) =
  "httpc" "request"

external fn erl_request_no_body(
  Method,
  #(Charlist, List(#(Charlist, Charlist))),
  List(ErlHttpOption),
  List(ErlOption),
) -> Result(
  #(#(Charlist, Int, Charlist), List(#(Charlist, Charlist)), BitString),
  Dynamic,
) =
  "httpc" "request"

fn charlist_header(header: #(String, String)) -> #(Charlist, Charlist) {
  let #(k, v) = header
  #(binary_to_list(k), binary_to_list(v))
}

fn string_header(header: #(Charlist, Charlist)) -> #(String, String) {
  let #(k, v) = header
  #(list_to_binary(k), list_to_binary(v))
}

// TODO: test
// TODO: refine error type
pub fn send_bits(
  req: Request(BitString),
) -> Result(Response(BitString), Dynamic) {
  let erl_url =
    req
    |> request.to_uri
    |> uri.to_string
    |> binary_to_list
  let erl_headers = list.map(req.headers, charlist_header)
  let erl_http_options = []
  let erl_options = [BodyFormat(Binary)]

  try response = case req.method {
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
  }

  let #(#(_version, status, _status), headers, resp_body) = response
  Ok(Response(status, list.map(headers, string_header), resp_body))
}

// TODO: test
// TODO: refine error type
pub fn send(req: Request(String)) -> Result(Response(String), Dynamic) {
  try resp =
    req
    |> request.map(bit_string.from_string)
    |> send_bits

  case bit_string.to_string(resp.body) {
    Ok(body) -> Ok(response.set_body(resp, body))
    Error(_) -> Error(dynamic.from("Response body was not valid UTF-8"))
  }
}

import gleam/dynamic.{Dynamic}
import gleam/http.{Method}
import gleam/list

external type Charlist;

external fn binary_to_list(String) -> Charlist
  = "erlang" "binary_to_list"

external fn list_to_binary(Charlist) -> String
  = "erlang" "list_to_binary"

external type ErlHttpOption;

type BodyFormat {
  Binary
};

type ErlOption {
  BodyFormat(BodyFormat)
};

external fn erl_request(
  Method,
  tuple(Charlist, List(tuple(Charlist, Charlist)), Charlist, String),
  List(ErlHttpOption),
  List(ErlOption),
) -> Result(
  tuple(
    tuple(Charlist, Int, Charlist),
    List(tuple(Charlist, Charlist)),
    String,
  ),
  Dynamic,
)
  = "httpc" "request"

external fn erl_request_no_body(
  Method,
  tuple(Charlist, List(tuple(Charlist, Charlist))),
  List(ErlHttpOption),
  List(ErlOption),
) -> Result(
  tuple(
    tuple(Charlist, Int, Charlist),
    List(tuple(Charlist, Charlist)),
    String,
  ),
  Dynamic,
)
  = "httpc" "request"

pub type RequestBody {
  Text(
    content_type: String,
    body: String,
  )

  None
}

pub type Response {
  Response(
    status: Int,
    headers: List(tuple(String, String)),
    body: String,
  )
}

fn charlist_header(header: tuple(String, String))
  -> tuple(Charlist, Charlist)
{
  let tuple(k, v) = header
  tuple(binary_to_list(k), binary_to_list(v))
}

fn string_header(header: tuple(Charlist, Charlist))
  -> tuple(String, String)
{
  let tuple(k, v) = header
  tuple(list_to_binary(k), list_to_binary(v))
}

// TODO: refine error type
pub fn request(
  method method: Method,
  url url: String,
  headers headers: List(tuple(String, String)),
  body body: RequestBody,
) -> Result(Response, Dynamic) {
  let erl_url = binary_to_list(url)
  let erl_headers = list.map(headers, charlist_header)
  let erl_http_options = []
  let erl_options = [BodyFormat(Binary)]

  let response = case body {
    Text(content_type: content_type, body: body) -> {
      let erl_content_type = binary_to_list(content_type)
      let request = tuple(erl_url, erl_headers, erl_content_type, body)
      erl_request(method, request, erl_http_options, erl_options)
    }

    None -> {
      let request = tuple(erl_url, erl_headers)
      erl_request_no_body(method, request, erl_http_options, erl_options)
    }
  }

  case response {
    Error(error) ->
      Error(error)

    Ok(tuple(tuple(_http_version, status, _status), headers, resp_body)) ->
      Ok(Response(status, list.map(headers, string_header), resp_body))
  }
}

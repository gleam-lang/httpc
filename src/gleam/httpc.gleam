import gleam/bit_array

import gleam/dynamic.{type Dynamic}
import gleam/erlang/atom
import gleam/erlang/charlist.{type Charlist}
import gleam/erlang/process
import gleam/http.{type Method}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response, Response}
import gleam/list
import gleam/result
import gleam/uri

pub type HttpError {
  /// The response body contained non-UTF-8 data, but UTF-8 data was expected.
  InvalidUtf8Response
  /// It was not possible to connect to the host.
  FailedToConnect(ip4: ConnectError, ip6: ConnectError)
  /// The response was not received within the configured timeout period.
  ResponseTimeout
  /// The connection was closed mid-response
  SocketClosedRemotely
}

pub type ConnectError {
  Posix(code: String)
  TlsAlert(code: String, detail: String)
}

@external(erlang, "gleam_httpc_ffi", "default_user_agent")
fn default_user_agent() -> #(Charlist, Charlist)

@external(erlang, "gleam_httpc_ffi", "normalise_error")
fn normalise_error(error: Dynamic) -> HttpError

type ErlHttpOption {
  Ssl(List(ErlSslOption))
  Autoredirect(Bool)
  Timeout(Int)
}

type BodyFormat {
  Binary
}

type Destination {
  Self
}

type Mode {
  Once
}

type ErlOption {
  BodyFormat(BodyFormat)
  SocketOpts(List(SocketOpt))
  Sync(Bool)
  Stream(#(Destination, Mode))
}

type SocketOpt {
  Ipfamily(Inet6fb4)
}

type Inet6fb4 {
  Inet6fb4
}

type ErlSslOption {
  Verify(ErlVerifyOption)
}

type ErlVerifyOption {
  VerifyNone
}

/// Identifies a particular HTTP request used to match with incoming
/// `RawStreamMessage`s. This identifier is useful when managing multiple
/// concurrent streaming requests.
pub type RequestIdentifier

/// When streaming, this raw form preserves the `Charlist` headers references
/// exactly as they arrive, so selectors can match on them without extra
/// allocations. If desired, use `raw_stream_mapper` with
/// `select_stream_messages` to turn these `Charlist` headers into
/// `String` headers.
/// 
pub type RawStreamMessage {
  /// Sent exactly once when the server response begins. This message has an
  /// extra element `pid`. This is the process id that is used an argument to
  /// `receive_next_stream_message(pid)`
  RawStreamStart(RequestIdentifier, List(#(Charlist, Charlist)), process.Pid)
  /// Sent for every chunk of response data that the worker emits. Each chunk
  /// must be explicitly requested by calling `receive_next_stream_message`
  /// with the process id supplied from the `StreamStart` message.
  RawStreamChunk(RequestIdentifier, BitArray)
  /// Sent exactly once after the final chunk has been consumed. Chunked
  /// transfer encoding may add trailers, so there can be more headers here than
  /// were present in the initial `StreamStart`.
  RawStreamEnd(RequestIdentifier, List(#(Charlist, Charlist)))
  /// Sent whenever the stream cannot be completed, either because the request
  /// failed or an error occurred while consuming chunks.
  RawStreamError(RequestIdentifier, HttpError)
}

/// A convenience function that converts a `RawStreamMessage` into a 
/// `StreamMessage`. Use this when you want to transform header values from
/// `List(#(Charlist, Charlist))` into the more Gleam idiomatic
/// `List(#(String, String))`.
///
pub fn raw_stream_mapper() -> fn(RawStreamMessage) -> StreamMessage {
  fn(msg: RawStreamMessage) {
    case msg {
      RawStreamChunk(request_id, bin_part) -> StreamChunk(request_id, bin_part)
      RawStreamStart(request_id, headers, pid) ->
        StreamStart(request_id, list.map(headers, string_header), pid)
      RawStreamEnd(request_id, headers) ->
        StreamEnd(request_id, list.map(headers, string_header))
      RawStreamError(request_id, reason) -> StreamError(request_id, reason)
    }
  }
}

/// Messages delivered to the caller when `dispatch_stream_bits` is executed
/// (i.e., streaming mode), so that you can pull the response body as it
/// becomes available.
/// 
pub type StreamMessage {
  /// Sent exactly once when the server response begins. This message has an
  /// extra element `pid`. This is the process id that is used an argument to
  /// `receive_next_stream_message(pid)`
  /// 
  StreamStart(
    request_id: RequestIdentifier,
    headers: List(#(String, String)),
    stream_pid: process.Pid,
  )
  /// Sent for every chunk of response data that the worker emits. Each chunk
  /// must be explicitly requested by calling `receive_next_stream_message`
  /// with the process id, `stream_pid` supplied from the `StreamStart` message.
  StreamChunk(request_id: RequestIdentifier, chunk: BitArray)
  /// Sent exactly once after the final chunk has been consumed. Chunked
  /// transfer encoding may add trailers, so there can be more headers here than
  /// were present in the initial `StreamStart`.
  StreamEnd(request_id: RequestIdentifier, trailers: List(#(String, String)))
  /// Sent whenever the stream cannot be completed, either because the request
  /// failed or an error occurred while consuming chunks.
  StreamError(request_id: RequestIdentifier, error: HttpError)
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

@external(erlang, "httpc", "request")
fn erl_stream_request_no_body(
  a: Method,
  b: #(Charlist, List(#(Charlist, Charlist))),
  c: List(ErlHttpOption),
  d: List(ErlOption),
) -> Result(RequestIdentifier, Dynamic)

@external(erlang, "httpc", "request")
fn erl_stream_request(
  a: Method,
  b: #(Charlist, List(#(Charlist, Charlist)), Charlist, BitArray),
  c: List(ErlHttpOption),
  d: List(ErlOption),
) -> Result(RequestIdentifier, Dynamic)

fn string_header(header: #(Charlist, Charlist)) -> #(String, String) {
  let #(k, v) = header
  #(charlist.to_string(k), charlist.to_string(v))
}

// TODO: refine error type
/// Send a HTTP request of binary data using the default configuration.
///
/// If you wish to use some other configuration use `dispatch_bits` instead.
///
pub fn send_bits(
  req: Request(BitArray),
) -> Result(Response(BitArray), HttpError) {
  configure()
  |> dispatch_bits(req)
}

/// Send a HTTP stream request of binary data.
/// 
/// Returns a `RequestIdentifier` that can be matched with incoming
/// `StreamMessage`s.
/// 
pub fn dispatch_stream_bits(
  config: Configuration,
  req: Request(BitArray),
) -> Result(RequestIdentifier, HttpError) {
  let erl_url =
    req
    |> request.to_uri
    |> uri.to_string
    |> charlist.from_string
  let erl_headers = prepare_headers(req.headers)
  let erl_http_options = [
    Autoredirect(config.follow_redirects),
    Timeout(config.timeout),
  ]
  let erl_http_options = case config.verify_tls {
    True -> erl_http_options
    False -> [Ssl([Verify(VerifyNone)]), ..erl_http_options]
  }
  let erl_options = [
    BodyFormat(Binary),
    SocketOpts([Ipfamily(Inet6fb4)]),
    Sync(False),
    Stream(#(Self, Once)),
  ]
  use request_id <- result.try(
    case req.method {
      http.Options | http.Head | http.Get -> {
        let erl_req = #(erl_url, erl_headers)
        erl_stream_request_no_body(
          req.method,
          erl_req,
          erl_http_options,
          erl_options,
        )
      }
      _ -> {
        let erl_content_type =
          req
          |> request.get_header("content-type")
          |> result.unwrap("application/octet-stream")
          |> charlist.from_string
        let erl_req = #(erl_url, erl_headers, erl_content_type, req.body)
        erl_stream_request(req.method, erl_req, erl_http_options, erl_options)
      }
    }
    |> result.map_error(normalise_error),
  )

  Ok(request_id)
}

/// Triggers the next streaming message to be sent to the calling process.
/// Use the `stream_pid` argument returned by the `StreamStart` message. 
/// 
@external(erlang, "gleam_httpc_ffi", "receive_next_stream_message")
pub fn receive_next_stream_message(stream_pid: process.Pid) -> Nil

@external(erlang, "gleam_httpc_ffi", "coerce_stream_message")
fn unsafe_decode(message: Dynamic) -> RawStreamMessage

/// Configure the selector that receives stream messages
/// 
/// Note this will receive messages from all processes that sent a HTTP stream
/// request; for example using `send_stream_request`, rather than any specific
/// one. In this case, for finer grained processing, you can filter on the
/// `RequestIdentifier`, which is the first argument in the `RawStreamMessage`
/// constructor. If you wish to only handle stream messages from one process,
/// then use one process per HTTP stream request. 
/// 
pub fn select_stream_messages(
  selector: process.Selector(t),
  mapper: fn(RawStreamMessage) -> t,
) -> process.Selector(t) {
  let http = atom.create(http.scheme_to_string(http.Http))

  selector
  |> process.select_record(http, 1, map_stream_message(mapper))
}

fn map_stream_message(mapper: fn(RawStreamMessage) -> t) -> fn(Dynamic) -> t {
  fn(message) { mapper(unsafe_decode(message)) }
}

// TODO: refine error type
/// Send a HTTP request of binary data.
///
pub fn dispatch_bits(
  config: Configuration,
  req: Request(BitArray),
) -> Result(Response(BitArray), HttpError) {
  let erl_url =
    req
    |> request.to_uri
    |> uri.to_string
    |> charlist.from_string
  let erl_headers = prepare_headers(req.headers)
  let erl_http_options = [
    Autoredirect(config.follow_redirects),
    Timeout(config.timeout),
  ]
  let erl_http_options = case config.verify_tls {
    True -> erl_http_options
    False -> [Ssl([Verify(VerifyNone)]), ..erl_http_options]
  }
  let erl_options = [BodyFormat(Binary), SocketOpts([Ipfamily(Inet6fb4)])]

  use response <- result.try(
    case req.method {
      http.Options | http.Head | http.Get -> {
        let erl_req = #(erl_url, erl_headers)
        erl_request_no_body(req.method, erl_req, erl_http_options, erl_options)
      }
      _ -> {
        let erl_content_type =
          req
          |> request.get_header("content-type")
          |> result.unwrap("application/octet-stream")
          |> charlist.from_string
        let erl_req = #(erl_url, erl_headers, erl_content_type, req.body)
        erl_request(req.method, erl_req, erl_http_options, erl_options)
      }
    }
    |> result.map_error(normalise_error),
  )

  let #(#(_version, status, _status), headers, resp_body) = response

  Ok(Response(status, list.map(headers, string_header), resp_body))
}

/// Configuration that can be used to send HTTP requests.
///
/// To be used with `dispatch` and `dispatch_bits`.
///
pub opaque type Configuration {
  Builder(
    /// Whether to verify the TLS certificate of the server.
    ///
    /// This defaults to `True`, meaning that the TLS certificate will be
    /// verified unless you call this function with `False`.
    ///
    /// Setting this to `False` can make your application vulnerable to
    /// man-in-the-middle attacks and other security risks. Do not do this
    /// unless you are sure and you understand the risks.
    ///
    verify_tls: Bool,
    /// Whether to follow redirects.
    ///
    follow_redirects: Bool,
    /// Timeout for the request in milliseconds.
    ///
    timeout: Int,
  )
}

/// Create a new configuration with the default settings.
///
/// # Defaults
///
/// - TLS is verified.
/// - Redirects are not followed.
/// - The timeout for the response to be received is 30 seconds from when the
///   request is sent.
///
pub fn configure() -> Configuration {
  Builder(verify_tls: True, follow_redirects: False, timeout: 30_000)
}

/// Set whether to verify the TLS certificate of the server.
///
/// This defaults to `True`, meaning that the TLS certificate will be verified
/// unless you call this function with `False`.
///
/// Setting this to `False` can make your application vulnerable to
/// man-in-the-middle attacks and other security risks. Do not do this unless
/// you are sure and you understand the risks.
///
pub fn verify_tls(config: Configuration, which: Bool) -> Configuration {
  Builder(..config, verify_tls: which)
}

/// Set whether redirects should be followed automatically.
pub fn follow_redirects(config: Configuration, which: Bool) -> Configuration {
  Builder(..config, follow_redirects: which)
}

/// Set the timeout in milliseconds, the default being 30 seconds.
///
/// If the response is not recieved within this amount of time then the
/// client disconnects and an error is returned.
///
pub fn timeout(config: Configuration, timeout: Int) -> Configuration {
  Builder(..config, timeout:)
}

/// Send a HTTP request of unicode data.
///
pub fn dispatch(
  config: Configuration,
  request: Request(String),
) -> Result(Response(String), HttpError) {
  let request = request.map(request, bit_array.from_string)
  use resp <- result.try(dispatch_bits(config, request))

  case bit_array.to_string(resp.body) {
    Ok(body) -> Ok(response.set_body(resp, body))
    Error(_) -> Error(InvalidUtf8Response)
  }
}

/// Send a HTTP stream request of unicode data using `Configuration`.
/// 
/// `httpc.gleam` supports the `ErlOption`, `Stream(#(Self, Once))`, for
/// accepting streamed responses. In this mode, the caller must explicitly
/// request the next stream message using `receive_next_stream_message`.
///
/// If the request is successfully dispatched, this function returns a
/// `RequestIdentifier`. This identifier is useful when managing multiple
/// concurrent streaming requests, allowing you to match incoming messages to
/// the originating request.
///
/// Once you've configured a selector to receive stream messages (see
/// `select_stream_messages`), the other stream message variants will be
/// delivered to the caller.
/// 
/// Streaming errors are delivered in raw form via:
/// `RawStreamError(RequestIdentifier, HttpError)` or
/// `StreamError(RequestIdentifier, HttpError)`, assuming your using
/// `raw_stream_mapper` to configure your message selector as shown in the
/// example below.
///
/// Example:
/// 
/// ```gleam
/// import gleam/http.{Get}
/// import gleam/http/request
/// import gleam/httpc
/// import gleam/process
/// 
/// // Receive a streamed response. The number of stream chunks we
/// // receive is 1, as specfied in the endpoint
/// pub fn stream_self_once() {
///    let req =
///      request.new()
///      |> request.set_method(Get)
///      |> request.set_host("postman-echo.com")
///      |> request.set_path("/stream/1")
///  
///    let config =
///       httpc.configure()
///       |> httpc.timeout(5000)
/// 
///    // Send the streaming request to the server
///    let assert Ok(_request_id) =
///       httpc.dispatch_stream_request(config, req)
/// 
///    // Configure the selector
///    let selector =
///      process.new_selector()
///      |> httpc.select_stream_messages(httpc.raw_stream_mapper())
/// 
///    let assert Ok(httpc.StreamStart(_request_id, _headers, stream_pid)) =
///       process.selector_receive(selector, 5000)
///    httpc.receive_next_stream_message(stream_pid)
///    let assert Ok(httpc.StreamChunk(_request_id, _binary_part)) =
///       process.selector_receive(selector, 5000)
///    httpc.receive_next_stream_message(stream_pid)
///    let assert Ok(httpc.StreamEnd(_request_id, _headers)) =
///       process.selector_receive(selector, 5000)
/// }
/// ```
/// 
pub fn dispatch_stream_request(
  config: Configuration,
  request: Request(String),
) -> Result(RequestIdentifier, HttpError) {
  let request = request.map(request, bit_array.from_string)
  use request_id <- result.try(dispatch_stream_bits(config, request))
  Ok(request_id)
}

/// Send a HTTP request of unicode data using the default configuration.
///
/// If you wish to use some other configuration use `dispatch` instead.
///
pub fn send(req: Request(String)) -> Result(Response(String), HttpError) {
  configure()
  |> dispatch(req)
}

fn prepare_headers(
  headers: List(#(String, String)),
) -> List(#(Charlist, Charlist)) {
  prepare_headers_loop(headers, [], False)
}

fn prepare_headers_loop(
  in: List(#(String, String)),
  out: List(#(Charlist, Charlist)),
  user_agent_set: Bool,
) -> List(#(Charlist, Charlist)) {
  case in {
    [] if user_agent_set -> out
    [] -> [default_user_agent(), ..out]
    [#(k, v), ..in] -> {
      let user_agent_set = user_agent_set || k == "user-agent"
      let out = [#(charlist.from_string(k), charlist.from_string(v)), ..out]
      prepare_headers_loop(in, out, user_agent_set)
    }
  }
}

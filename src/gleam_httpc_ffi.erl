-module(gleam_httpc_ffi).
-export([default_user_agent/0, normalise_error/1]).

normalise_error({failed_connect, Opts}) ->
    Ipv6 = case lists:keyfind(inet6, 1, Opts) of
        {inet6, _, V1} ->{some, normalise_ip_error(V1)};
        _ -> none
    end,
    Ipv4 = case lists:keyfind(inet, 1, Opts) of
        {inet, _, V2} -> {some, normalise_ip_error(V2)};
        _ -> none
    end,
    {failed_to_connect, Ipv4, Ipv6};
normalise_error(timeout) -> 
    response_timeout;
normalise_error(Error) ->
    erlang:error({unexpected_httpc_error, Error}).

normalise_ip_error(Code) when is_atom(Code) ->
    {posix, erlang:atom_to_binary(Code)};
normalise_ip_error({tls_alert, {A, B}}) ->
    {tls_alert, erlang:atom_to_binary(A), unicode:characters_to_binary(B)};
normalise_ip_error(Error) ->
    erlang:error({unexpected_httpc_ip_error, Error}).

default_user_agent() ->
    Version =
        case application:get_key(gleam_httpc, vsn) of
            {ok, V} when is_list(V) -> V;
            undefined -> "0.0.0"
        end,
    {"user-agent", "gleam_httpc/" ++ Version}.

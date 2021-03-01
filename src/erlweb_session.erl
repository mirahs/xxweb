%% -*- coding: latin-1 -*-
-module(erlweb_session).

-export([
    execute/2
    ,on_response/1
]).

-export([
    get/1,
    get/2,
    set/1,
    set/2,
    del/1,
    destory/1
]).

-include("erlweb.hrl").

-define(SESSION_KEYS,			session_keys).
-define(SESSION_COOKIE,			<<"session_cookie">>).
-define(SESSION_COOKIE_ATOM,	session_cookie).


execute(Req, Env = #{handler_opts := #{session_apps := SessionApps}}) ->
    AppBTmp = cowboy_req:binding(app, Req),
    AppB    = ?IF(AppBTmp =:= undefined, <<"index">>, AppBTmp),
    case lists:member(AppB, SessionApps) of
        true ->
            ?INFO("on request"),
            case cowboy_req:match_cookies([{?SESSION_COOKIE_ATOM, [], <<>>}], Req) of
                #{session_cookie := SessionId} when SessionId =/= <<"">> ->
                    SessionData	= erlweb_session_srv:session_get(SessionId),
                    ?INFO("SessionId:~p", [SessionId]),
                    ?INFO("SessionData:~p", [SessionData]),
                    [erlang:put(Key, Value) || {Key, Value} <- SessionData],
                    erlang:put(?SESSION_KEYS, [Key || {Key, _Data} <- SessionData]),
                    {ok, Req, Env};
                _ ->
                    SessionId = session_id(Req),
                    ?INFO("SessionId:~p", [SessionId]),
                    erlang:put(?SESSION_KEYS, []),
                    Req2 = cowboy_req:set_resp_cookie(?SESSION_COOKIE, SessionId, Req, #{path => <<"/">>}),
                    {ok, Req2, Env}
            end;
        false -> {ok, Req, Env}
    end.

%% 返回前调用
on_response(Req) ->?INFO("on response"),
    case erlang:get(?SESSION_KEYS) of
        undefined -> ?INFO("on response"),skip;
        _Keys ->?INFO("on response _Keys:~p", [_Keys]),
            case cowboy_req:match_cookies([{?SESSION_COOKIE_ATOM, [], <<>>}], Req) of
                #{session_cookie := SessionId} when SessionId =/= <<"">> ->?INFO("on response SessionId:~p", [SessionId]),session_set(SessionId);
                _XX -> ?INFO("on response _XX:~p", [_XX]),skip
            end
    end,
    Req.


%% API
get(Key) ->
    ?MODULE:get(Key, undefined).

get(Key, DefaultValue) ->
    case erlang:get(Key) of
        undefined ->
            DefaultValue;
        Value ->
            Value
    end.

set(Key, Value) ->
    erlang:put(Key, Value),
    Keys = erlang:get(?SESSION_KEYS),
    erlang:put(?SESSION_KEYS, [Key|lists:delete(Key, Keys)]).

set(KeyValues) ->
    [set(Key, Value) || {Key, Value} <- KeyValues].

del() ->
    Keys= erlang:get(?SESSION_KEYS),
    [del(Key) || Key <- Keys].

del(Key) ->
    erlang:erase(Key),
    Keys= erlang:get(?SESSION_KEYS),
    erlang:put(?SESSION_KEYS, lists:delete(Key, Keys)).

destory(Req) ->
    SessionId = session_id(Req, false),
    del(),
    erlweb_session_srv:session_destory(SessionId),
    cowboy_req:set_resp_cookie(?SESSION_COOKIE, <<"">>, Req, #{path => <<"/">>}).



session_id(Req) ->
    session_id(Req, true).

session_id(Req, true) ->
    case cowboy_req:match_cookies([{?SESSION_COOKIE_ATOM, [], <<>>}], Req) of
        #{session_cookie:=SessionId} when SessionId =/= <<"">> ->
            ?TOB(SessionId);
        _ ->
            ?TOB(erlweb_session_srv:session_new())
    end;
session_id(Req, false) ->
    case cowboy_req:match_cookies([{?SESSION_COOKIE_ATOM, [], <<>>}], Req) of
        #{session_cookie:=SessionId} when SessionId =/= <<"">> ->
            ?TOB(SessionId);
        _ ->
            <<"0">>
    end.


session_set(SessionId) ->
    SessionKeys	= erlang:get(?SESSION_KEYS),
    SessionData	= [{Key, erlang:get(Key)} || Key <- SessionKeys],?INFO("SessionData:~p", [SessionData]),
    erlweb_session_srv:session_set(SessionId, SessionData).

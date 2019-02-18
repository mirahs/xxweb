-module(hello).

-export([
	start/0
	,stop/0
]).


start() ->
	{ok, _} = application:ensure_all_started(hello),
	ok.

stop() ->
    application:stop(hello).

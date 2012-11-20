% http://www.erlang.org/doc/getting_started/conc_prog.html

-module(tut17).

-export([start_ping/1, start_pong/0,  ping/2, pong/0]).

ts() ->
    TS = {_,_,Micro} = os:timestamp(),
    {{_,_,_},{_,Minute,Second}} =
        calendar:now_to_universal_time(TS),
    io_lib:format("~2..0w:~2..0w.~6..0w",
                  [Minute,Second,Micro]).

ping(0, Pong_Node) ->
    {pong, Pong_Node} ! finished,
    io:format("~s, ping finished~n", [ts()]);

ping(N, Pong_Node) ->
    {pong, Pong_Node} ! {ping1, self()},
    {pong, Pong_Node} ! {ping2, self()},
    wait_pong(N, Pong_Node).

wait_pong(N, Pong_Node) ->
    receive
        pong1 ->
            io:format("~s, Ping received pong~n", [ts()]),
            wait_pong(N, Pong_Node);
        pong2 ->
            io:format("~s, Ping received pong~n", [ts()])
    end,
    ping(N - 1, Pong_Node).

pong() ->
    receive
        finished ->
            io:format("~s, Pong finished~n", [ts()]);
        {ping1, Ping_PID} ->
            io:format("~s, Pong received ping~n", [ts()]),
            Ping_PID ! pong1,
            pong();
        {ping2, Ping_PID} ->
            io:format("~s, Pong received ping~n", [ts()]),
            Ping_PID ! pong2,
            pong()
    end.

start_pong() ->
    register(pong, spawn(tut17, pong, [])).

start_ping(Pong_Node) ->
    spawn(tut17, ping, [3, Pong_Node]).

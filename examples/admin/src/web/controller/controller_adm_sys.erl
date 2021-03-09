%% -*- coding: latin-1 -*-
-module(controller_adm_sys).

-compile(nowarn_export_all).
-compile(export_all).

-include("common.hrl").
-include("web.hrl").
-include("web_adm.hrl").


%% 密码更新
password(?web_get, Req, _Opts) ->
    Data    = cowboy_req:parse_qs(Req),
    Account0= proplists:get_value(<<"account">>, Data),
    Account = ?IF(Account0 =:= undefined, web_adm:get_account(), Account0),
    {dtl, [{account, Account}]};
password(?web_post, Req, _Opts) ->
    {ok, Data, _Req2} = cowboy_req:read_urlencoded_body(Req),
    Account = proplists:get_value(<<"account">>, Data, <<>>),
    Password= proplists:get_value(<<"password">>, Data, <<>>),
    ?IF(Account =:= <<>> orelse Password =:= <<>>, ?web_failed("请输入正确的数据"), skip),
    tbl_adm_user:update_by_account(Account, [{password, util:md5(util:md5(Password))}]),
    web:echo_success().

%% 添加管理员
master_new(?web_get, Req, _Opts) ->
    Data= cowboy_req:parse_qs(Req),
    Id  = proplists:get_value(<<"id">>, Data, <<>>),
    ?IF(Id =:= <<>>, skip, begin {ok, AdmUser} = tbl_adm_user:get(Id), erlweb_tpl:assign(data, AdmUser) end),

    Type= web_adm:get_type(),
    UserTypes = [{UT, UD} || {UT, UD} <- maps:to_list(?adm_user_types_desc),  UT >= Type],
    {dtl, [{user_types, UserTypes}]};
master_new(?web_post, Req, _Opts) ->
    {ok, Data, _Req2} = cowboy_req:read_urlencoded_body(Req),
    Id      = proplists:get_value(<<"id">>, Data, <<>>),
    Account = proplists:get_value(<<"account">>, Data, <<>>),
    Type    = proplists:get_value(<<"type">>, Data, <<>>),
    Note    = proplists:get_value(<<"note">>, Data, <<>>),
    ?IF(Account =:= <<>> orelse Type =:= <<>> orelse Note =:= <<>>, ?web_failed("请输入正确的数据"), skip),
    Bind = [{account, Account}, {type, Type}, {note, Note}],
    case Id of
        <<>> ->
            Password = util:md5(util:md5("123456")),
            Bind2 = [{password, Password} | Bind],
            tbl_adm_user:add(Bind2);
        _ -> tbl_adm_user:update(Id, Bind)
    end,
    web:echo_success().

%% 管理员列表
master_list(?web_get, Req, _Opts) ->
    Data= cowboy_req:parse_qs(Req),
    Id  = util:to_integer(proplists:get_value(<<"id">>, Data)),
    case proplists:get_value(<<"act">>, Data) of
        <<"del">> ->
            case web_adm:get_id() of
                Id -> {error, "不能删除自己"};
                _ ->
                    tbl_adm_user:delete(Id),
                    {error, "删除成功"}
            end;
        <<"lock">> ->
            case web_adm:get_id() of
                Id -> {error, "不能操作自己"};
                _ ->
                    Lock0   = proplists:get_value(<<"lock">>, Data),
                    Lock    = ?IF(Lock0 =:= <<"1">>, 0, 1),?DEBUG("dsf:~p", [{Lock0, Lock}]),
                    tbl_adm_user:update(Id, [{lock, Lock}]),
                    ?web_redirect
            end;
        _ ->
            #{page := Page, datas := Datas0} = web_page:page(Req, adm_user),
            Fun = fun
                      (#{type := TypeF, lock := LockF} = DataF, DatasAcc) ->
                          TypeDesc = maps:get(TypeF, ?adm_user_types_desc),
                          LockDesc = ?IF(LockF =:= 0, "锁定", "解锁"),
                          [DataF#{type_desc => TypeDesc, lock_desc => LockDesc} | DatasAcc]
                  end,
            Datas = lists:reverse(lists:foldl(Fun, [], Datas0)),
            {dtl, [{page, Page}, {datas, Datas}]}
    end.

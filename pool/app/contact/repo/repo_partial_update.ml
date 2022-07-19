module Dynparam = Utils.Database.Dynparam

let update_sihl_user pool ?firstname ?lastname contact =
  let ctx = Pool_tenant.to_ctx pool in
  let open CCOption in
  let given_name = firstname <+> contact.Entity.user.Sihl_user.given_name in
  let name = lastname <+> contact.Entity.user.Sihl_user.name in
  Service.User.update ~ctx ?given_name ?name contact.Entity.user
;;

let update_sql column_fragment =
  let base = {sql| UPDATE pool_contacts SET |sql} in
  let where_fragment =
    {sql| WHERE user_uuid = UNHEX(REPLACE($1, '-', '')) |sql}
  in
  Format.asprintf "%s %s %s" base column_fragment where_fragment
;;

let partial_update pool (field : Entity.Field.t) contact =
  let open Entity in
  let base_caqti = Pool_common.Repo.Id.t in
  let dyn = Dynparam.empty |> Dynparam.add base_caqti (contact |> id) in
  let%lwt dyn, sql =
    let open Field in
    let htmx_field, version = field in
    match htmx_field with
    | Firstname value ->
      let%lwt (_ : Entity.Sihl_user.t) =
        update_sihl_user
          pool
          ~firstname:(value |> Pool_user.Firstname.value)
          contact
      in
      Lwt.return
        ( dyn
          |> Dynparam.add
               Pool_common.Repo.Version.t
               Pool_common.Version.(version |> increment |> value)
        , {sql|
          firstname_version = $2
        |sql} )
    | Lastname value ->
      let%lwt (_ : Entity.Sihl_user.t) =
        update_sihl_user
          pool
          ~lastname:(value |> Pool_user.Lastname.value)
          contact
      in
      Lwt.return
        ( dyn
          |> Dynparam.add
               Pool_common.Repo.Version.t
               Pool_common.Version.(version |> increment |> value)
        , {sql|
            lastname_version = $2
          |sql} )
    | Paused value ->
      Lwt.return
        ( dyn
          |> Dynparam.add Caqti_type.bool (value |> Pool_user.Paused.value)
          |> Dynparam.add
               Pool_common.Repo.Version.t
               Pool_common.Version.(version |> increment |> value)
        , {sql|
              paused = $2,
              paused_version = $3
            |sql}
        )
    | Language value ->
      Lwt.return
        ( dyn
          |> Dynparam.add Caqti_type.(option Pool_common.Repo.Language.t) value
          |> Dynparam.add
               Pool_common.Repo.Version.t
               Pool_common.Version.(version |> increment |> value)
        , {sql|
                language = $2,
                language_version = $3
              |sql}
        )
    | Custom _ -> failwith "Todo"
  in
  let open Caqti_request.Infix in
  let (Dynparam.Pack (pt, pv)) = dyn in
  let update_request = sql |> update_sql |> pt ->. Caqti_type.unit in
  Utils.Database.exec (pool |> Pool_database.Label.value) update_request pv
;;
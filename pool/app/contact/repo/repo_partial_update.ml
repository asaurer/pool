module Dynparam = Utils.Database.Dynparam

let update_sihl_user pool ?firstname ?lastname contact =
  let open CCOption in
  let ctx = Pool_tenant.to_ctx pool in
  let given_name = firstname <+> contact.Entity.user.Sihl_user.given_name in
  let name = lastname <+> contact.Entity.user.Sihl_user.name in
  Service.User.update ~ctx ?given_name ?name contact.Entity.user
;;

let update_sql column_fragment =
  let base = {sql| UPDATE pool_contacts SET profile_updated_at = $2, |sql} in
  let where_fragment =
    {sql| WHERE user_uuid = UNHEX(REPLACE($1, '-', '')) |sql}
  in
  Format.asprintf "%s %s %s" base column_fragment where_fragment
;;

let partial_update pool (field : Entity.PartialUpdate.t) contact =
  let open Entity in
  let base_caqti = Pool_common.Repo.Id.t in
  let dyn =
    Dynparam.empty
    |> Dynparam.add base_caqti (contact |> id)
    |> Dynparam.add Caqti_type.ptime (Ptime_clock.now ())
  in
  let update_user_table (dyn, sql) =
    let open Caqti_request.Infix in
    let (Dynparam.Pack (pt, pv)) = dyn in
    let update_request = sql |> update_sql |> pt ->. Caqti_type.unit in
    Utils.Database.exec (pool |> Pool_database.Label.value) update_request pv
  in
  let open PartialUpdate in
  match field with
  | Firstname (version, value) ->
    let%lwt (_ : Sihl_user.t) =
      update_sihl_user
        pool
        ~firstname:(value |> Pool_user.Firstname.value)
        contact
    in
    ( dyn |> Dynparam.add Pool_common.Repo.Version.t version
    , {sql|
          firstname_version = $3
        |sql} )
    |> update_user_table
  | Lastname (version, value) ->
    let%lwt (_ : Sihl_user.t) =
      update_sihl_user
        pool
        ~lastname:(value |> Pool_user.Lastname.value)
        contact
    in
    ( dyn |> Dynparam.add Pool_common.Repo.Version.t version
    , {sql|
            lastname_version = $3
          |sql} )
    |> update_user_table
  | Paused (version, value) ->
    ( dyn
      |> Dynparam.add Caqti_type.bool (value |> Pool_user.Paused.value)
      |> Dynparam.add Pool_common.Repo.Version.t version
    , {sql|
              paused = $3,
              paused_version = $4
            |sql}
    )
    |> update_user_table
  | Language (version, value) ->
    ( dyn
      |> Dynparam.add Caqti_type.(option Pool_common.Repo.Language.t) value
      |> Dynparam.add Pool_common.Repo.Version.t version
    , {sql|
                language = $3,
                language_version = $4
              |sql}
    )
    |> update_user_table
  | Custom field ->
    let open Custom_field in
    (upsert_answer pool (Entity.id contact)) field
;;

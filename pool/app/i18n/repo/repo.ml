module RepoEntity = Repo_entity

module Sql = struct
  let select_from_i18n_sql where_fragment =
    let select_from =
      {sql|
        SELECT
          LOWER(CONCAT(
            SUBSTR(HEX(uuid), 1, 8), '-',
            SUBSTR(HEX(uuid), 9, 4), '-',
            SUBSTR(HEX(uuid), 13, 4), '-',
            SUBSTR(HEX(uuid), 17, 4), '-',
            SUBSTR(HEX(uuid), 21)
          )),
          i18n_key,
          language,
          content
        FROM pool_i18n
      |sql}
    in
    Format.asprintf "%s %s" select_from where_fragment
  ;;

  let find_request =
    let open Caqti_request.Infix in
    {sql|
      WHERE uuid = UNHEX(REPLACE(?, '-', ''))
    |sql}
    |> select_from_i18n_sql
    |> Caqti_type.string ->! RepoEntity.t
  ;;

  let find pool id =
    let open Utils.Lwt_result.Infix in
    Utils.Database.find_opt
      (Pool_database.Label.value pool)
      find_request
      (id |> Pool_common.Id.value)
    ||> CCOption.to_result Pool_common.Message.(NotFound Field.I18n)
  ;;

  let find_by_key_request =
    let open Caqti_request.Infix in
    {sql|
      WHERE i18n_key = ? AND language = ?
    |sql}
    |> select_from_i18n_sql
    |> Caqti_type.(tup2 string string) ->! RepoEntity.t
  ;;

  let find_by_key pool key language =
    let open Utils.Lwt_result.Infix in
    Utils.Database.find_opt
      (Pool_database.Label.value pool)
      find_by_key_request
      (key |> Entity.Key.to_string, language |> Pool_common.Language.show)
    ||> CCOption.to_result Pool_common.Message.(NotFound Field.I18n)
  ;;

  let find_all_request =
    let open Caqti_request.Infix in
    "" |> select_from_i18n_sql |> Caqti_type.unit ->* RepoEntity.t
  ;;

  let find_all pool =
    Utils.Database.collect (Pool_database.Label.value pool) find_all_request
  ;;

  let insert_sql =
    {sql|
      INSERT INTO pool_i18n (
        uuid,
        i18n_key,
        language,
        content
      ) VALUES (
        UNHEX(REPLACE(?, '-', '')),
        ?,
        ?,
        ?
      )
    |sql}
  ;;

  let insert_request =
    let open Caqti_request.Infix in
    insert_sql |> RepoEntity.t ->. Caqti_type.unit
  ;;

  let insert pool =
    Utils.Database.exec (Pool_database.Label.value pool) insert_request
  ;;

  let update_request =
    let open Caqti_request.Infix in
    {sql|
      UPDATE pool_i18n
      SET
        i18n_key = $2,
        language = $3,
        content = $4
      WHERE
        uuid = UNHEX(REPLACE($1, '-', ''))
    |sql}
    |> RepoEntity.t ->. Caqti_type.unit
  ;;

  let update pool =
    Utils.Database.exec (Pool_database.Label.value pool) update_request
  ;;

  let delete_by_key_request =
    let open Caqti_request.Infix in
    {sql|
      DELETE FROM pool_i18n
      WHERE i18n_key = ?
    |sql}
    |> Caqti_type.(string ->. unit)
  ;;

  let delete_by_key pool =
    Utils.Database.exec (Pool_database.Label.value pool) delete_by_key_request
  ;;
end

let find = Sql.find
let find_by_key = Sql.find_by_key
let find_all = Sql.find_all
let insert = Sql.insert
let update = Sql.update

let delete_by_key pool key =
  key |> Entity.Key.to_string |> Sql.delete_by_key pool
;;

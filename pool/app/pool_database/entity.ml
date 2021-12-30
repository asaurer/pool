module PoolError = Pool_common.Message

module Url = struct
  type t = string [@@deriving eq]

  let create url =
    if CCString.is_empty url
    then Error PoolError.(Invalid DatabaseUrl)
    else Ok url
  ;;

  let schema () =
    Conformist.custom
      (Pool_common.Utils.schema_decoder create PoolError.DatabaseUrl)
      CCList.pure
      "database_url"
  ;;
end

module Label = struct
  type t = string [@@deriving eq, show]

  let value m = m
  let of_string m = m

  let create label =
    if CCString.is_empty label || String.contains label ' '
    then Error PoolError.(Invalid DatabaseLabel)
    else Ok label
  ;;

  let schema () =
    Conformist.custom
      (Pool_common.Utils.schema_decoder create PoolError.DatabaseLabel)
      CCList.pure
      "database_label"
  ;;
end

type t =
  { url : Url.t
  ; label : Label.t
  }
[@@deriving eq]

let create url label = Ok { url; label }

let add_pool model =
  Sihl.Database.add_pool
    ~pool_size:
      (Sihl.Configuration.read_string "DATABASE_POOL_SIZE"
      |> CCFun.flip CCOption.bind CCInt.of_string
      |> CCOption.value ~default:10)
    model.label
    model.url
;;

let read_pool m = m.label
let pp formatter m = Label.pp formatter m.label
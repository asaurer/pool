module Conformist = Pool_common.Utils.PoolConformist

module Create : sig
  type t =
    { key : I18n.Key.t
    ; language : Pool_common.Language.t
    ; content : I18n.Content.t
    }

  val handle : t -> (Pool_event.t list, Pool_common.Message.error) result

  val decode
    :  (string * string list) list
    -> (t, Pool_common.Message.error) result

  (** TODO *)
  val build_checker : 'a -> 'b
end = struct
  type t =
    { key : I18n.Key.t
    ; language : Pool_common.Language.t
    ; content : I18n.Content.t
    }

  let command key language content = { key; language; content }

  let schema =
    Pool_common.Utils.PoolConformist.(
      make
        Field.
          [ I18n.Key.schema ()
          ; Pool_common.Language.schema ()
          ; I18n.Content.schema ()
          ]
        command)
  ;;

  let handle (command : t) =
    let property : I18n.create =
      I18n.
        { key = command.key
        ; language = command.language
        ; content = command.content
        }
    in
    Ok [ I18n.Created property |> Pool_event.i18n ]
  ;;

  let decode data =
    Conformist.decode_and_validate schema data
    |> CCResult.map_err Pool_common.Message.to_conformist_error
  ;;

  let build_checker _ =
    let _effects = [ `Update, `Uniq "some_tenant_id" ] in
    Utils.todo [%here]
  ;;
end

module Update : sig
  type t = { content : I18n.Content.t }

  val handle
    :  I18n.t
    -> t
    -> (Pool_event.t list, Pool_common.Message.error) result

  val decode
    :  (string * string list) list
    -> (t, Pool_common.Message.error) result

  (** TODO *)
  val build_checker : 'a -> 'b
end = struct
  type t = { content : I18n.Content.t }

  let command content = { content }
  let schema = Conformist.(make Field.[ I18n.Content.schema () ] command)

  let handle property (command : t) =
    let edit : I18n.edit = I18n.{ content = command.content } in
    Ok [ I18n.Updated (property, edit) |> Pool_event.i18n ]
  ;;

  let decode data =
    Conformist.decode_and_validate schema data
    |> CCResult.map_err Pool_common.Message.to_conformist_error
  ;;

  let build_checker _ =
    let _effects = [ `Update, `Uniq "some_tenant_id" ] in
    Utils.todo [%here]
  ;;
end

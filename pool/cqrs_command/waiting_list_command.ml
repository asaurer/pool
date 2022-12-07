module Conformist = Pool_common.Utils.PoolConformist

let src = Logs.Src.create "waiting_list.cqrs"

module Create : sig
  type t = Waiting_list.create

  val handle
    :  ?tags:Logs.Tag.set
    -> t
    -> (Pool_event.t list, Pool_common.Message.error) result

  val can : Guard.Authorizer.effect list
end = struct
  type t = Waiting_list.create

  let handle ?(tags = Logs.Tag.empty) (command : Waiting_list.create) =
    Logs.info ~src (fun m -> m "Handle command Create" ~tags);
    if command.Waiting_list.experiment
         .Experiment.Public.direct_registration_disabled
       |> Experiment.DirectRegistrationDisabled.value
    then Ok [ Waiting_list.Created command |> Pool_event.waiting_list ]
    else Error Pool_common.Message.NotEligible
  ;;

  let can = [ `Create, `TargetEntity `WaitingList ]
end

module Update : sig
  type t = Waiting_list.update

  val handle
    :  ?tags:Logs.Tag.set
    -> Waiting_list.t
    -> t
    -> (Pool_event.t list, Pool_common.Message.error) result

  val decode
    :  (string * string list) list
    -> (t, Pool_common.Message.error) result

  val can : Waiting_list.t -> Guard.Authorizer.effect list
end = struct
  type t = Waiting_list.update

  let command comment = Waiting_list.{ comment }

  let schema =
    Conformist.(
      make
        Field.[ Conformist.optional @@ Waiting_list.Comment.schema () ]
        command)
  ;;

  let handle ?(tags = Logs.Tag.empty) waiting_list (command : t) =
    Logs.info ~src (fun m -> m "Handle command Update" ~tags);
    Ok
      [ Waiting_list.Updated (command, waiting_list) |> Pool_event.waiting_list
      ]
  ;;

  let decode data =
    Conformist.decode_and_validate schema data
    |> CCResult.map_err Pool_common.Message.to_conformist_error
  ;;

  let can waiting_list =
    [ ( `Update
      , `Target
          (waiting_list.Waiting_list.id
          |> Guard.Uuid.target_of Pool_common.Id.value) )
    ]
  ;;
end

module Destroy : sig
  type t = Waiting_list.t

  val handle
    :  ?tags:Logs.Tag.set
    -> t
    -> (Pool_event.t list, Pool_common.Message.error) result

  val can : Waiting_list.t -> Guard.Authorizer.effect list
end = struct
  type t = Waiting_list.t

  let handle ?(tags = Logs.Tag.empty) m =
    Logs.info ~src (fun m -> m "Handle command Destroy" ~tags);
    Ok [ Waiting_list.Deleted m |> Pool_event.waiting_list ]
  ;;

  let can waiting_list =
    [ `Manage, `TargetEntity `WaitingList
    ; ( `Delete
      , `Target
          (waiting_list.Waiting_list.id
          |> Guard.Uuid.target_of Pool_common.Id.value) )
    ]
  ;;
end

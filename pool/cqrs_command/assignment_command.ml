module Conformist = Pool_common.Utils.PoolConformist

module Create : sig
  type t =
    { contact : Contact.t
    ; session : Session.Public.t
    }

  val handle : t -> (Pool_event.t list, Pool_common.Message.error) result
  val can : Sihl_user.t -> t -> bool Lwt.t
end = struct
  type t =
    { contact : Contact.t
    ; session : Session.Public.t
    }

  let handle (command : t) =
    let create =
      Assignment.
        { contact = command.contact
        ; session_id = command.session.Session.Public.id
        }
    in
    Ok [ Assignment.Created create |> Pool_event.assignment ]
  ;;

  let can user _ =
    Permission.can user ~any_of:[ Permission.Create Permission.Assignment ]
  ;;
end

module Cancel : sig
  type t = Assignment.t

  val handle : t -> (Pool_event.t list, Pool_common.Message.error) result
  val can : Sihl_user.t -> t -> bool Lwt.t
end = struct
  type t = Assignment.t

  let handle (command : t)
      : (Pool_event.t list, Pool_common.Message.error) result
    =
    Ok [ Assignment.Canceled command |> Pool_event.assignment ]
  ;;

  let can user command =
    Permission.can
      user
      ~any_of:
        [ Permission.Update (Permission.Assignment, Some command.Assignment.id)
        ]
  ;;
end

module SetAttendance : sig
  type t =
    { show_up : Assignment.ShowUp.t
    ; participated : Assignment.Participated.t
    }

  val handle
    :  Assignment.t
    -> t
    -> (Pool_event.t list, Pool_common.Message.error) result

  val decode
    :  (string * string list) list
    -> (t, Pool_common.Message.error) result

  val can : Sihl_user.t -> Assignment.t -> bool Lwt.t
end = struct
  type t =
    { show_up : Assignment.ShowUp.t
    ; participated : Assignment.Participated.t
    }

  let command (show_up : Assignment.ShowUp.t) participated =
    { show_up; participated }
  ;;

  let schema =
    Conformist.(
      make
        Field.[ Assignment.ShowUp.schema (); Assignment.Participated.schema () ]
        command)
  ;;

  let handle assignment (command : t) =
    Ok
      [ Assignment.ShowedUp (assignment, command.show_up)
        |> Pool_event.assignment
      ; Assignment.Participated (assignment, command.participated)
        |> Pool_event.assignment
      ]
  ;;

  let decode data =
    Conformist.decode_and_validate schema data
    |> CCResult.map_err Pool_common.Message.to_conformist_error
  ;;

  let can user assignment =
    Permission.can
      user
      ~any_of:
        [ Permission.Update
            (Permission.Assignment, Some assignment.Assignment.id)
        ]
  ;;
end

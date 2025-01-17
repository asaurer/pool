module Conformist = Pool_common.Utils.PoolConformist

let src = Logs.Src.create "session.cqrs"

let create_command
  start
  duration
  description
  max_participants
  min_participants
  overbook
  reminder_subject
  reminder_text
  reminder_lead_time
  : Session.base
  =
  Session.
    { start
    ; duration
    ; description
    ; max_participants
    ; min_participants
    ; overbook
    ; reminder_subject
    ; reminder_text
    ; reminder_lead_time
    }
;;

let create_schema =
  Conformist.(
    make
      Field.
        [ Session.Start.schema ()
        ; Session.Duration.schema ()
        ; Conformist.optional @@ Session.Description.schema ()
        ; Session.ParticipantAmount.schema
            Pool_common.Message.Field.MaxParticipants
        ; Session.ParticipantAmount.schema
            Pool_common.Message.Field.MinParticipants
        ; Session.ParticipantAmount.schema Pool_common.Message.Field.Overbook
        ; Conformist.optional @@ Pool_common.Reminder.Subject.schema ()
        ; Conformist.optional @@ Pool_common.Reminder.Text.schema ()
        ; Conformist.optional @@ Pool_common.Reminder.LeadTime.schema ()
        ]
      create_command)
;;

let update_command
  start
  duration
  description
  max_participants
  min_participants
  overbook
  reminder_subject
  reminder_text
  reminder_lead_time
  : Session.update
  =
  Session.
    { start
    ; duration
    ; description
    ; max_participants
    ; min_participants
    ; overbook
    ; reminder_subject
    ; reminder_text
    ; reminder_lead_time
    }
;;

let update_schema =
  Conformist.(
    make
      Field.
        [ Conformist.optional @@ Session.Start.schema ()
        ; Conformist.optional @@ Session.Duration.schema ()
        ; Conformist.optional @@ Session.Description.schema ()
        ; Session.ParticipantAmount.schema
            Pool_common.Message.Field.MaxParticipants
        ; Session.ParticipantAmount.schema
            Pool_common.Message.Field.MinParticipants
        ; Session.ParticipantAmount.schema Pool_common.Message.Field.Overbook
        ; Conformist.optional @@ Pool_common.Reminder.Subject.schema ()
        ; Conformist.optional @@ Pool_common.Reminder.Text.schema ()
        ; Conformist.optional @@ Pool_common.Reminder.LeadTime.schema ()
        ]
      update_command)
;;

let validate_start follow_up_sessions parent_session start =
  let open Session in
  (* If session has follow-ups, make sure they are all later *)
  let starts_after_followups =
    CCList.exists
      (fun (follow_up : Session.t) ->
        Ptime.is_earlier ~than:(Start.value start) (Start.value follow_up.start))
      follow_up_sessions
  in
  (* If session is follow-up, make sure it's later than parent *)
  let starts_before_parent =
    CCOption.map_or
      ~default:false
      (fun (s : Session.t) ->
        Ptime.is_earlier ~than:(Start.value s.start) (Start.value start))
      parent_session
  in
  if starts_before_parent || starts_after_followups
  then Error Pool_common.Message.FollowUpIsEarlierThanMain
  else Ok ()
;;

(* TODO [aerben] create sigs *)
module Create : sig
  include Common.CommandSig with type t = Session.base

  val handle
    :  ?tags:Logs.Tag.set
    -> ?parent_session:Session.t
    -> Experiment.Id.t
    -> Pool_location.t
    -> t
    -> (Pool_event.t list, Conformist.error_msg) result

  val decode : Conformist.input -> (t, Conformist.error_msg) result
end = struct
  type t = Session.base

  let schema = create_schema

  let handle
    ?(tags = Logs.Tag.empty)
    ?parent_session
    experiment_id
    location
    (Session.
       { start
       ; duration
       ; description
       ; max_participants
       ; min_participants
       ; (* TODO [aerben] find a better name *)
         overbook
       ; reminder_subject
       ; reminder_text
       ; reminder_lead_time
       } :
      Session.base)
    =
    Logs.info ~src (fun m -> m "Handle command Create" ~tags);
    (* If session is follow-up, make sure it's later than parent *)
    let follow_up_is_ealier =
      let open Session in
      CCOption.map_or
        ~default:false
        (fun (s : Session.t) ->
          Ptime.is_earlier ~than:(Start.value s.start) (Start.value start))
        parent_session
    in
    let validations =
      [ follow_up_is_ealier, Pool_common.Message.FollowUpIsEarlierThanMain
      ; ( max_participants < min_participants
        , Pool_common.Message.(
            Smaller (Field.MaxParticipants, Field.MinParticipants)) )
      ]
    in
    let open CCResult in
    let* () =
      validations
      |> CCList.filter fst
      |> CCList.map (fun (_, err) -> Error err)
      |> flatten_l
      |> map ignore
    in
    let (session : Session.base) =
      Session.
        { start
        ; duration
        ; description
        ; max_participants
        ; min_participants
        ; overbook
        ; reminder_subject
        ; reminder_text
        ; reminder_lead_time
        }
    in
    Ok
      [ Session.Created
          ( session
          , CCOption.map (fun s -> s.Session.id) parent_session
          , experiment_id
          , location )
        |> Pool_event.session
      ]
  ;;

  let decode data =
    Conformist.decode_and_validate schema data
    |> CCResult.map_err Pool_common.Message.to_conformist_error
  ;;

  let effects = [ `Create, `TargetEntity `Session ]
end

module Update : sig
  include Common.CommandSig with type t = Session.update

  val handle
    :  ?tags:Logs.Tag.set
    -> ?parent_session:Session.t
    -> Session.t list
    -> Session.t
    -> Pool_location.t
    -> t
    -> (Pool_event.t list, Conformist.error_msg) result

  val decode
    :  (string * string list) list
    -> (t, Pool_common.Message.error) result

  val effects : Pool_common.Id.t -> Guard.Authorizer.effect list
end = struct
  type t = Session.update

  let handle
    ?(tags = Logs.Tag.empty)
    ?parent_session
    follow_up_sessions
    session
    location
    (Session.
       { start
       ; duration
       ; description
       ; max_participants
       ; min_participants
       ; overbook
       ; reminder_subject
       ; reminder_text
       ; reminder_lead_time
       } :
      Session.update)
    =
    Logs.info ~src (fun m -> m "Handle command Update" ~tags);
    let open Session in
    let open CCResult in
    let has_assignments = Session.has_assignments session in
    let* start, duration =
      let open Pool_common.Message in
      let to_result field =
        CCOption.to_result (Conformist [ field, Pool_common.Message.NoValue ])
      in
      match has_assignments with
      | false ->
        CCResult.both
          (to_result Field.Start start)
          (to_result Field.Duration duration)
      | true -> Ok (session.start, session.duration)
    in
    let* () = validate_start follow_up_sessions parent_session start in
    let* () =
      if max_participants < min_participants
      then
        Error
          Pool_common.Message.(
            Smaller (Field.MaxParticipants, Field.MinParticipants))
      else Ok ()
    in
    let (session_cmd : Session.base) =
      Session.
        { start
        ; duration
        ; description
        ; max_participants
        ; min_participants
        ; overbook
        ; reminder_subject
        ; reminder_text
        ; reminder_lead_time
        }
    in
    Ok
      [ Session.Updated (session_cmd, location, session) |> Pool_event.session ]
  ;;

  let decode data =
    Conformist.decode_and_validate update_schema data
    |> CCResult.map_err Pool_common.Message.to_conformist_error
  ;;

  let effects id =
    [ `Update, `Target (id |> Guard.Uuid.target_of Pool_common.Id.value)
    ; `Update, `TargetEntity `Invitation
    ]
  ;;
end

module Reschedule : sig
  include Common.CommandSig with type t = Session.reschedule

  val handle
    :  ?tags:Logs.Tag.set
    -> ?parent_session:Session.t
    -> Session.t list
    -> Session.t
    -> Sihl_email.t list
    -> t
    -> (Pool_event.t list, Conformist.error_msg) result

  val decode
    :  (string * string list) list
    -> (t, Pool_common.Message.error) result

  val effects : Pool_common.Id.t -> Guard.Authorizer.effect list
end = struct
  type t = Session.reschedule

  let command start duration : Session.reschedule = Session.{ start; duration }

  let schema =
    Conformist.(
      make Field.[ Session.Start.schema (); Session.Duration.schema () ] command)
  ;;

  let handle
    ?(tags = Logs.Tag.empty)
    ?parent_session
    follow_up_sessions
    session
    emails
    (Session.{ start; _ } as reschedule : Session.reschedule)
    =
    Logs.info ~src (fun m -> m "Handle command Reschedule" ~tags);
    let open CCResult in
    let* () = validate_start follow_up_sessions parent_session start in
    let* () =
      if Ptime.is_earlier
           ~than:(Ptime_clock.now ())
           (start |> Session.Start.value)
      then Error Pool_common.Message.TimeInPast
      else Ok ()
    in
    Ok
      ((Session.Rescheduled (session, reschedule) |> Pool_event.session)
      ::
      (if emails |> CCList.is_empty |> not
      then [ Email.BulkSent emails |> Pool_event.email ]
      else []))
  ;;

  let decode data =
    Conformist.decode_and_validate schema data
    |> CCResult.map_err Pool_common.Message.to_conformist_error
  ;;

  let effects id =
    [ `Update, `Target (id |> Guard.Uuid.target_of Pool_common.Id.value)
    ; `Update, `TargetEntity `Invitation
    ]
  ;;
end

module Delete : sig
  include Common.CommandSig

  type t = { session : Session.t }

  val handle
    :  ?tags:Logs.Tag.set
    -> Session.t
    -> (Pool_event.t list, Pool_common.Message.error) result

  val effects : Pool_common.Id.t -> Guard.Authorizer.effect list
end = struct
  type t = { session : Session.t }

  let handle ?(tags = Logs.Tag.empty) session =
    Logs.info ~src (fun m -> m "Handle command Delete" ~tags);
    (* TODO [aerben] how to deal with follow-ups? currently they just
       disappear *)
    if not
         (session.Session.assignment_count |> Session.AssignmentCount.value == 0)
    then Error Pool_common.Message.SessionHasAssignments
    else Ok [ Session.Deleted session |> Pool_event.session ]
  ;;

  let effects id =
    [ `Delete, `Target (id |> Guard.Uuid.target_of Pool_common.Id.value)
    ; `Delete, `TargetEntity `Invitation
    ]
  ;;
end

module Cancel : sig
  include Common.CommandSig

  type t =
    { session : Session.t
    ; notify_via : string
    }

  val handle
    :  ?tags:Logs.Tag.set
    -> Session.t
    -> (Pool_event.t list, Pool_common.Message.error) result

  val effects : Pool_common.Id.t -> Guard.Authorizer.effect list
end = struct
  (* TODO issue #90 step 2 *)
  (* notify_via: Email, SMS *)
  type t =
    { session : Session.t
    ; notify_via : string
    }

  let handle ?(tags = Logs.Tag.empty) session =
    Logs.info ~src (fun m -> m "Handle command Cancel" ~tags);
    Ok [ Session.Canceled session |> Pool_event.session ]
  ;;

  let effects id =
    [ `Update, `Target (id |> Guard.Uuid.target_of Pool_common.Id.value)
    ; `Update, `TargetEntity `Invitation
    ]
  ;;
end

module SendReminder : sig
  include Common.CommandSig with type t = (Session.t * Sihl_email.t list) list

  val effects : Pool_common.Id.t -> Guard.Authorizer.effect list
end = struct
  type t = (Session.t * Sihl_email.t list) list

  let handle ?(tags = Logs.Tag.empty) command =
    Logs.info ~src (fun m -> m "Handle command SendReminder" ~tags);
    Ok
      (CCList.flat_map
         (fun (session, emails) ->
           (Session.ReminderSent session |> Pool_event.session)
           ::
           (if emails |> CCList.is_empty |> not
           then [ Email.BulkSent emails |> Pool_event.email ]
           else []))
         command)
  ;;

  let effects id =
    [ `Update, `Target (id |> Guard.Uuid.target_of Pool_common.Id.value)
    ; `Update, `TargetEntity `Invitation
    ]
  ;;
end

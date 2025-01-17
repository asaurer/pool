module Id = struct
  include Pool_common.Id

  let to_common m = m
end

module Common = Pool_common

module Title = struct
  include Pool_common.Model.String

  let field = Common.Message.Field.Title
  let create = create field
  let schema = schema ?validation:None field
end

module PublicTitle = struct
  include Pool_common.Model.String

  let field = Common.Message.Field.PublicTitle
  let create = create field
  let schema = schema ?validation:None field
end

module Description = struct
  include Pool_common.Model.String

  let field = Common.Message.Field.Description
  let create = create field
  let schema = schema ?validation:None field
end

module DirectRegistrationDisabled = struct
  include Pool_common.Model.Boolean

  let schema = schema Common.Message.Field.DirectRegistrationDisabled
end

module RegistrationDisabled = struct
  include Pool_common.Model.Boolean

  let schema = schema Common.Message.Field.RegistrationDisabled
end

module AllowUninvitedSignup = struct
  include Pool_common.Model.Boolean

  let schema = schema Common.Message.Field.AllowUninvitedSignup
end

module InvitationTemplate = struct
  module Subject = struct
    include Pool_common.Model.String

    let field = Common.Message.Field.InvitationSubject
    let create = create field
    let schema = schema ?validation:None field
    let of_string m = m
  end

  module Text = struct
    include Pool_common.Model.String

    let field = Common.Message.Field.InvitationText
    let create = create field
    let schema = schema ?validation:None field
    let of_string m = m
  end

  type t =
    { subject : Subject.t
    ; text : Text.t
    }
  [@@deriving eq, show]

  let create subject text : (t, Common.Message.error) result =
    let open CCResult in
    let* subject = Subject.create subject in
    let* text = Subject.create text in
    Ok { subject; text }
  ;;

  let subject_value (m : t) = m.subject |> Subject.value
  let text_value (m : t) = m.text |> Text.value
end

type t =
  { id : Id.t
  ; title : Title.t
  ; public_title : PublicTitle.t
  ; description : Description.t
  ; filter : Filter.t option
  ; direct_registration_disabled : DirectRegistrationDisabled.t
  ; registration_disabled : RegistrationDisabled.t
  ; allow_uninvited_signup : AllowUninvitedSignup.t
  ; experiment_type : Pool_common.ExperimentType.t option
  ; invitation_template : InvitationTemplate.t option
  ; session_reminder_lead_time : Pool_common.Reminder.LeadTime.t option
  ; session_reminder_subject : Pool_common.Reminder.Subject.t option
  ; session_reminder_text : Pool_common.Reminder.Text.t option
  ; created_at : Ptime.t
  ; updated_at : Ptime.t
  }
[@@deriving eq, show]

let create
  ?id
  title
  public_title
  description
  direct_registration_disabled
  registration_disabled
  allow_uninvited_signup
  experiment_type
  invitation_subject
  invitation_text
  session_reminder_lead_time
  session_reminder_subject
  session_reminder_text
  =
  let open CCResult in
  let* () =
    match session_reminder_subject, session_reminder_text with
    | Some _, Some _ | None, None -> Ok ()
    | _ -> Error Pool_common.Message.ReminderSubjectAndTextRequired
  in
  let* invitation_template =
    match invitation_subject, invitation_text with
    | Some subject, Some text ->
      InvitationTemplate.create subject text |> CCResult.map CCOption.pure
    | None, None -> Ok None
    | _ -> Error Pool_common.Message.InvitationSubjectAndTextRequired
  in
  Ok
    { id = id |> CCOption.value ~default:(Id.create ())
    ; title
    ; public_title
    ; description
    ; filter = None
    ; direct_registration_disabled
    ; registration_disabled
    ; allow_uninvited_signup
    ; experiment_type
    ; invitation_template
    ; session_reminder_lead_time
    ; session_reminder_subject
    ; session_reminder_text
    ; created_at = Ptime_clock.now ()
    ; updated_at = Ptime_clock.now ()
    }
;;

let title_value (m : t) = Title.value m.title
let public_title_value (m : t) = PublicTitle.value m.public_title
let description_value (m : t) = Description.value m.description

module Public = struct
  type t =
    { id : Pool_common.Id.t
    ; public_title : PublicTitle.t
    ; description : Description.t
    ; direct_registration_disabled : DirectRegistrationDisabled.t
    ; experiment_type : Pool_common.ExperimentType.t option
    }
  [@@deriving eq, show]
end

let session_reminder_subject_value m =
  m.session_reminder_subject |> CCOption.map Pool_common.Reminder.Subject.value
;;

let session_reminder_text_value m =
  m.session_reminder_text |> CCOption.map Pool_common.Reminder.Text.value
;;

let session_reminder_lead_time_value m =
  m.session_reminder_lead_time
  |> CCOption.map Pool_common.Reminder.LeadTime.value
;;

let direct_registration_disabled_value (m : t) =
  DirectRegistrationDisabled.value m.direct_registration_disabled
;;

let registration_disabled_value (m : t) =
  RegistrationDisabled.value m.registration_disabled
;;

let allow_uninvited_signup_value (m : t) =
  AllowUninvitedSignup.value m.allow_uninvited_signup
;;

let boolean_fields =
  Pool_common.Message.Field.
    [ DirectRegistrationDisabled; RegistrationDisabled; AllowUninvitedSignup ]
;;

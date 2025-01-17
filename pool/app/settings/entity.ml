module Message = Pool_common.Message

(* TODO [aerben] maybe move to pool common *)
module Day = struct
  type t = int [@@deriving eq, show, yojson]

  let to_timespan t = t * 24 * 60 * 60 |> Ptime.Span.of_int_s
end

module Week = struct
  type t = int [@@deriving eq, show, yojson]

  let to_timespan t = t * 7 * 24 * 60 * 60 |> Ptime.Span.of_int_s
end

module ContactEmail = struct
  include Pool_common.Model.String

  let field = Message.Field.EmailAddress
  (* TODO: email address validation *)

  let create = create field
  let schema = schema ?validation:None field
  let of_string m = m
end

module EmailSuffix = struct
  include Pool_common.Model.String

  let field = Message.Field.EmailSuffix
  (* TODO: email address validation *)

  let create = create field
  let schema = schema ?validation:None field
  let of_string m = m
end

module InactiveUser = struct
  module DisableAfter = struct
    type t = Week.t [@@deriving eq, show, yojson]

    let create week =
      let open CCResult.Infix in
      week
      |> CCInt.of_string
      |> CCOption.to_result Pool_common.Message.(Invalid Field.TimeSpan)
      >>= fun week ->
      if week < 0 then Error Pool_common.Message.TimeSpanPositive else Ok week
    ;;

    let value m = m
    let to_timespan = Week.to_timespan

    let schema () =
      Pool_common.Utils.schema_decoder
        create
        CCInt.to_string
        Message.Field.InactiveUserDisableAfter
    ;;
  end

  module Warning = struct
    type t = Day.t [@@deriving eq, show, yojson]

    let create day =
      let open CCResult.Infix in
      let open Pool_common.Message in
      day
      |> CCInt.of_string
      |> CCOption.to_result (Invalid Field.TimeSpan)
      >>= fun day -> if day < 0 then Error TimeSpanPositive else Ok day
    ;;

    let value m = m
    let to_timespan = Day.to_timespan

    let schema () =
      Pool_common.Utils.schema_decoder
        create
        CCInt.to_string
        Message.Field.InactiveUserWarning
    ;;
  end
end

module TriggerProfileUpdateAfter = struct
  type t = Day.t [@@deriving eq, show, yojson]

  let create day =
    let open CCResult.Infix in
    let open Pool_common.Message in
    day
    |> CCInt.of_string
    |> CCOption.to_result (Invalid Field.TimeSpan)
    >>= fun day -> if day < 0 then Error TimeSpanPositive else Ok day
  ;;

  let value m = m
  let to_timespan = Day.to_timespan

  let schema () =
    Pool_common.Utils.schema_decoder
      create
      CCInt.to_string
      Message.Field.TriggerProfileUpdateAfter
  ;;
end

module TermsAndConditions = struct
  module Terms = struct
    include Pool_common.Model.String

    let field = Message.Field.TermsAndConditions
    (* TODO: email address validation *)

    let create = create field
    let schema = schema ?validation:None field
    let of_string m = m
  end

  type t = Pool_common.Language.t * Terms.t [@@deriving eq, show, yojson]

  let create language content =
    let open CCResult in
    let* language = Pool_common.Language.create language in
    let* content = Terms.create content in
    Ok (language, content)
  ;;

  let value m = m
end

module Value = struct
  type default_reminder_lead_time = Pool_common.Reminder.LeadTime.t
  [@@deriving eq, show, yojson]

  type tenant_languages = Pool_common.Language.t list
  [@@deriving eq, show, yojson]

  type tenant_email_suffixes = EmailSuffix.t list [@@deriving eq, show, yojson]
  type tenant_contact_email = ContactEmail.t [@@deriving eq, show, yojson]

  type inactive_user_disable_after = InactiveUser.DisableAfter.t
  [@@deriving eq, show, yojson]

  type inactive_user_warning = InactiveUser.DisableAfter.t
  [@@deriving eq, show, yojson]

  type trigger_profile_update_after = TriggerProfileUpdateAfter.t
  [@@deriving eq, show, yojson]

  type terms_and_conditions = TermsAndConditions.t list
  [@@deriving eq, show, yojson]

  type t =
    | DefaultReminderLeadTime of default_reminder_lead_time
    | TenantLanguages of tenant_languages
    | TenantEmailSuffixes of tenant_email_suffixes
    | TenantContactEmail of tenant_contact_email
    | InactiveUserDisableAfter of inactive_user_disable_after
    | InactiveUserWarning of inactive_user_warning
    | TriggerProfileUpdateAfter of trigger_profile_update_after
    | TermsAndConditions of terms_and_conditions
  [@@deriving eq, show, yojson, variants]
end

type setting_key =
  | ReminderLeadTime [@name "default_reminder_lead_time"]
  | Languages [@name "languages"]
  | EmailSuffixes [@name "email_suffixes"]
  | ContactEmail [@name "contact_email"]
  | InactiveUserDisableAfter [@name "inactive_user_disable_after"]
  | InactiveUserWarning [@name "inactive_user_warning"]
  | TriggerProfileUpdateAfter [@name "trigger_profile_update_after"]
  | TermsAndConditions [@name "terms_and_conditions"]
[@@deriving eq, show, yojson]

type t =
  { value : Value.t
  ; created_at : Ptime.t
  ; updated_at : Ptime.t
  }
[@@deriving eq, show]

module Write = struct
  type t = { value : Value.t }
end

let action_of_param = function
  | "create_tenant_emailsuffix" -> Ok `CreateTenantEmailSuffix
  | "delete_tenant_emailsuffix" -> Ok `DeleteTenantEmailSuffix
  | "update_default_lead_time" -> Ok `UpdateDefaultLeadTime
  | "update_inactive_user_disable_after" -> Ok `UpdateInactiveUserDisableAfter
  | "update_inactive_user_warning" -> Ok `UpdateInactiveUserWarning
  | "update_tenant_contact_email" -> Ok `UpdateTenantContactEmail
  | "update_tenant_emailsuffix" -> Ok `UpdateTenantEmailSuffixes
  | "update_tenant_languages" -> Ok `UpdateTenantLanguages
  | "update_terms_and_conditions" -> Ok `UpdateTermsAndConditions
  | "update_trigger_profile_update_after" -> Ok `UpdateTriggerProfileUpdateAfter
  | _ -> Error Pool_common.Message.DecodeAction
;;

let stringify_action = function
  | `CreateTenantEmailSuffix -> "create_tenant_emailsuffix"
  | `DeleteTenantEmailSuffix -> "delete_tenant_emailsuffix"
  | `UpdateDefaultLeadTime -> "update_default_lead_time"
  | `UpdateInactiveUserDisableAfter -> "update_inactive_user_disable_after"
  | `UpdateInactiveUserWarning -> "update_inactive_user_warning"
  | `UpdateTenantContactEmail -> "update_tenant_contact_email"
  | `UpdateTenantEmailSuffixes -> "update_tenant_emailsuffix"
  | `UpdateTenantLanguages -> "update_tenant_languages"
  | `UpdateTermsAndConditions -> "update_terms_and_conditions"
  | `UpdateTriggerProfileUpdateAfter -> "update_trigger_profile_update_after"
;;

let default_session_reminder_lead_time_key_yojson =
  yojson_of_setting_key ReminderLeadTime
;;

let trigger_profile_update_after_key_yojson =
  yojson_of_setting_key TriggerProfileUpdateAfter
;;

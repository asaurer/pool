open Entity
open Default

type event =
  | ContactEmailUpdated of ContactEmail.t
  | DefaultReminderLeadTimeUpdated of Pool_common.Reminder.LeadTime.t
  | EmailSuffixesUpdated of EmailSuffix.t list
  | InactiveUserDisableAfterUpdated of InactiveUser.DisableAfter.t
  | InactiveUserWarningUpdated of InactiveUser.Warning.t
  | LanguagesUpdated of Pool_common.Language.t list
  | TermsAndConditionsUpdated of TermsAndConditions.t list
  | TriggerProfileUpdateAfterUpdated of TriggerProfileUpdateAfter.t
  | DefaultRestored of default
[@@deriving eq, show]

let handle_event pool : event -> unit Lwt.t = function
  | LanguagesUpdated languages ->
    let%lwt () = Repo.update pool (Value.TenantLanguages languages) in
    Lwt.return_unit
  | EmailSuffixesUpdated email_suffixes ->
    let%lwt () = Repo.update pool (Value.TenantEmailSuffixes email_suffixes) in
    Lwt.return_unit
  | DefaultReminderLeadTimeUpdated lead_time ->
    let%lwt () = Repo.update pool (Value.DefaultReminderLeadTime lead_time) in
    Lwt.return_unit
  | ContactEmailUpdated contact_email ->
    let%lwt () = Repo.update pool (Value.TenantContactEmail contact_email) in
    Lwt.return_unit
  | InactiveUserDisableAfterUpdated inactive_user_disable_after ->
    let%lwt () =
      Repo.update
        pool
        (Value.InactiveUserDisableAfter inactive_user_disable_after)
    in
    Lwt.return_unit
  | InactiveUserWarningUpdated inactive_user_warning ->
    let%lwt () =
      Repo.update pool (Value.InactiveUserWarning inactive_user_warning)
    in
    Lwt.return_unit
  | TermsAndConditionsUpdated terms_and_conditions ->
    let%lwt () =
      Repo.update pool (Value.TermsAndConditions terms_and_conditions)
    in
    Lwt.return_unit
  | TriggerProfileUpdateAfterUpdated trigger_update_after ->
    let%lwt () =
      Repo.update pool (Value.TriggerProfileUpdateAfter trigger_update_after)
    in
    Lwt.return_unit
  | DefaultRestored
      { default_reminder_lead_time
      ; tenant_languages
      ; tenant_email_suffixes
      ; tenant_contact_email
      ; inactive_user_disable_after
      ; inactive_user_warning
      ; trigger_profile_update_after
      ; terms_and_conditions
      } ->
    let%lwt () =
      [ ReminderLeadTime
      ; Languages
      ; EmailSuffixes
      ; ContactEmail
      ; InactiveUserDisableAfter
      ; InactiveUserWarning
      ; TriggerProfileUpdateAfter
      ; TermsAndConditions
      ]
      |> Lwt_list.iter_s (Repo.delete pool)
    in
    let%lwt () =
      Value.
        [ DefaultReminderLeadTime default_reminder_lead_time
        ; TenantLanguages tenant_languages
        ; TenantEmailSuffixes tenant_email_suffixes
        ; TenantContactEmail tenant_contact_email
        ; InactiveUserDisableAfter inactive_user_disable_after
        ; InactiveUserWarning inactive_user_warning
        ; TriggerProfileUpdateAfter trigger_profile_update_after
        ; TermsAndConditions terms_and_conditions
        ]
      |> Lwt_list.iter_s (Repo.insert pool)
    in
    Lwt.return_unit
;;

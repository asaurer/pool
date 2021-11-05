open Entity

type event =
  | LanguagesUpdated of TenantLanguages.Values.t
  | EmailSuffixesUpdated of TenantEmailSuffixes.Values.t
[@@deriving eq, show]

let handle_event pool : event -> unit Lwt.t = function
  | LanguagesUpdated languages ->
    let%lwt _ = Repo.update_languages pool languages in
    Lwt.return_unit
  | EmailSuffixesUpdated email_suffixes ->
    let%lwt _ = Repo.update_email_suffixes pool email_suffixes in
    Lwt.return_unit
;;

(* let[@warning "-4"] equal_event event1 event2 = match event1, event2 with |
   LanguagesUpdated one, LanguagesUpdated two -> TenantLanguages.Values.equal
   one two | EmailSuffixesUpdated one, EmailSuffixesUpdated two ->
   TenantEmailSuffixes.Values.equal one two | _ -> false ;; *)

let pp_event formatter event =
  match event with
  | LanguagesUpdated m -> TenantLanguages.Values.pp formatter m
  | EmailSuffixesUpdated m -> TenantEmailSuffixes.Values.pp formatter m
;;

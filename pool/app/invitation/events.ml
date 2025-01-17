open Entity

let create_invitation (experiment : Experiment.t) contact template =
  (* TODO[tinhub]: Sihl 4.0: add text elements to for subject *)
  let open Experiment in
  let name = Contact.fullname contact in
  let email = Contact.email_address contact in
  let experiment_description =
    experiment.description |> Experiment.Description.value
  in
  Email.Helper.prepare_boilerplate_email
    template
    (email |> Pool_user.EmailAddress.value)
    [ "name", name; "experimentDescription", experiment_description ]
;;

type create =
  { experiment : Experiment.t
  ; contact : Contact.t
  }
[@@deriving eq, show]

type event =
  | Created of Contact.t list * Experiment.t
  | Resent of t
[@@deriving eq, show]

let handle_event pool event =
  let open Utils.Lwt_result.Infix in
  match event with
  | Created (contacts, _) when CCList.is_empty contacts -> Lwt.return_unit
  | Created (contacts, experiment) ->
    let contacts =
      CCList.map (fun contact -> Pool_common.Id.create (), contact) contacts
    in
    let%lwt () = Repo.bulk_insert pool contacts experiment.Experiment.id in
    Lwt_list.iter_s
      (fun (id, contact) ->
        Entity.create ~id contact
        |> Entity_guard.Target.to_authorizable ~ctx:(Pool_tenant.to_ctx pool)
        ||> Pool_common.Utils.get_or_failwith
        ||> fun (_ : [> `Invitation ] Guard.AuthorizableTarget.t) -> ())
      contacts
  | Resent invitation ->
    Repo.update pool { invitation with resent_at = Some (ResentAt.create ()) }
;;

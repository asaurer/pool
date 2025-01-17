include Entity
include Event

let find = Repo.find
let find_multiple = Repo.find_multiple
let find_filtered = Repo.find_filtered
let count_filtered = Repo.count_filtered
let find_by_email = Repo.find_by_email
let find_all = Repo.find_all
let find_to_trigger_profile_update = Repo.find_to_trigger_profile_update

let find_by_user pool (user : Sihl_user.t) =
  user.Sihl_user.id |> Pool_common.Id.of_string |> Repo.find pool
;;

let has_terms_accepted = Event.has_terms_accepted

module Repo = struct
  module Preview = Repo_model.Preview
end

module Guard = struct
  module Target = struct
    type t = Entity.t [@@deriving show]

    let to_authorizable ?ctx t =
      Guard.Persistence.Target.decorate
        ?ctx
        (fun t ->
          Guard.AuthorizableTarget.make
            (Guard.TargetRoleSet.singleton `Contact)
            `Contact
            (Guard.Uuid.Target.of_string_exn (Pool_common.Id.value (id t))))
        t
      |> Lwt_result.map_error (fun s ->
           Format.asprintf "Failed to convert Contact to authorizable: %s" s)
      |> Lwt_result.map_error Pool_common.Message.authorization
    ;;
  end

  module Actor = struct
    type t = Entity.t [@@deriving show]

    let to_authorizable ?ctx t =
      t
      |> Guard.Persistence.Actor.decorate ?ctx (fun t ->
           Guard.Authorizable.make
             (Guard.ActorRoleSet.singleton `Contact)
             `Contact
             (Guard.Uuid.Actor.of_string_exn (Pool_common.Id.value (id t))))
      |> Lwt_result.map_error (fun s ->
           Format.asprintf "Failed to convert Contact to authorizable: %s" s)
      |> Lwt_result.map_error Pool_common.Message.authorization
    ;;

    (** Many request handlers do not extract a [User.t] at any point. This
        function is useful in such cases. *)
    let authorizable_of_req ?ctx req =
      let open Lwt_result.Syntax in
      let* user_id =
        Sihl.Web.Session.find "user_id" req
        |> CCResult.of_opt
        |> CCResult.map_err (fun x -> Pool_common.Message.Authorization x)
        |> Lwt_result.lift
      in
      Guard.Persistence.Actor.decorate
        ?ctx
        (fun id ->
          Guard.Authorizable.make
            (Guard.ActorRoleSet.singleton `Contact)
            `Contact
            (Guard.Uuid.Actor.of_string_exn id))
        user_id
      |> Lwt_result.map_error Pool_common.Message.authorization
    ;;
  end
end

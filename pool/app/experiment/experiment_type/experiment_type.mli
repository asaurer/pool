type public =
  { id : Pool_common.Id.t
  ; description : Experiment.Description.t
  ; sessions : Session.t list
  }
[@@deriving eq, show]

type sessions =
  { experiment : Experiment.t
  ; sessions : Session.t list
  }
[@@deriving eq, show]

type invitations =
  { experiment : Experiment.t
  ; invitations : Invitation.t list
  }
[@@deriving eq, show]

val find_all_public : Pool_database.Label.t -> unit -> public list Lwt.t

val find_public
  :  Pool_database.Label.t
  -> Pool_common.Id.t
  -> (public, Repo_entity.Common.Message.error) result Lwt.t

val find_invitations
  :  Pool_database.Label.t
  -> Pool_common.Id.t
  -> (invitations, Pool_common.Message.error) Lwt_result.t

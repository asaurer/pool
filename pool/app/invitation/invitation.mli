module ResentAt : sig
  type t

  val equal : t -> t -> bool
  val pp : Format.formatter -> t -> unit
  val create : unit -> t
  val value : t -> Ptime.t
end

type t =
  { id : Pool_common.Id.t
  ; contact : Contact.t
  ; resent_at : ResentAt.t option
  ; created_at : Ptime.t
  ; updated_at : Ptime.t
  }

val equal : t -> t -> bool
val pp : Format.formatter -> t -> unit
val create : ?id:Pool_common.Id.t -> Contact.t -> t

type notification_history =
  { invitation : t
  ; queue_entries : (Sihl_email.t * Sihl_queue.instance) list
  }

val equal_notification_history
  :  notification_history
  -> notification_history
  -> bool

val pp_notification_history : Format.formatter -> notification_history -> unit

type create =
  { experiment : Experiment.t
  ; contact : Contact.t
  }

val equal_create : create -> create -> bool
val pp_create : Format.formatter -> create -> unit
val show_create : create -> string

type event =
  | Created of Contact.t list * Experiment.t
  | Resent of t

val equal_event : event -> event -> bool
val pp_event : Format.formatter -> event -> unit
val show_event : event -> string
val handle_event : Pool_database.Label.t -> event -> unit Lwt.t

val find
  :  Pool_database.Label.t
  -> Pool_common.Id.t
  -> (t, Pool_common.Message.error) Lwt_result.t

val find_by_experiment
  :  Pool_database.Label.t
  -> Experiment.Id.t
  -> (t list, Pool_common.Message.error) result Lwt.t

val find_by_contact
  :  Pool_database.Label.t
  -> Contact.t
  -> (t list, Pool_common.Message.error) result Lwt.t

val find_experiment_id_of_invitation
  :  Pool_database.Label.t
  -> t
  -> (Experiment.Id.t, Pool_common.Message.error) result Lwt.t

val find_multiple_by_experiment_and_contacts
  :  Pool_database.Label.t
  -> Pool_common.Id.t list
  -> Experiment.t
  -> Pool_common.Id.t list Lwt.t

val contact_was_invited_to_experiment
  :  Pool_database.Label.t
  -> Experiment.t
  -> Contact.t
  -> bool Lwt.t

module Guard : sig
  module Target : sig
    val to_authorizable
      :  ?ctx:Guardian__Persistence.context
      -> t
      -> ( [> `Invitation ] Guard.AuthorizableTarget.t
         , Pool_common.Message.error )
         Lwt_result.t

    type t

    val equal : t -> t -> bool
    val pp : Format.formatter -> t -> unit
    val show : t -> string
  end
end

module ShowUp : sig
  include Pool_common.Model.BooleanSig

  val init : t
end

module Participated : sig
  include Pool_common.Model.BooleanSig

  val init : t
end

module MatchesFilter : sig
  type t

  val init : t
end

module CanceledAt : sig
  type t

  val init : t
  val create_now : unit -> t
  val value : t -> Ptime.t option
end

type t =
  { id : Pool_common.Id.t
  ; contact : Contact.t
  ; show_up : ShowUp.t
  ; participated : Participated.t
  ; matches_filter : MatchesFilter.t
  ; canceled_at : CanceledAt.t
  ; created_at : Pool_common.CreatedAt.t
  ; updated_at : Pool_common.UpdatedAt.t
  }

val pp : Format.formatter -> t -> unit
val equal : t -> t -> bool

module Public : sig
  type t =
    { id : Pool_common.Id.t
    ; canceled_at : CanceledAt.t
    }
end

val find
  :  Pool_database.Label.t
  -> Pool_common.Id.t
  -> (t, Pool_common.Message.error) result Lwt.t

val find_by_experiment_and_contact_opt
  :  Pool_database.Label.t
  -> Pool_common.Id.t
  -> Contact.t
  -> Public.t option Lwt.t

val find_by_session
  :  Pool_database.Label.t
  -> Pool_common.Id.t
  -> (t list, Pool_common.Message.error) result Lwt.t

val find_uncanceled_by_session
  :  Pool_database.Label.t
  -> Pool_common.Id.t
  -> (t list, Pool_common.Message.error) result Lwt.t

type create =
  { contact : Contact.t
  ; session_id : Pool_common.Id.t
  }

type event =
  | Canceled of t
  | Created of create
  | Participated of t * Participated.t
  | ShowedUp of t * ShowUp.t

val handle_event : Pool_database.Label.t -> event -> unit Lwt.t
val equal_event : event -> event -> bool
val pp_event : Format.formatter -> event -> unit

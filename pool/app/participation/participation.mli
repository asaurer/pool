module ShowUp : sig
  type t

  val schema
    :  unit
    -> (Pool_common.Message.error, t) Pool_common.Utils.PoolConformist.Field.t

  val init : t
  val create : bool -> t
end

module Participated : sig
  type t

  val schema
    :  unit
    -> (Pool_common.Message.error, t) Pool_common.Utils.PoolConformist.Field.t

  val init : t
  val create : bool -> t
end

module MatchesFilter : sig
  type t

  val init : t
end

module CanceledAt : sig
  type t

  val init : t
  val create_now : unit -> t
end

type t =
  { id : Pool_common.Id.t
  ; participant : Participant.t
  ; show_up : ShowUp.t
  ; participated : Participated.t
  ; matches_filter : MatchesFilter.t
  ; canceled_at : CanceledAt.t
  ; created_at : Pool_common.CreatedAt.t
  ; updated_at : Pool_common.UpdatedAt.t
  }

val pp : Format.formatter -> t -> unit
val equal : t -> t -> bool

val find
  :  Pool_database.Label.t
  -> Pool_common.Id.t
  -> (Entity.t, Pool_common.Message.error) result Lwt.t

type create =
  { participant : Participant.t
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

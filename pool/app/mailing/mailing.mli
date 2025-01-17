module Id : sig
  include module type of Pool_common.Id

  val to_common : t -> Pool_common.Id.t
end

module StartAt : sig
  include Pool_common.Model.BaseSig

  val create : Ptime.t -> (t, Pool_common.Message.error) result
  val value : t -> Ptime.t
  val to_human : t -> string

  val schema
    :  unit
    -> (Pool_common.Message.error, t) Pool_common.Utils.PoolConformist.Field.t
end

module EndAt : sig
  include Pool_common.Model.BaseSig

  val create : Ptime.t -> (t, Pool_common.Message.error) result
  val value : t -> Ptime.t
  val to_human : t -> string

  val schema
    :  unit
    -> (Pool_common.Message.error, t) Pool_common.Utils.PoolConformist.Field.t
end

module Rate : sig
  include Pool_common.Model.IntegerSig

  val default : t
end

module Distribution : sig
  type sortable_field =
    | AssignmentCount
    | Firstname
    | InvitationCount
    | Lastname

  val all_sortable_fields : sortable_field list
  val pp_sortable_field : Format.formatter -> sortable_field -> unit
  val show_sortable_field : sortable_field -> string
  val equal_sortable_field : sortable_field -> sortable_field -> bool
  val read_sortable_field : string -> sortable_field

  val sortable_field_to_string
    :  Pool_common.Language.t
    -> sortable_field
    -> string

  module SortOrder : sig
    type t =
      | Ascending
      | Descending

    val equal : t -> t -> bool
    val pp : Format.formatter -> t -> unit
    val show : t -> string
    val to_human : t -> Pool_common.Language.t -> string
    val read : string -> t
    val create : string -> (t, Pool_common.Message.error) result
    val label : t -> string
    val all : t list
    val default : t

    val schema
      :  unit
      -> (Pool_common.Message.error, t) Pool_common.Utils.PoolConformist.Field.t
  end

  type t = (sortable_field * SortOrder.t) list

  val equal : t -> t -> bool
  val pp : Format.formatter -> t -> unit
  val show : t -> string
  val create : (sortable_field * SortOrder.t) list -> t
  val value : t -> (sortable_field * SortOrder.t) list
  val t_of_yojson : Yojson.Safe.t -> t
  val yojson_of_t : t -> Yojson.Safe.t
  val get_order_element : t -> string

  val schema
    :  unit
    -> (Pool_common.Message.error, t) Pool_common.Utils.PoolConformist.Field.t

  val of_urlencoded_list
    :  string list
    -> (string, Pool_common.Message.error) result
end

type t =
  { id : Id.t
  ; start_at : StartAt.t
  ; end_at : EndAt.t
  ; rate : Rate.t
  ; distribution : Distribution.t option
  ; created_at : Pool_common.CreatedAt.t
  ; updated_at : Pool_common.UpdatedAt.t
  }

val pp : Format.formatter -> t -> unit
val show : t -> string
val equal : t -> t -> bool
val per_minutes : CCInt.t -> t -> CCFloat.t
val total : t -> int

val create
  :  ?id:Id.t
  -> StartAt.t
  -> EndAt.t
  -> Rate.t
  -> Distribution.t option
  -> (t, Pool_common.Message.error) result

type update =
  { start_at : StartAt.t
  ; end_at : EndAt.t
  ; rate : Rate.t
  ; distribution : Distribution.t option
  }

val equal_update : update -> update -> bool
val pp_update : Format.formatter -> update -> unit
val show_update : update -> string

type event =
  | Created of (t * Experiment.Id.t)
  | Updated of (update * t)
  | Deleted of t
  | Stopped of t

val equal_event : event -> event -> bool
val pp_event : Format.formatter -> event -> unit
val show_event : event -> string
val handle_event : Pool_database.Label.t -> event -> unit Lwt.t

val find
  :  Pool_database.Label.t
  -> Id.t
  -> (t, Pool_common.Message.error) Lwt_result.t

val find_by_experiment
  :  Pool_database.Label.t
  -> Experiment.Id.t
  -> t list Lwt.t

val find_overlaps : Pool_database.Label.t -> t -> t list Lwt.t
val find_current : Pool_database.Label.t -> t list Lwt.t

module Guard : sig
  module Target : sig
    val to_authorizable
      :  ?ctx:Guardian__Persistence.context
      -> t
      -> ( [> `Mailing ] Guard.AuthorizableTarget.t
         , Pool_common.Message.error )
         Lwt_result.t

    type t

    val equal : t -> t -> bool
    val pp : Format.formatter -> t -> unit
    val show : t -> string
  end
end

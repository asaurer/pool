module Url : sig
  include Pool_common.Model.StringSig
end

module Label : sig
  include Pool_common.Model.StringSig

  val of_string : string -> t
end

type t =
  { url : Url.t
  ; label : Label.t
  }

val root : Label.t
val equal : t -> t -> bool
val pp : Format.formatter -> t -> unit
val create : string -> string -> (t, Pool_common.Message.error) result
val add_pool : t -> unit
val read_pool : t -> Label.t

module Repo : sig
  module Url : sig
    type t = Url.t

    val t : t Caqti_type.t
  end

  module Label : sig
    type t = Label.t

    val t : t Caqti_type.t
  end

  val t : t Caqti_type.t
end

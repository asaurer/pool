open Sexplib.Conv
module PoolError = Entity_message

(* TODO [aerben] to get more type-safety, every entity should have its own ID *)
module Id = struct
  type t = string [@@deriving eq, show, sexp]

  let create () = Uuidm.v `V4 |> Uuidm.to_string
  let of_string m = m
  let value m = m

  let schema () =
    Pool_common_utils.schema_decoder
      (Utils.fcn_ok of_string)
      value
      PoolError.Field.Id
  ;;
end

module Language = struct
  type t =
    | En [@name "EN"]
    | De [@name "DE"]
  [@@deriving eq, show, yojson, sexp]

  let code = function
    | En -> "EN"
    | De -> "DE"
  ;;

  let of_string = function
    | "EN" -> Ok En
    | "DE" -> Ok De
    | _ -> Error PoolError.(Invalid Field.Language)
  ;;

  let label country_code = country_code |> code |> Utils.Countries.find

  let schema () =
    Pool_common_utils.schema_decoder of_string code PoolError.Field.Language
  ;;

  let all () = [ En; De ]
  let all_codes () = [ En; De ] |> CCList.map code

  let field_of_t =
    let open Entity_message.Field in
    function
    | En -> LanguageEn
    | De -> LanguageDe
  ;;

  (* TODO: Is there a better way the supressing the warning 4 for the whole
     module? *)
end [@warning "-4"]

module Version = struct
  type t = int [@@deriving eq, show, yojson]

  let value m = m
  let create () = 0
  let of_int i = i
  let increment m = m + 1
end

module CreatedAt = struct
  type t = Ptime.t [@@deriving eq, show]

  let create = Ptime_clock.now
  let value m = m
  let sexp_of_t = Utils_time.ptime_to_sexp
end

module UpdatedAt = struct
  type t = Ptime.t [@@deriving eq, show]

  let create = Ptime_clock.now
  let value m = m
  let sexp_of_t = Utils_time.ptime_to_sexp
end

module File = struct
  module Name = struct
    type t = string [@@deriving eq, show, sexp_of]

    let create m =
      if CCString.is_empty m
      then Error PoolError.(Invalid Field.Filename)
      else Ok m
    ;;

    let value m = m
  end

  module Size = struct
    type t = int [@@deriving eq, show, sexp_of]

    let create m =
      let open CCInt.Infix in
      if m >= CCInt.zero then Ok m else Error PoolError.(Invalid Field.Filesize)
    ;;

    let value m = m
  end

  module Mime = struct
    type t =
      | Css
      | Gif
      | Ico
      | Jpeg
      | Png
      | Svg
      | Webp
    [@@deriving eq, show, sexp_of]

    let of_string = function
      | "text/css" -> Ok Css
      | "image/gif" -> Ok Gif
      | "image/vnd.microsoft.icon" -> Ok Ico
      | "image/jpeg" -> Ok Jpeg
      | "image/png" -> Ok Png
      | "image/svg+xml" -> Ok Svg
      | "image/webp" -> Ok Webp
      | _ -> Error PoolError.(Invalid Field.FileMimeType)
    ;;

    let to_string = function
      | Css -> "text/css"
      | Gif -> "image/gif"
      | Ico -> "image/vnd.microsoft.icon"
      | Jpeg -> "image/jpeg"
      | Png -> "image/png"
      | Svg -> "image/svg+xml"
      | Webp -> "image/webp"
    ;;

    let of_filename filename =
      match filename |> Filename.extension with
      | ".css" -> Ok Css
      | ".gif" -> Ok Gif
      | ".ico" -> Ok Ico
      | ".jpeg" | ".jpg" -> Ok Jpeg
      | ".png" -> Ok Png
      | ".svg" -> Ok Svg
      | ".webp" -> Ok Webp
      | _ -> Error PoolError.(Invalid Field.FileMimeType)
    ;;
  end

  type t =
    { id : Id.t
    ; name : Name.t
    ; size : Size.t
    ; mime_type : Mime.t
    ; created_at : CreatedAt.t
    ; updated_at : UpdatedAt.t
    }
  [@@deriving show, eq, sexp_of]

  let id m = m.id
  let size m = m.size

  let path m =
    Sihl.Web.externalize_path
      (Format.asprintf "/custom/assets/%s/%s" m.id m.name)
  ;;
end

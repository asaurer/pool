module Countries = Countries
module Database = Database
module LanguageCodes = Language_codes

let todo _ = failwith "todo"
let fcn_ok fcn m = m |> fcn |> CCResult.pure

module Lwt_result = struct
  include Lwt_result

  module Infix = struct
    include Infix

    let ( >== ) = Lwt_result.bind_result
    let ( >> ) m k = m >>= fun _ -> k
    let ( |>> ) = Lwt_result.bind_lwt
    let ( >|> ) = Lwt.bind
    let ( ||> ) m k = Lwt.map k m
  end
end

module Url = struct
  let public_host =
    let open CCOption in
    let decode_host url =
      let uri = url |> Uri.of_string in
      match Uri.host uri, Uri.port uri with
      | Some host, None -> Some host
      | Some host, Some port -> Some (Format.asprintf "%s:%d" host port)
      | None, _ -> None
    in
    Sihl.Configuration.read_string "PUBLIC_URL" >>= decode_host
  ;;
end

module Bool = struct
  let to_result err value =
    match value with
    | true -> Ok ()
    | false -> Error err
  ;;
end

module Html = struct
  (* placed here due to circular dependency between email and http_utils
     library *)
  let handle_line_breaks finally_fcn str =
    let open Tyxml.Html in
    finally_fcn
    @@
    match
      str
      |> CCString.split ~by:"\n"
      |> CCList.map (CCString.split ~by:"\\n")
      |> CCList.flatten
    with
    | [] -> []
    | head :: tail ->
      CCList.fold_left
        (fun html str -> html @ [ br (); txt str ])
        [ txt head ]
        tail
  ;;
end

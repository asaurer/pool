let print = Entity.print

type t =
  | And of t list [@printer print "and"]
  | Or of t list [@printer print "or"]
  | Not of t [@printer print "not"]
  | Pred of Entity.Predicate.human [@printer print "pred"]
[@@deriving show { with_path = false }]

let init ?key ?operator ?value () : t =
  Pred (Entity.Predicate.create_human ?key ?operator ?value ())
;;

let value_of_yojson_opt (yojson : Yojson.Safe.t) =
  let open CCOption in
  let open CCFun in
  match yojson with
  | `Assoc [ (key, value) ] ->
    (match key, value with
     | "list", `List values ->
       values
       |> CCList.filter_map (Entity.single_value_of_yojson %> of_result)
       |> Entity.lst
       |> CCOption.pure
     | _ -> Entity.single_value_of_yojson yojson |> of_result >|= Entity.single)
  | _ -> None
;;

let predicate_of_yojson key_list (yojson : Yojson.Safe.t) =
  let open Entity in
  let open Helper in
  match yojson with
  | `Assoc assoc ->
    let open CCFun in
    let open CCOption in
    let go key of_yojson =
      assoc |> CCList.assoc_opt ~eq:CCString.equal key >>= of_yojson
    in
    let key =
      go key_string (Key.of_yojson %> of_result) >>= Key.to_human key_list
    in
    let operator = go operator_string (Operator.of_yojson %> of_result) in
    let value = go value_string value_of_yojson_opt in
    Predicate.create_human ?key ?operator ?value () |> CCResult.pure
  | _ -> Error Pool_common.Message.(Invalid Field.Predicate)
;;

let rec of_yojson (key_list : Entity.Key.human list) json
  : (t, Pool_common.Message.error) result
  =
  let open CCResult in
  let error = Pool_common.Message.(Invalid Field.Filter) in
  let of_yojson = of_yojson key_list in
  let of_list to_predicate filters =
    filters |> CCList.map of_yojson |> CCList.all_ok >|= to_predicate
  in
  match json with
  | `Assoc [ (key, filter) ] ->
    (match key, filter with
     | "and", `List filters -> of_list (fun lst -> And lst) filters
     | "or", `List filters -> of_list (fun lst -> Or lst) filters
     | "not", f -> f |> of_yojson >|= fun p -> Not p
     | "pred", p -> p |> predicate_of_yojson key_list >|= fun p -> Pred p
     | _ -> Error error)
  | _ -> Error error
;;
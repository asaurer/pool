let get_or_failwith = Pool_common.Utils.get_or_failwith

let locations =
  let open Pool_location in
  [ ( "Eiger"
    , None
    , Some (None, "Eiger", None, "Pfaffacherweg 93", "9054", "Schlatt-haslen")
    , None
    , Status.Active )
  ; ( "Mönch"
    , None
    , Some
        ( Some "Schweizer Alpen"
        , "Mönch"
        , None
        , "Mülhauserstrasse 139"
        , "3995"
        , "Mühlebach" )
    , None
    , Status.Active )
  ; ( "Jungfrau"
    , None
    , Some (None, "Jungfrau", None, "Möhe 63", "8858", "Innerthal")
    , None
    , Status.Maintenance )
  ; ( "Matterhorn"
    , None
    , Some
        ( Some "Schweizer Alpen"
        , "Matterhorn"
        , None
        , "Möhe 146"
        , "6476"
        , "Intschi" )
    , None
    , Status.Active )
  ; ( "Bernina"
    , None
    , Some (None, "Bernina", None, "Untere Bahnhofstrasse 132", "6965", "Cadro")
    , None
    , Status.Active )
  ; ( "Calanda"
    , None
    , Some (None, "Calanda", None, "Hasenbühlstrasse 88", "8340", "Bossikon")
    , None
    , Status.Closed )
  ]
  |> CCList.map (fun (label, description, address, link, status) ->
       let address =
         match address with
         | Some (institution, room, building, street, zip, city) ->
           Address.Mail.create institution room building street zip city
           |> Pool_common.Utils.get_or_failwith
           |> Address.physical
         | None -> Address.Virtual
       in
       create label description address link status []
       |> Pool_common.Utils.get_or_failwith)
;;

let create pool =
  let open Pool_location in
  default_values @ locations
  |> CCList.map created
  |> Lwt_list.iter_s (handle_event pool)
;;

module HttpUtils = Http_utils
module Message = HttpUtils.Message
module Field = Pool_common.Message.Field

let create_layout req = General.create_tenant_layout req

let id req field encode =
  Sihl.Web.Router.param req @@ Field.show field |> encode
;;

let index req =
  let open Utils.Lwt_result.Infix in
  let result ({ Pool_context.database_label; _ } as context) =
    Utils.Lwt_result.map_error (fun err -> err, "/admin/dashboard")
    @@ let%lwt location_list = Pool_location.find_all database_label in
       Page.Admin.Location.index location_list context
       |> create_layout ~active_navigation:"/admin/locations" req context
       >|+ Sihl.Web.Response.of_html
  in
  result |> HttpUtils.extract_happy_path req
;;

let new_form req =
  let open Utils.Lwt_result.Infix in
  let result context =
    Utils.Lwt_result.map_error (fun err -> err, "/admin/locations")
    @@
    let flash_fetcher key = Sihl.Web.Flash.find key req in
    Page.Admin.Location.form context flash_fetcher
    |> create_layout req context
    >|+ Sihl.Web.Response.of_html
  in
  result |> HttpUtils.extract_happy_path req
;;

let create req =
  let open Utils.Lwt_result.Infix in
  let%lwt urlencoded = Sihl.Web.Request.to_urlencoded req in
  let result { Pool_context.database_label; _ } =
    Utils.Lwt_result.map_error (fun err ->
      ( err
      , "/admin/locations/create"
      , [ HttpUtils.urlencoded_to_flash urlencoded ] ))
    @@
    let tags = Logger.req req in
    let events =
      let open CCResult.Infix in
      let open Cqrs_command.Location_command.Create in
      urlencoded
      |> HttpUtils.format_request_boolean_values [ Field.(Virtual |> show) ]
      |> HttpUtils.remove_empty_values
      |> decode
      >>= handle ~tags
      |> Lwt_result.lift
    in
    let handle events =
      let%lwt () =
        Lwt_list.iter_s (Pool_event.handle_event ~tags database_label) events
      in
      Http_utils.redirect_to_with_actions
        "/admin/locations"
        [ Message.set ~success:[ Pool_common.Message.(Created Field.Location) ]
        ]
    in
    events |>> handle
  in
  result |> HttpUtils.extract_happy_path_with_actions req
;;

let new_file req =
  let open Utils.Lwt_result.Infix in
  let open Pool_location in
  let id = id req Field.Location Id.of_string in
  let result ({ Pool_context.database_label; _ } as context) =
    Utils.Lwt_result.map_error (fun err ->
      err, id |> Id.value |> Format.asprintf "/admin/locations/%s/files/create")
    @@ let* location = find database_label id in
       let labels = Mapping.Label.all in
       let languages = Pool_common.Language.all in
       Page.Admin.Location.file_form labels languages location context
       |> create_layout req context
       >|+ Sihl.Web.Response.of_html
  in
  result |> HttpUtils.extract_happy_path req
;;

let add_file req =
  let open Utils.Lwt_result.Infix in
  let id =
    HttpUtils.get_field_router_param req Field.Location
    |> Pool_location.Id.of_string
  in
  let path =
    id |> Pool_location.Id.value |> Format.asprintf "/admin/locations/%s"
  in
  let result { Pool_context.database_label; _ } =
    Utils.Lwt_result.map_error (fun err ->
      err, Format.asprintf "%s/files/create" path)
    @@ let* location = Pool_location.find database_label id in
       let%lwt multipart_encoded =
         Sihl.Web.Request.to_multipart_form_data_exn req
       in
       let* files =
         HttpUtils.File.upload_files
           database_label
           [ Field.(FileMapping |> show) ]
           req
       in
       let tags = Logger.req req in
       let finalize = function
         | Ok resp -> Lwt.return_ok resp
         | Error err ->
           let%lwt () =
             Lwt_list.iter_s
               (fun (_, asset_id) ->
                 asset_id
                 |> Service.Storage.delete
                      ~ctx:(Pool_tenant.to_ctx database_label))
               files
           in
           Logs.err (fun m -> m "One of the events failed while adding a file");
           Lwt.return_error err
       in
       let events =
         let open CCResult.Infix in
         let open Cqrs_command.Location_command.AddFile in
         files @ multipart_encoded
         |> HttpUtils.File.multipart_form_data_to_urlencoded
         |> decode
         >>= handle ~tags location
         |> Lwt_result.lift
       in
       let handle events =
         let%lwt () =
           Lwt_list.iter_s (Pool_event.handle_event ~tags database_label) events
         in
         Http_utils.redirect_to_with_actions
           path
           [ Message.set
               ~success:[ Pool_common.Message.(Created Field.FileMapping) ]
           ]
       in
       events >|> finalize |>> handle
  in
  result |> HttpUtils.extract_happy_path req
;;

let asset req =
  let open Sihl.Contract.Storage in
  let id = id req Pool_common.Message.Field.File Pool_common.Id.of_string in
  let result { Pool_context.database_label; _ } =
    let ctx = Pool_tenant.to_ctx database_label in
    let%lwt file = Service.Storage.find ~ctx (Pool_common.Id.value id) in
    let%lwt content = Service.Storage.download_data_base64 ~ctx file in
    let mime = file.file.mime in
    let content = content |> Base64.decode_exn in
    Sihl.Web.Response.of_plain_text content
    |> Sihl.Web.Response.set_content_type mime
    |> Lwt.return_ok
  in
  result |> HttpUtils.extract_happy_path req
;;

let detail edit req =
  let open Utils.Lwt_result.Infix in
  let error_path = "/admin/locations" in
  let result ({ Pool_context.database_label; language; _ } as context) =
    Utils.Lwt_result.map_error (fun err -> err, error_path)
    @@
    let id = id req Field.Location Pool_location.Id.of_string in
    let* location = Pool_location.find database_label id in
    let* sessions = Session.find_all_public_by_location database_label id in
    let add_experiment_title session =
      let open Pool_common in
      let%lwt title =
        Session.find_experiment_id_and_title
          database_label
          session.Session.Public.id
      in
      ( session
      , title
        |> CCResult.get_or
             ~default:
               ( Experiment.Id.create ()
               , Utils.error_to_string
                   language
                   Message.(NotFound Field.Experiment) ) )
      |> Lwt.return
    in
    let%lwt session_list = Lwt_list.map_s add_experiment_title sessions in
    let states = Pool_location.Status.all in
    Page.Admin.Location.(
      match edit with
      | false -> detail location context session_list
      | true ->
        let flash_fetcher key = Sihl.Web.Flash.find key req in
        form ~location ~states context flash_fetcher)
    |> Lwt.return_ok
    >>= create_layout req context
    >|+ Sihl.Web.Response.of_html
  in
  result |> HttpUtils.extract_happy_path req
;;

let show = detail false
let edit = detail true

let update req =
  let open Utils.Lwt_result.Infix in
  let result { Pool_context.database_label; _ } =
    let id = id req Field.Location Pool_location.Id.of_string in
    let%lwt urlencoded = Sihl.Web.Request.to_urlencoded req in
    let detail_path =
      id |> Pool_location.Id.value |> Format.asprintf "/admin/locations/%s"
    in
    Utils.Lwt_result.map_error (fun err ->
      ( err
      , Format.asprintf "%s/edit" detail_path
      , [ HttpUtils.urlencoded_to_flash urlencoded ] ))
    @@ let* location = Pool_location.find database_label id in
       let tags = Logger.req req in
       let events =
         let open CCResult.Infix in
         let open Cqrs_command.Location_command.Update in
         urlencoded
         |> HttpUtils.format_request_boolean_values [ Field.(Virtual |> show) ]
         |> HttpUtils.remove_empty_values
         |> decode
         >>= handle ~tags location
         |> Lwt_result.lift
       in
       let handle events =
         let%lwt () =
           Lwt_list.iter_s (Pool_event.handle_event ~tags database_label) events
         in
         Http_utils.redirect_to_with_actions
           detail_path
           [ Message.set
               ~success:[ Pool_common.Message.(Updated Field.Location) ]
           ]
       in
       events |>> handle
  in
  result |> HttpUtils.extract_happy_path_with_actions req
;;

let delete req =
  let result { Pool_context.database_label; _ } =
    let location_id = id req Field.Location Pool_location.Id.of_string in
    let mapping_id =
      id req Field.FileMapping Pool_location.Mapping.Id.of_string
    in
    let path =
      location_id
      |> Pool_location.Id.value
      |> Format.asprintf "/admin/locations/%s"
    in
    Utils.Lwt_result.map_error (fun err -> err, path)
    @@
    let open Utils.Lwt_result.Infix in
    let tags = Logger.req req in
    let* events =
      mapping_id
      |> Cqrs_command.Location_command.DeleteFile.handle ~tags
      |> Lwt_result.lift
    in
    let%lwt () = Pool_event.handle_events ~tags database_label events in
    Http_utils.redirect_to_with_actions
      path
      [ Message.set ~success:[ Pool_common.Message.(Deleted Field.File) ] ]
    |> Lwt_result.ok
  in
  result |> HttpUtils.extract_happy_path req
;;

module Access : sig
  include Helpers.AccessSig

  val create_file : Rock.Middleware.t
  val read_file : Rock.Middleware.t
  val delete_file : Rock.Middleware.t
end = struct
  module Field = Pool_common.Message.Field
  module LocationCommand = Cqrs_command.Location_command

  let file_effects =
    Middleware.Guardian.id_effects Pool_location.Mapping.Id.of_string Field.File
  ;;

  let location_effects =
    Middleware.Guardian.id_effects Pool_location.Id.of_string Field.Location
  ;;

  let index =
    Middleware.Guardian.validate_admin_entity [ `Read, `TargetEntity `Location ]
  ;;

  let create =
    LocationCommand.Create.effects |> Middleware.Guardian.validate_admin_entity
  ;;

  let create_file =
    [ LocationCommand.AddFile.effects ]
    |> location_effects
    |> Middleware.Guardian.validate_generic
  ;;

  let read =
    [ (fun id ->
        [ `Read, `Target (id |> Guard.Uuid.target_of Pool_location.Id.value)
        ; `Read, `TargetEntity `Location
        ])
    ]
    |> location_effects
    |> Middleware.Guardian.validate_generic
  ;;

  let read_file =
    [ (fun id ->
        let open Pool_location.Mapping.Id in
        [ `Read, `Target (id |> Guard.Uuid.target_of value)
        ; `Read, `TargetEntity `LocationFile
        ])
    ]
    |> file_effects
    |> Middleware.Guardian.validate_generic
  ;;

  let update =
    [ LocationCommand.Update.effects ]
    |> location_effects
    |> Middleware.Guardian.validate_generic
  ;;

  let delete = Middleware.Guardian.denied

  let delete_file =
    [ LocationCommand.DeleteFile.effects ]
    |> location_effects
    |> Middleware.Guardian.validate_generic
  ;;
end

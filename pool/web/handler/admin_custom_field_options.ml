module HttpUtils = Http_utils
module Message = HttpUtils.Message
module Url = Page.Admin.CustomFields.Url
module Field = Pool_common.Message.Field

let create_layout req = General.create_tenant_layout req

let get_option_id req =
  HttpUtils.get_field_router_param
    req
    Pool_common.Message.Field.CustomFieldOption
  |> Custom_field.SelectOption.Id.of_string
;;

let get_field_id req =
  HttpUtils.get_field_router_param req Pool_common.Message.Field.CustomField
  |> Custom_field.Id.of_string
;;

let get_custom_field fnc req =
  let%lwt custom_field =
    let open Utils.Lwt_result.Infix in
    Pool_context.find req
    |> Lwt_result.lift
    >>= fun { Pool_context.database_label; _ } ->
    Custom_field.find database_label (req |> get_field_id)
  in
  match custom_field with
  | Ok field -> field |> fnc req
  | Error err ->
    Http_utils.redirect_to_with_actions
      Url.fallback_path
      [ HttpUtils.Message.set ~error:[ err ] ]
;;

let form ?id req custom_field =
  let open Utils.Lwt_result.Infix in
  let result ({ Pool_context.database_label; _ } as context) =
    Utils.Lwt_result.map_error (fun err ->
      ( err
      , Url.Field.edit_path Custom_field.(model custom_field, id custom_field) ))
    @@ let* custom_field_option =
         id
         |> CCOption.map_or ~default:(Lwt_result.return None) (fun id ->
              Custom_field.find_option database_label id >|+ CCOption.pure)
       in
       let* custom_field =
         req |> get_field_id |> Custom_field.find database_label
       in
       let* sys_languages =
         Pool_context.Tenant.get_tenant_languages req |> Lwt_result.lift
       in
       let flash_fetcher key = Sihl.Web.Flash.find key req in
       Page.Admin.CustomFieldOptions.detail
         ?custom_field_option
         custom_field
         context
         sys_languages
         flash_fetcher
       |> create_layout req context
       >|+ Sihl.Web.Response.of_html
  in
  result |> HttpUtils.extract_happy_path req
;;

let new_form req = get_custom_field form req

let edit req =
  let id = req |> get_option_id in
  get_custom_field (form ~id) req
;;

let write ?id req custom_field =
  let open Utils.Lwt_result.Infix in
  let%lwt urlencoded =
    Sihl.Web.Request.to_urlencoded req ||> HttpUtils.remove_empty_values
  in
  let url_data = Custom_field.(model custom_field, id custom_field) in
  let redirect_path = Url.Field.edit_path url_data in
  let error_path =
    match id with
    | None -> Url.Option.new_path url_data
    | Some id -> Url.Option.edit_path url_data id
  in
  let field_names =
    let open Pool_common in
    let encode_lang t = t |> Language.create |> CCResult.to_opt in
    let go field =
      Admin_custom_fields.find_assocs_in_urlencoded urlencoded field
    in
    go Message.Field.Name encode_lang
  in
  let tags = Logger.req req in
  let result { Pool_context.database_label; _ } =
    Utils.Lwt_result.map_error (fun err ->
      err, error_path, [ HttpUtils.urlencoded_to_flash urlencoded ])
    @@
    let events =
      let* sys_languages =
        Pool_context.Tenant.get_tenant_languages req |> Lwt_result.lift
      in
      match id with
      | None ->
        Cqrs_command.Custom_field_option_command.Create.handle
          ~tags
          sys_languages
          custom_field
          field_names
        |> Lwt_result.lift
      | Some id ->
        let* custom_field_option = Custom_field.find_option database_label id in
        Cqrs_command.Custom_field_option_command.Update.handle
          ~tags
          sys_languages
          custom_field_option
          field_names
        |> Lwt_result.lift
    in
    let handle events =
      let%lwt () =
        Lwt_list.iter_s (Pool_event.handle_event ~tags database_label) events
      in
      let success =
        let open Pool_common.Message in
        if CCOption.is_some id
        then Updated Field.CustomFieldOption
        else Created Field.CustomFieldOption
      in
      Http_utils.redirect_to_with_actions
        redirect_path
        [ Message.set ~success:[ success ] ]
    in
    events |>> handle
  in
  result |> HttpUtils.extract_happy_path_with_actions req
;;

let create req = get_custom_field write req

let update req =
  let id = req |> get_option_id in
  get_custom_field (write ~id) req
;;

let toggle_action action req =
  let open Utils.Lwt_result.Infix in
  let handler req custom_field =
    let id = req |> get_option_id in
    let result { Pool_context.database_label; _ } =
      let redirect_path =
        Url.Field.edit_path Custom_field.(model custom_field, id custom_field)
      in
      Utils.Lwt_result.map_error (fun err -> err, redirect_path)
      @@ let* option = id |> Custom_field.find_option database_label in
         let tags = Logger.req req in
         let events =
           Lwt_result.lift
           @@
           match action with
           | `Delete ->
             option
             |> Cqrs_command.Custom_field_option_command.Destroy.handle ~tags
           | `Publish ->
             option
             |> Cqrs_command.Custom_field_option_command.Publish.handle ~tags
         in
         let success =
           let open Pool_common.Message in
           match action with
           | `Delete -> Deleted Field.CustomFieldOption
           | `Publish -> Published Field.CustomFieldOption
         in
         let handle events =
           let%lwt () = Pool_event.handle_events ~tags database_label events in
           Http_utils.redirect_to_with_actions
             redirect_path
             [ Message.set ~success:[ success ] ]
         in
         events |>> handle
    in
    result |> HttpUtils.extract_happy_path req
  in
  get_custom_field handler req
;;

let delete = toggle_action `Delete
let publish = toggle_action `Publish

module Access : sig
  include Helpers.AccessSig

  val publish : Rock.Middleware.t
end = struct
  module CustomFieldCommand = Cqrs_command.Custom_field_option_command
  module Field = Pool_common.Message.Field

  let custom_field_option_effects =
    Middleware.Guardian.id_effects
      Custom_field.SelectOption.Id.of_string
      Field.CustomFieldOption
  ;;

  let index =
    Middleware.Guardian.validate_admin_entity
      [ `Read, `TargetEntity `CustomField ]
  ;;

  let create =
    CustomFieldCommand.Create.effects
    |> Middleware.Guardian.validate_admin_entity
  ;;

  let read =
    [ (fun id ->
        let open Custom_field.SelectOption.Id in
        [ `Read, `Target (id |> Guard.Uuid.target_of value)
        ; `Read, `TargetEntity `CustomField
        ])
    ]
    |> custom_field_option_effects
    |> Middleware.Guardian.validate_generic
  ;;

  let update =
    [ CustomFieldCommand.Update.effects ]
    |> custom_field_option_effects
    |> Middleware.Guardian.validate_generic
  ;;

  let publish =
    [ CustomFieldCommand.Publish.effects ]
    |> custom_field_option_effects
    |> Middleware.Guardian.validate_generic
  ;;

  let delete =
    [ CustomFieldCommand.Destroy.effects ]
    |> custom_field_option_effects
    |> Middleware.Guardian.validate_generic
  ;;
end

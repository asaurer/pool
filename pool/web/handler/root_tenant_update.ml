module HttpUtils = Http_utils
module Message = HttpUtils.Message

let update req command success_message =
  let open Utils.Lwt_result.Infix in
  let id = Sihl.Web.Router.param req "id" in
  let redirect_path = Format.asprintf "/root/tenant/%s" id in
  let tenant () =
    Tenant.find_full (id |> Pool_common.Id.of_string)
    |> Lwt_result.map_err (fun err -> err, redirect_path)
  in
  let events tenant =
    let%lwt urlencoded = Sihl.Web.Request.to_urlencoded req in
    let events_list urlencoded =
      match command with
      | `EditDetail ->
        Cqrs_command.Tenant_command.EditDetails.decode urlencoded
        |> CCResult.map_err Utils.handle_conformist_error
        |> CCResult.flat_map
             (CCFun.flip Cqrs_command.Tenant_command.EditDetails.handle tenant)
      | `EditDatabase ->
        Cqrs_command.Tenant_command.EditDatabase.decode urlencoded
        |> CCResult.map_err Utils.handle_conformist_error
        |> CCResult.flat_map
             (CCFun.flip Cqrs_command.Tenant_command.EditDatabase.handle tenant)
    in
    urlencoded
    |> HttpUtils.format_request_boolean_values [ "disabled" ]
    |> events_list
    |> CCResult.map_err (fun err -> err, redirect_path)
    |> Lwt_result.lift
  in
  let handle events =
    let%lwt _ = Lwt_list.map_s Pool_event.handle_event events in
    Lwt.return_ok ()
  in
  let return_to_overview =
    Http_utils.redirect_to_with_actions
      redirect_path
      [ Message.set ~success:[ success_message ] ]
  in
  ()
  |> tenant
  >>= events
  >|= handle
  |>> CCFun.const return_to_overview
  >|> HttpUtils.extract_happy_path
;;

let update_detail req =
  update req `EditDetail "Tenant was successfully updated."
;;

let update_database req =
  update req `EditDatabase "Database information was successfully updated."
;;

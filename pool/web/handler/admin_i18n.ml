module HttpUtils = Http_utils
module Message = HttpUtils.Message

let create_layout req = General.create_tenant_layout req

module I18nMap = CCMap.Make (struct
  type t = I18n.Key.t

  let compare = compare
end)

let index req =
  let open Utils.Lwt_result.Infix in
  let error_path = "/" in
  let result ({ Pool_context.database_label; _ } as context) =
    Utils.Lwt_result.map_error (fun err -> err, error_path)
    @@
    let sort translations =
      let update m t =
        I18nMap.update
          (I18n.key t)
          (function
           | None -> Some [ t ]
           | Some values -> Some (t :: values))
          m
      in
      CCList.fold_left update I18nMap.empty translations
      |> I18nMap.to_seq
      |> CCList.of_seq
      |> CCList.sort (fun (k1, _) (k2, _) ->
           CCString.compare (I18n.Key.to_string k1) (I18n.Key.to_string k2))
      |> Lwt.return
    in
    let%lwt translation_list = I18n.find_all database_label () >|> sort in
    Page.Admin.I18n.list translation_list context
    |> create_layout req ~active_navigation:"/admin/i18n" context
    >|+ Sihl.Web.Response.of_html
  in
  result |> HttpUtils.extract_happy_path req
;;

let update req =
  let open Utils.Lwt_result.Infix in
  let id =
    HttpUtils.get_field_router_param req Pool_common.Message.Field.i18n
    |> Pool_common.Id.of_string
  in
  let redirect_path = Format.asprintf "/admin/i18n" in
  let result { Pool_context.database_label; _ } =
    Utils.Lwt_result.map_error (fun err -> err, redirect_path)
    @@
    let property () = I18n.find database_label id in
    let tags = Logger.req req in
    let events property =
      let open CCResult.Infix in
      let open Cqrs_command.I18n_command.Update in
      let%lwt urlencoded = Sihl.Web.Request.to_urlencoded req in
      urlencoded |> decode >>= handle ~tags property |> Lwt_result.lift
    in
    let handle events =
      let%lwt () =
        Lwt_list.iter_s (Pool_event.handle_event ~tags database_label) events
      in
      Http_utils.redirect_to_with_actions
        redirect_path
        [ Message.set ~success:[ Pool_common.Message.(Updated Field.I18n) ] ]
    in
    () |> property >>= events |>> handle
  in
  result |> HttpUtils.extract_happy_path req
;;

module Access : sig
  include Helpers.AccessSig
end = struct
  module Field = Pool_common.Message.Field
  module I18nCommand = Cqrs_command.I18n_command

  let i18n_effects =
    Middleware.Guardian.id_effects Pool_common.Id.of_string Field.I18n
  ;;

  let tenant_effects effects req context =
    (* TODO [mabiede] allow validator function to handle results *)
    let effects =
      match Pool_context.Tenant.find req with
      | Ok { Pool_context.Tenant.tenant; _ } ->
        effects |> CCList.map (fun effect -> effect tenant) |> CCList.flatten
      | Error _ -> [ `Manage, `TargetEntity `Tenant ]
    in
    context, effects
  ;;

  let tenant_i18n_effects effects req context =
    let effects =
      match Pool_context.Tenant.find req with
      | Ok { Pool_context.Tenant.tenant; _ } ->
        let id = Http_utils.find_id Pool_common.Id.of_string Field.I18n req in
        effects |> CCList.map (fun effect -> effect tenant id) |> CCList.flatten
      | Error _ -> [ `Manage, `TargetEntity `Tenant ]
    in
    context, effects
  ;;

  let index =
    Middleware.Guardian.validate_admin_entity [ `Read, `TargetEntity `I18n ]
  ;;

  let create =
    [ I18nCommand.Create.effects ]
    |> tenant_effects
    |> Middleware.Guardian.validate_generic
  ;;

  let read =
    [ (fun id ->
        [ `Read, `Target (id |> Guard.Uuid.target_of Pool_common.Id.value)
        ; `Read, `TargetEntity `I18n
        ])
    ]
    |> i18n_effects
    |> Middleware.Guardian.validate_generic
  ;;

  let update =
    [ I18nCommand.Update.effects ]
    |> tenant_i18n_effects
    |> Middleware.Guardian.validate_generic
  ;;

  let delete = Middleware.Guardian.denied
end

module Command = Cqrs_command.Participant_command
module HttpUtils = Http_utils
module Message = HttpUtils.Message

type handler = Rock.Request.t -> Rock.Response.t Lwt.t

let sign_up : handler =
 fun req ->
  let csrf = Sihl.Web.Csrf.find req |> Option.get in
  let message = Sihl.Web.Flash.find_alert req in
  let message = Option.bind message Message.of_string in
  let go = CCFun.flip Sihl.Web.Flash.find req in
  let channels = Participant.RecruitmentChannel.all () in
  let email = go "email" in
  let firstname = go "firstname" in
  let lastname = go "lastname" in
  let recruitment_channel = go "recruitment_channel" in
  let html =
    Page.Participant.sign_up
      csrf
      message
      channels
      email
      firstname
      lastname
      recruitment_channel
      ()
  in
  Sihl.Web.Response.of_html html |> Lwt.return
;;

let sign_up_create : handler =
 fun req ->
  let%lwt urlencoded = Sihl.Web.Request.to_urlencoded req in
  let%lwt result =
    let open Lwt_result.Syntax in
    let* tenant_db = General.Tenant_middleware.tenant_db_of_request req in
    (* TODO add Settings when ready *)
    (* let* allowed_email_suffixes = Settings.allowed_email_suffixes tenant_db
       in *)
    let allowed_email_suffixes = None in
    let* events =
      let open CCResult.Infix in
      Command.SignUp.decode urlencoded
      |> CCResult.map_err Utils.handle_conformist_error
      >>= Command.SignUp.handle ?allowed_email_suffixes
      |> Lwt_result.lift
    in
    let%lwt run =
      Utils.Database.with_transaction tenant_db (fun () ->
          let%lwt () = Pool_event.handle_events tenant_db events in
          HttpUtils.redirect_to_with_actions
            "/dashboard"
            [ Message.set
                ~success:
                  [ "Successfully created. An email has been sent to your \
                     email address for verification."
                  ]
            ])
    in
    Lwt.return_ok run
  in
  result
  |> CCResult.map_err (fun msg ->
         ( msg
         , "/participant/signup"
         , [ HttpUtils.urlencoded_to_flash urlencoded
           ; Message.set ~error:[ msg ]
           ] ))
  |> HttpUtils.extract_happy_path_with_actions
;;
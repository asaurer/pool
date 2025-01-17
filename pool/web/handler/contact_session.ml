module HttpUtils = Http_utils

let create_layout = Contact_general.create_layout

let show req =
  let open Utils.Lwt_result.Infix in
  let experiment_id, id =
    let open Pool_common.Message.Field in
    ( HttpUtils.find_id Experiment.Id.of_string Experiment req
    , HttpUtils.find_id Pool_common.Id.of_string Session req )
  in
  let error_path =
    Format.asprintf "/experiments/%s" (experiment_id |> Experiment.Id.value)
  in
  let result ({ Pool_context.database_label; _ } as context) =
    Utils.Lwt_result.map_error (fun err -> err, error_path)
    @@ let* contact = Pool_context.find_contact context |> Lwt_result.lift in
       let* experiment =
         Experiment.find_public database_label experiment_id contact
       in
       let* () =
         Assignment.find_by_experiment_and_contact_opt
           database_label
           experiment.Experiment.Public.id
           contact
         >|> function
         | Some _ ->
           Lwt.return_error Pool_common.Message.AlreadySignedUpForExperiment
         | None -> Lwt.return_ok ()
       in
       let* session = Session.find_public database_label id in
       Page.Contact.Experiment.Assignment.detail session experiment context
       |> Lwt.return_ok
       >>= create_layout req context
       >|+ Sihl.Web.Response.of_html
  in
  result |> HttpUtils.extract_happy_path req
;;

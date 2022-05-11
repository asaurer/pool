open Tyxml.Html

let detail session experiment Pool_context.{ language; _ } =
  let form_action =
    Format.asprintf
      "/experiments/%s/sessions/%s"
      (experiment.Experiment_type.id |> Pool_common.Id.value)
      (session.Session.Public.id |> Pool_common.Id.value)
    |> Sihl.Web.externalize_path
  in
  div
    [ h1
        [ txt
            Pool_common.(Utils.text_to_string language I18n.SessionSignUpTitle)
        ]
    ; Page_contact_sessions.public_detail session language
    ; form
        ~a:[ a_action form_action; a_method `Post ]
        [ Component.submit_element
            language
            Pool_common.Message.(Enroll)
            ~classnames:[ "button--success" ]
            ()
        ]
    ]
;;

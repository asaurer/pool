open Tyxml.Html
open Component.Input

module Partials = struct
  open Assignment

  let empty language =
    Pool_common.(
      Utils.text_to_string language (I18n.EmtpyList Message.Field.Assignments))
    |> txt
  ;;

  let contact_fullname (a : Assignment.t) = a.contact |> Contact.fullname |> txt

  let contact_email (a : Assignment.t) =
    a.contact |> Contact.email_address |> Pool_user.EmailAddress.value |> txt
  ;;

  let canceled_at (a : Assignment.t) =
    a.canceled_at
    |> CCOption.map_or ~default:"" (fun c ->
         c
         |> Assignment.CanceledAt.value
         |> Pool_common.Utils.Time.formatted_date_time)
    |> txt
  ;;

  let overview_list Pool_context.{ language; csrf; _ } experiment_id assignments
    =
    let action assignment =
      Format.asprintf
        "/admin/experiments/%s/assignments/%s/cancel"
        (experiment_id |> Experiment.Id.value)
        (assignment.Assignment.id |> Pool_common.Id.value)
      |> Sihl.Web.externalize_path
    in
    match CCList.is_empty assignments with
    | true -> p [ language |> empty ]
    | false ->
      let thead =
        (Pool_common.Message.Field.[ Name; Email; CanceledAt ]
        |> Component.Table.fields_to_txt language)
        @ [ txt "" ]
      in
      let rows =
        CCList.map
          (fun (assignment : Assignment.t) ->
            let base =
              [ assignment |> contact_fullname
              ; assignment |> contact_email
              ; assignment |> canceled_at
              ]
            in
            let cancel assignment =
              form
                ~a:[ a_action (action assignment); a_method `Post ]
                [ csrf_element csrf ()
                ; submit_element
                    language
                    (Pool_common.Message.Cancel None)
                    ~submit_type:`Error
                    ()
                ]
            in
            match assignment.canceled_at with
            | None -> base @ [ cancel assignment ]
            | Some _ -> base @ [ txt "" ])
          assignments
      in
      Component.Table.horizontal_table `Striped ~align_last_end:true ~thead rows
  ;;
end

let list assignments experiment (Pool_context.{ language; _ } as context) =
  let html =
    CCList.map
      (fun (session, assignments) ->
        div
          [ h3
              ~a:[ a_class [ "heading-3" ] ]
              [ txt (session |> Session.session_date_to_human) ]
          ; Partials.overview_list context experiment.Experiment.id assignments
          ])
      assignments
    |> div ~a:[ a_class [ "stack-lg" ] ]
  in
  Page_admin_experiments.experiment_layout
    ~hint:Pool_common.I18n.ExperimentAssignment
    language
    (Page_admin_experiments.NavLink Pool_common.I18n.Assignments)
    experiment
    ~active:Pool_common.I18n.Assignments
    html
;;

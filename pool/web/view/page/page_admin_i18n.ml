open Tyxml.Html
open Component.Input
module Message = Pool_common.Message

let list translation_list Pool_context.{ language; csrf; _ } =
  let input_element translation =
    input_element
      ~orientation:`Horizontal
      ~classnames:[ "grow" ]
      ~label_field:(Pool_common.Language.field_of_t (I18n.language translation))
      ~required:true
      ~value:(translation |> I18n.content |> I18n.Content.value)
      language
      `Text
      Pool_common.Message.Field.Translation
  in
  let textarea_element translation =
    textarea_element
      ~orientation:`Horizontal
      ~classnames:[ "grow" ]
      ~label_field:(Pool_common.Language.field_of_t (I18n.language translation))
      ~required:true
      ~value:(translation |> I18n.content |> I18n.Content.value)
      language
      Pool_common.Message.Field.Translation
  in
  let build_translations_row translation_list =
    CCList.map
      (fun (key, translations) ->
        let translations_html =
          CCList.map
            (fun translation ->
              let action =
                Sihl.Web.externalize_path
                  (Format.asprintf
                     "/admin/i18n/%s"
                     (translation |> I18n.id |> Pool_common.Id.value))
              in
              let text_input =
                match I18n.Key.is_textarea key with
                | true -> textarea_element translation
                | false -> input_element translation
              in
              form
                ~a:
                  [ a_action action
                  ; a_method `Post
                  ; a_class [ "flexrow"; "flex-gap" ]
                  ]
                [ csrf_element csrf ()
                ; text_input
                ; submit_icon ~classnames:[ "primary" ] `Save
                ])
            translations
        in
        div
          [ h2
              ~a:[ a_class [ "heading-2" ] ]
              [ txt
                  (key
                  |> I18n.Key.to_string
                  |> CCString.replace ~which:`All ~sub:"_" ~by:" "
                  |> CCString.capitalize_ascii)
              ]
          ; div ~a:[ a_class [ "stack"; "flexcolumn" ] ] translations_html
          ])
      translation_list
  in
  let translations = build_translations_row translation_list in
  div
    ~a:[ a_class [ "safety-margin"; "trim"; "measure" ] ]
    [ h1
        ~a:[ a_class [ "heading-1" ] ]
        [ txt Pool_common.(Utils.text_to_string Language.En I18n.I18nTitle) ]
    ; div ~a:[ a_class [ "stack-lg" ] ] translations
    ]
;;

open Tyxml.Html

let input_element = Component.input_element

let list csrf translation_list message () =
  let open I18n in
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
                     (translation.id |> Pool_common.Id.value))
              in
              div
                [ p [ txt (translation.language |> Pool_common.Language.code) ]
                ; form
                    ~a:[ a_action action; a_method `Post ]
                    [ Component.csrf_element csrf ()
                    ; input_element
                        `Text
                        (Some "content")
                        (translation.content |> I18n.Content.value)
                    ; input_element `Submit None "Update"
                    ]
                ])
            translations
        in
        div
          [ h2
              [ txt
                  (key
                  |> CCString.replace ~which:`All ~sub:"_" ~by:" "
                  |> CCString.capitalize_ascii)
              ]
          ; div translations_html
          ])
      translation_list
  in
  let translations = build_translations_row translation_list in
  let html = div [ h1 [ txt "Translations" ]; div translations ] in
  Page_layout.create html message ()
;;

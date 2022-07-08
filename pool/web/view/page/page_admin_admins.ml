open Tyxml.Html

let admin_overview language admins =
  let thead = Pool_common.Message.Field.[ Some Email; Some Name; None ] in
  CCList.map
    (fun admin ->
      let open Sihl_user in
      let default_empty o = CCOption.value ~default:"" o in
      let user = Admin.Any.user admin in
      [ txt user.email
      ; txt
          (Format.asprintf
             "%s %s"
             (user.given_name |> default_empty)
             (user.name |> default_empty)
          |> CCString.trim)
      ; a
          ~a:
            [ a_href
                (Sihl.Web.externalize_path
                   (Format.asprintf "/admin/admins/%s" user.id))
            ]
          [ txt Pool_common.(Utils.control_to_string language Message.More) ]
      ])
    admins
  |> Component.Table.horizontal_table `Striped ~thead language
;;

let index Pool_context.{ language; _ } admins =
  div
    ~a:[ a_class [ "trim"; "safety-margin" ] ]
    [ h1 [ txt Pool_common.(Utils.nav_link_to_string language I18n.Admins) ]
    ; admin_overview language admins
    ]
;;

let detail Pool_context.{ language; _ } admin =
  let open Sihl.Contract.User in
  let user = Admin.Any.user admin in
  div
    ~a:[ a_class [ "trim"; "safety-margin" ] ]
    [ h1
        ~a:[ a_class [ "heading-1" ] ]
        [ txt
            (Format.asprintf
               "%s %s"
               (user.given_name |> Option.value ~default:"")
               (user.name |> Option.value ~default:""))
        ]
    ; p
        [ a
            ~a:
              [ a_href
                  (Format.asprintf "/admin/admins/%s/edit" user.id
                  |> Sihl.Web.externalize_path)
              ]
            [ txt
                Pool_common.(
                  Utils.control_to_string language Message.(Edit None))
            ]
        ]
    ]
;;

let edit _ editabe_admin =
  let open Sihl.Contract.User in
  let user = Admin.Any.user editabe_admin in
  div
    ~a:[ a_class [ "trim"; "safety-margin" ] ]
    [ h1
        ~a:[ a_class [ "heading-1" ] ]
        [ txt
            (Format.asprintf
               "%s %s"
               (user.given_name |> Option.value ~default:"")
               (user.name |> Option.value ~default:""))
        ]
    ]
;;
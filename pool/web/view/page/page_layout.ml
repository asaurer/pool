open Tyxml.Html
module Message = Page_message

let charset = meta ~a:[ a_charset "utf8" ] ()

let viewport =
  meta
    ~a:[ a_name "viewport"; a_content "width=device-width, initial-scale=1" ]
    ()
;;

let favicon =
  link
    ~rel:[ `Icon ]
    ~href:(Sihl.Web.externalize_path "/assets/images/favicon.png")
    ()
;;

let global_stylesheet =
  link
    ~rel:[ `Stylesheet ]
    ~href:(Sihl.Web.externalize_path "/assets/index.css")
    ()
;;

let header title ?(children = []) () =
  header
    ~a:[ a_class [ "site-header"; "flex-box"; "flex--row"; "flex--between" ] ]
    [ h1 ~a:[ a_style "margin: 0;" ] [ txt title ]; div children ]
;;

let footer title =
  footer
    ~a:[ a_class [ "site-footer"; "flex-box"; "flex--row"; "flex--center" ] ]
    [ p [ txt title ] ]
;;

let build_nav_link (url, title) language query_language active_navigation =
  let txt_to_string m =
    Pool_common.Utils.nav_link_to_string language m |> txt
  in
  let nav_link =
    a
      ~a:[ a_href (Http_utils.externalize_path_with_lang query_language url) ]
      [ txt_to_string title ]
  in
  active_navigation
  |> CCOption.map_or ~default:nav_link (fun active ->
         if CCString.equal active url
         then span [ txt_to_string title ]
         else nav_link)
;;

module Tenant = struct
  let i18n_links tenant_languages active_lang =
    div
      ~a:[]
      (CCList.map
         (fun tenant_language ->
           let label = Pool_common.Language.code tenant_language in
           if Pool_common.Language.equal tenant_language active_lang
           then span [ txt label ]
           else
             a
               ~a:
                 [ a_href
                     Pool_common.(
                       Message.(
                         add_field_query_params
                           ""
                           [ ( Field.Language
                             , Language.code tenant_language
                               |> CCString.lowercase_ascii )
                           ]))
                 ]
               [ txt label ])
         tenant_languages)
  ;;

  (* TODO[timhub]: * differ between login status *)
  let navigation layout_context language query_language active_navigation =
    let nav_links =
      let open Pool_common.I18n in
      (match layout_context with
      | `Subject -> [ "/experiments", Experiments ]
      | `Admin ->
        [ "/admin/dashboard", Dashboard
        ; "/admin/experiments", Experiments
        ; "/admin/settings", Settings
        ; "/admin/i18n", I18n
        ])
      |> CCList.map (fun item ->
             build_nav_link item language query_language active_navigation)
    in
    nav nav_links
  ;;

  let create_layout
      layout_context
      children
      Pool_context.Tenant.{ tenant_languages; tenant }
      message
      active_lang
      query_language
      active_navigation
    =
    let title_text = Pool_tenant.(Title.value tenant.title) in
    let page_title =
      title (txt (Format.asprintf "%s - %s" title_text "Pool Tool"))
    in
    let custom_stylesheet =
      link
        ~rel:[ `Stylesheet ]
        ~href:(Sihl.Web.externalize_path "/custom/assets/index.css")
        ()
    in
    let message = Message.create message active_lang () in
    let scripts =
      script
        ~a:[ a_src (Sihl.Web.externalize_path "/assets/index.js"); a_defer () ]
        (txt "")
    in
    let header_content =
      let navigation =
        navigation layout_context active_lang query_language active_navigation
      in
      (fun html -> [ div ~a:[ a_class [ "flex-box"; "flex--row" ] ] html ])
      @@
      match layout_context with
      | `Admin -> [ navigation ]
      | `Subject -> [ navigation; i18n_links tenant_languages active_lang ]
    in
    let content = main ~a:[ a_class [ "site-main" ] ] [ message; children ] in
    html
      (head
         page_title
         [ charset; viewport; custom_stylesheet; global_stylesheet; favicon ])
      (body
         [ header title_text ~children:header_content ()
         ; content
         ; footer title_text
         ; scripts
         ])
  ;;
end

let create_root_layout children message lang ?active_navigation () =
  (* TODO[timhub]: * differ between login status *)
  let navigation =
    let nav_links =
      let open Pool_common.I18n in
      [ "/root/tenants", Tenants ]
      |> CCList.map (fun item ->
             build_nav_link item Pool_common.Language.En None active_navigation)
    in
    nav nav_links
  in
  let title_text = "Pool Tool" in
  let page_title = title (txt title_text) in
  let message = Message.create message lang () in
  let scripts =
    script
      ~a:[ a_src (Sihl.Web.externalize_path "/assets/index.js"); a_defer () ]
      (txt "")
  in
  let content = main ~a:[ a_class [ "site-main" ] ] [ message; children ] in
  html
    (head page_title [ charset; viewport; global_stylesheet; favicon ])
    (body
       [ header title_text ~children:[ navigation ] ()
       ; content
       ; footer title_text
       ; scripts
       ])
;;

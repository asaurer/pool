module CustomMiddleware = Middleware
open Sihl.Web

let add_key ?(prefix = "") ?(suffix = "") field =
  let open Pool_common.Message.Field in
  [ prefix; field |> url_key; suffix ]
  |> CCList.filter (fun m -> m |> CCString.is_empty |> not)
  |> CCString.concat "/"
;;

let global_middlewares =
  [ Middleware.id ~id:(fun () -> CCString.sub (Sihl.Random.base64 12) 0 10) ()
  ; CustomMiddleware.Error.error ()
  ; Middleware.trailing_slash ()
  ; Middleware.static_file ()
  ; Middleware.csrf ()
  ; Middleware.flash ()
  ; Opium.Middleware.content_length
  ; Opium.Middleware.etag
  ; Opium.Middleware.method_override
  ]
;;

module Public = struct
  let global_routes =
    choose
      [ get "/" Handler.Public.root_redirect
      ; get "/custom/assets/:id/:filename" Handler.Public.asset
      ; get "/error" Handler.Public.error
      ]
  ;;

  let routes =
    Handler.Public.(
      choose
        ~middlewares:
          [ CustomMiddleware.Tenant.valid_tenant ()
          ; CustomMiddleware.Context.context ()
          ; CustomMiddleware.Logger.logger
          ]
        [ choose
            ~middlewares:
              [ CustomMiddleware.Guardian.require_user_type_of
                  Pool_context.UserType.[ Guest; Contact; Admin ]
              ]
            [ get "/index" index; get "/custom/assets/index.css" index_css ]
        ; choose
            ~middlewares:
              [ CustomMiddleware.Guardian.require_user_type_of
                  Pool_context.UserType.[ Guest ]
              ]
            [ get "/login" Login.login_get
            ; post "/login" Login.login_post
            ; get "/request-reset-password" Login.request_reset_password_get
            ; post "/request-reset-password" Login.request_reset_password_post
            ; get "/reset-password" Login.reset_password_get
            ; post "/reset-password" Login.reset_password_post
            ]
        ; choose
            ~middlewares:
              [ CustomMiddleware.Guardian.require_user_type_of
                  Pool_context.UserType.[ Contact; Admin ]
              ]
            [ get "/logout" Login.logout ]
        ])
  ;;
end

module Contact = struct
  module SignUp = Handler.Contact.SignUp
  module UserProfile = Handler.Contact.UserProfile
  module Experiment = Handler.Contact.Experiment
  module WaitingList = Handler.Contact.WaitingList
  module Session = Handler.Contact.Session
  module Assignment = Handler.Contact.Assignment

  let public =
    [ get "/signup" SignUp.sign_up
    ; post "/signup" SignUp.sign_up_create
    ; get "/email-confirmation" Handler.Public.email_confirmation_note
    ; get "/email-verified" SignUp.email_verification
    ; get "/termsandconditions" SignUp.terms
    ; post "/terms-accepted/:id" SignUp.terms_accept
    ]
  ;;

  let locked_routes =
    let locked =
      let experiments =
        let build_scope subdir =
          Format.asprintf
            "/%s/%s"
            Pool_common.Message.Field.(Experiment |> url_key)
            subdir
        in
        let waiting_list =
          [ post "" WaitingList.create; post "/remove" WaitingList.delete ]
        in
        let sessions =
          let open Pool_common.Message.Field in
          [ get (Session |> url_key) Session.show
          ; post (Session |> url_key) Assignment.create
          ]
        in
        [ get "" Experiment.index
        ; get Pool_common.Message.Field.(Experiment |> url_key) Experiment.show
        ; choose ~scope:(build_scope "waiting-list") waiting_list
        ; choose ~scope:(build_scope "sessions") sessions
        ]
      in
      [ get "/dashboard" Handler.Contact.dashboard
      ; get "/user/personal-details" UserProfile.personal_details
      ; get "/user/login-information" UserProfile.login_information
      ; post "/user/update" UserProfile.update
      ; post "/user/update-email" UserProfile.update_email
      ; post "/user/update-password" UserProfile.update_password
      ; choose ~scope:"/experiments" experiments
      ]
    in
    [ choose
        ~middlewares:[ CustomMiddleware.Contact.completion_in_progress () ]
        locked
    ; get "/user/completion" UserProfile.completion
    ; post "/user/completion" UserProfile.completion_post
    ]
  ;;

  let routes =
    choose
      ~middlewares:
        [ CustomMiddleware.Tenant.valid_tenant ()
        ; CustomMiddleware.Context.context ()
        ; CustomMiddleware.Logger.logger
        ]
      [ choose
          ~middlewares:
            [ CustomMiddleware.Guardian.require_user_type_of
                Pool_context.UserType.[ Guest ]
            ]
          public
      ; choose
          ~middlewares:
            [ CustomMiddleware.Guardian.require_user_type_of
                Pool_context.UserType.[ Contact ]
            ; CustomMiddleware.Contact.confirmed_and_terms_agreed ()
            ]
          locked_routes
      ]
  ;;
end

module Admin = struct
  let validate_entity action entity =
    CustomMiddleware.Guardian.validate_admin_entity
      [ action, `TargetEntity entity ]
  ;;

  let require_read = validate_entity `Read

  let middlewares =
    [ CustomMiddleware.Tenant.valid_tenant ()
    ; CustomMiddleware.Context.context ()
    ; CustomMiddleware.Logger.logger
    ; CustomMiddleware.Admin.require_admin ()
    ]
  ;;

  let routes =
    let open Pool_common.Message.Field in
    let open Handler.Admin in
    let location =
      let open Location in
      let files =
        [ get "/create" ~middlewares:[ Access.create_file ] new_file
        ; post "" ~middlewares:[ Access.create_file ] add_file
        ; choose
            ~scope:(add_key File)
            [ get "" ~middlewares:[ Access.read_file ] asset ]
        ]
      in
      let specific =
        [ get "" ~middlewares:[ Access.index ] show
        ; get "/edit" ~middlewares:[ Access.update ] edit
        ; post "" ~middlewares:[ Access.update ] update
        ; choose ~scope:"/files" files
        ; choose
            ~scope:(add_key ~prefix:"mapping" FileMapping)
            [ post "/delete" ~middlewares:[ Access.delete_file ] delete ]
        ]
      in
      [ get "" ~middlewares:[ Access.index ] index
      ; get "/create" ~middlewares:[ Access.create ] new_form
      ; post "" ~middlewares:[ Access.create ] create
      ; choose ~scope:(add_key Location) specific
      ]
    in
    let experiments =
      let assistants =
        let open Experiments.Users in
        let specific =
          [ post
              "assign"
              ~middlewares:[ Access.assign_assistant ]
              assign_assistant
          ; post
              "divest"
              ~middlewares:[ Access.divest_assistant ]
              divest_assistant
          ]
        in
        [ get "" ~middlewares:[ Access.index_assistants ] index_assistants
        ; choose ~scope:(url_key Admin) specific
        ]
      in
      let experimenter =
        let open Experiments.Users in
        let specific =
          [ post
              "assign"
              ~middlewares:[ Access.assign_experimenter ]
              assign_experimenter
          ; post
              "divest"
              ~middlewares:[ Access.divest_experimenter ]
              divest_experimenter
          ]
        in
        [ get "" ~middlewares:[ Access.index_experimenter ] index_experimenter
        ; choose ~scope:(url_key Admin) specific
        ]
      in
      let invitations =
        Experiments.Invitations.
          [ get "" ~middlewares:[ Access.index ] index
          ; post "" ~middlewares:[ Access.create ] create
          ; get "sent" ~middlewares:[ Access.index ] sent_invitations
          ; post
              (add_key ~suffix:"resend" Invitation)
              ~middlewares:[ Access.resend ]
              resend
          ]
      in
      let sessions =
        let open Session in
        let specific =
          [ get "" ~middlewares:[ Access.read ] show
          ; post "" ~middlewares:[ Access.update ] update
          ; get "/edit" ~middlewares:[ Access.update ] edit
          ; get "/follow-up" ~middlewares:[ Access.update ] follow_up
          ; post "/follow-up" ~middlewares:[ Access.update ] create_follow_up
          ; post "/cancel" ~middlewares:[ Access.cancel ] cancel
          ; post "/delete" ~middlewares:[ Access.delete ] delete
          ; get "/reschedule" ~middlewares:[ Access.reschedule ] reschedule_form
          ; post "/reschedule" ~middlewares:[ Access.reschedule ] reschedule
          ; get "/close" ~middlewares:[ Access.stop ] close
          ; post "/close" ~middlewares:[ Access.stop ] close_post
          ]
        in
        [ get "" ~middlewares:[ Access.index ] list
        ; get "/create" ~middlewares:[ Access.create ] new_form
        ; post "" ~middlewares:[ Access.create ] create
        ; choose ~scope:"/:session" specific
        ]
      in
      let waiting_list =
        let open Experiments.WaitingList in
        let specific =
          [ get "" ~middlewares:[ Access.read ] detail
          ; post "" ~middlewares:[ Access.update ] update
          ; post "/assign" ~middlewares:[ Access.update ] assign_contact
          ]
        in
        [ get "" ~middlewares:[ Access.index ] index
        ; choose ~scope:(WaitingList |> url_key) specific
        ]
      in
      let assignments =
        let open Experiments.Assignment in
        let specific =
          [ post "/cancel" ~middlewares:[ Access.cancel ] cancel ]
        in
        [ get "" ~middlewares:[ Access.index ] index
        ; choose ~scope:(Assignment |> url_key) specific
        ]
      in
      let mailings =
        let open Experiments.Mailings in
        let specific =
          [ get "" ~middlewares:[ Access.read ] show
          ; post "" ~middlewares:[ Access.update ] update
          ; get "/edit" ~middlewares:[ Access.update ] edit
          ; post "/stop" ~middlewares:[ Access.stop ] stop
          ; post "/delete" ~middlewares:[ Access.delete ] delete
          ]
        in
        [ get "" ~middlewares:[ Access.index ] index
        ; post "" ~middlewares:[ Access.create ] create
        ; get "/create" ~middlewares:[ Access.create ] new_form
        ; post "/search-info" ~middlewares:[ Access.update ] search_info
        ; post "/add-condition" ~middlewares:[ Access.update ] add_condition
        ; choose ~scope:(Mailing |> url_key) specific
        ]
      in
      let filter =
        Handler.Admin.Filter.
          [ post "/create" ~middlewares:[ Access.create ] create_for_experiment
          ]
      in
      let specific =
        Experiments.
          [ get "" ~middlewares:[ Access.read ] show
          ; post "" ~middlewares:[ Access.update ] update
          ; get "/edit" ~middlewares:[ Access.update ] edit
          ; post "/delete" ~middlewares:[ Access.delete ] delete
          ; get
              "/contact-count"
              ~middlewares:[ Access.read ]
              Handler.Admin.Filter.count_contacts
          ; choose ~scope:"/assistants" assistants
          ; choose ~scope:"/experimenter" experimenter
          ; choose ~scope:"/invitations" invitations
          ; choose ~scope:"/waiting-list" waiting_list
          ; choose ~scope:"/sessions" sessions
          ; choose ~scope:"/assignments" assignments
          ; choose ~scope:"/mailings" mailings
          ; choose ~scope:"/filter" filter
          ]
      in
      Experiments.
        [ get "" ~middlewares:[ Access.index ] index
        ; post "" ~middlewares:[ Access.create ] create
        ; get "/create" ~middlewares:[ Access.create ] new_form
        ; choose ~scope:(add_key Experiment) specific
        ]
    in
    let admins =
      let open Handler.Admin.Admin in
      let specific =
        [ get "" ~middlewares:[ Access.read ] detail
        ; get "/edit" ~middlewares:[ Access.update ] edit
        ]
      in
      [ get "" ~middlewares:[ Access.index ] index
      ; choose ~scope:(Admin |> url_key) specific
      ]
    in
    let contacts =
      let open Handler.Admin.Contacts in
      let specific =
        [ get "" ~middlewares:[ Access.read ] detail
        ; post "" ~middlewares:[ Access.update ] update
        ; get "/edit" ~middlewares:[ Access.update ] edit
        ]
      in
      [ get "" ~middlewares:[ Access.index ] index
      ; choose ~scope:(Contact |> url_key) specific
      ]
    in
    let filter =
      let open Handler.Admin.Filter in
      let specific =
        [ get "edit" ~middlewares:[ Access.update ] edit
        ; post "" ~middlewares:[ Access.update ] update_template
        ]
      in
      [ get "" ~middlewares:[ Access.index ] index
      ; post "" ~middlewares:[ Access.create ] create_template
      ; get "/new" ~middlewares:[ Access.create ] new_form
      ; post "/toggle-key" ~middlewares:[ Access.update ] toggle_key
      ; post
          "/toggle-predicate-type"
          ~middlewares:[ Access.update ]
          toggle_predicate_type
      ; post "/add-predicate" ~middlewares:[ Access.update ] add_predicate
      ; choose ~scope:(Filter |> url_key) specific
      ]
    in
    let custom_fields =
      let open CustomField in
      let specific =
        let options =
          let open CustomFieldOption in
          let specific =
            [ get "/edit" ~middlewares:[ Access.update ] edit
            ; post "" ~middlewares:[ Access.update ] update
            ; post "/delete" ~middlewares:[ Access.delete ] delete
            ; post "/publish" ~middlewares:[ Access.publish ] publish
            ]
          in
          [ get "/new" ~middlewares:[ Access.create ] new_form
          ; post "" ~middlewares:[ Access.create ] create
          ; choose ~scope:(CustomFieldOption |> url_key) specific
          ]
        in
        [ post "" ~middlewares:[ Access.update ] update
        ; get "/edit" ~middlewares:[ Access.update ] edit
        ; post "/publish" ~middlewares:[ Access.publish ] publish
        ; post "/delete" ~middlewares:[ Access.delete ] delete
        ; post "/sort-options" ~middlewares:[ Access.update ] sort_options
        ; choose ~scope:"options" options
        ]
      in
      let fields =
        [ post "" ~middlewares:[ Access.create ] create
        ; get "/new" ~middlewares:[ Access.create ] new_form
        ; choose ~scope:(CustomField |> url_key) specific
        ]
      in
      let groups =
        let open CustomFieldGroup in
        let specific =
          [ get "/edit" ~middlewares:[ Access.update ] edit
          ; post "" ~middlewares:[ Access.update ] update
          ; post "/delete" ~middlewares:[ Access.delete ] delete
          ; post "sort-fields" ~middlewares:[ Access.update ] sort_fields
          ]
        in
        [ get "/new" ~middlewares:[ Access.create ] new_form
        ; post "" ~middlewares:[ Access.create ] create
        ; post "/sort" ~middlewares:[ Access.update ] sort
        ; choose ~scope:(CustomFieldGroup |> url_key) specific
        ]
      in
      let models =
        [ get "" ~middlewares:[ Access.index ] index
        ; post "sort-fields" ~middlewares:[ Access.sort ] sort_ungrouped_fields
        ; choose ~scope:"field" fields
        ; choose ~scope:"group" groups
        ]
      in
      [ get "" ~middlewares:[ Access.index ] redirect
      ; choose ~scope:(Model |> url_key) models
      ]
    in
    let i18n =
      let open I18n in
      [ get "" ~middlewares:[ Access.index ] index
      ; post
          (Format.asprintf "/%s" (I18n |> url_key))
          ~middlewares:[ Access.update ]
          update
      ]
    in
    let settings =
      let open Settings in
      [ get "" ~middlewares:[ Access.index ] show
      ; post "/:action" ~middlewares:[ Access.update ] update_settings
      ]
    in
    choose
      ~middlewares
      [ get "/dashboard" dashboard
      ; choose ~scope:"/settings" settings
      ; choose ~scope:"/i18n" i18n
      ; choose ~scope:"/experiments" experiments
      ; choose ~scope:"/filter" filter
      ; choose ~scope:"/locations" location
      ; choose ~scope:"/contacts" contacts
      ; choose ~scope:"/admins" admins
      ; choose ~scope:"/custom-fields" custom_fields
      ]
  ;;
end

module Root = struct
  let validate_entity action entity =
    CustomMiddleware.Guardian.validate_admin_entity
      [ action, `TargetEntity entity ]
  ;;

  let middlewares =
    [ CustomMiddleware.Root.from_root_only ()
    ; CustomMiddleware.Context.context ~is_root:true ()
    ; CustomMiddleware.Logger.logger
    ]
  ;;

  let public_routes =
    let open Handler.Root in
    [ get "" (forward_to_entrypoint "/root/login")
    ; get "/login" Login.login_get
    ; post "/login" Login.login_post
    ; get "/request-reset-password" Login.request_reset_password_get
    ; post "/request-reset-password" Login.request_reset_password_post
    ; get "/reset-password" Login.reset_password_get
    ; post "/reset-password" Login.reset_password_post
    ]
  ;;

  let locked_middlewares = [ CustomMiddleware.Root.require_root () ]

  let locked_routes =
    let open Pool_common.Message.Field in
    let open Handler.Root in
    let build_route appendix =
      Format.asprintf "%s/%s" (Tenant |> url_key) appendix
    in
    let tenants =
      let specific =
        Tenant.
          [ get "" ~middlewares:[ Access.read ] tenant_detail
          ; get
              ~middlewares:[ Access.read_operator ]
              "operator"
              manage_operators
          ; post
              "create-operator"
              ~middlewares:[ Access.create_operator ]
              create_operator
          ; post
              "update-detail"
              ~middlewares:[ Access.update ]
              Update.update_detail
          ; post
              "update-database"
              ~middlewares:[ Access.update ]
              Update.update_database
          ]
      in
      Tenant.
        [ get "" ~middlewares:[ Access.index ] Tenant.tenants
        ; post "/create" ~middlewares:[ Access.create ] Tenant.create
        ; choose ~scope:(Tenant |> url_key) specific
        ; post
            (build_route
               (Format.asprintf "assets/%s/delete" (AssetId |> url_key)))
            ~middlewares:[ Access.update ]
            Tenant.Update.delete_asset
        ]
    in
    let root =
      [ post
          "/create"
          ~middlewares:[ validate_entity `Create `System ]
          Root.create
      ; post
          (Format.asprintf "/%s/toggle-status" (Root |> url_key))
          ~middlewares:[ validate_entity `Update `System ]
          Root.toggle_status
      ]
    in
    [ choose
        [ get "/logout" Login.logout
        ; choose
            ~scope:"tenants"
            ~middlewares:[ validate_entity `Read `Tenant ]
            tenants
        ; choose
            ~scope:"root"
            ~middlewares:[ validate_entity `Read `System ]
            root
        ]
    ]
  ;;

  let routes =
    choose
      ~middlewares
      [ choose public_routes
      ; choose ~middlewares:locked_middlewares locked_routes
      ]
  ;;
end

let router =
  choose
    [ Public.routes
    ; Contact.routes
    ; choose ~scope:"/admin" [ Admin.routes ]
    ; choose ~scope:"/root" [ Root.routes ]
    ; Public.global_routes
    ; get "/denied" Handler.Public.denied
    ; get
        "/**"
        ~middlewares:
          [ CustomMiddleware.Context.context ()
          ; CustomMiddleware.Logger.logger
          ]
        Handler.Public.not_found
    ]
;;

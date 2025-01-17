module Assets = Seed_assets
module File = Pool_common.File

let get_or_failwith = Pool_common.Utils.get_or_failwith

let create () =
  let styles = Assets.dummy_css () in
  let icon = Assets.dummy_icon () in
  let tenant_logo = Assets.dummy_tenant_logo () in
  let partner_logo = Assets.dummy_partner_logo () in
  let%lwt () =
    Lwt_list.iter_s
      (fun file ->
        let open Assets in
        let stored_file =
          Sihl_storage.
            { id = file.Assets.id
            ; filename = file.filename
            ; filesize = file.filesize
            ; mime = file.mime
            }
        in
        let base64 = Base64.encode_exn file.body in
        let%lwt _ = Service.Storage.upload_base64 stored_file base64 in
        Lwt.return_unit)
      [ styles; icon; tenant_logo; partner_logo ]
  in
  let data =
    if Sihl.Configuration.is_test ()
    then (
      let database_url =
        Sihl.Configuration.read_string "DATABASE_URL_TENANT_TEST"
        |> CCOption.get_exn_or "DATABASE_URL_TENANT_TEST undefined"
      in
      [ ( "Econ test"
        , "description"
        , "test.pool.econ.uzh.ch"
        , database_url
        , "econ-test"
        , "smtp.uzh.ch"
        , "587"
        , "test@econ.uzh.ch"
        , "emailemail"
        , "LOGIN"
        , "STARTTLS"
        , styles.Assets.id
        , icon.Assets.id
        , "EN" )
      ])
    else
      [ ( "Econ UZH"
        , "description"
        , "localhost:3017"
        , "mariadb://root@database-tenant:3306/dev_econ"
        , "econ-uzh"
        , "smtp.uzh.ch"
        , "587"
        , "engineering@econ.uzh.ch"
        , "emailemail"
        , "LOGIN"
        , "STARTTLS"
        , styles.Assets.id
        , icon.Assets.id
        , "EN" )
      ; ( "ZHAW"
        , "description"
        , "pool.zhaw.ch"
        , "mariadb://root@database-tenant:3306/dev_zhaw"
        , "zhaw"
        , "smtp.zhaw.ch"
        , "465"
        , "engineering@zhaw.ch"
        , "emailemail"
        , "LOGIN"
        , "SSL/TLS"
        , styles.Assets.id
        , icon.Assets.id
        , "DE" )
      ]
  in
  let%lwt () =
    Lwt_list.iter_s
      (fun ( title
           , description
           , url
           , database_url
           , database_label
           , smtp_auth_server
           , smtp_auth_port
           , smtp_auth_username
           , smtp_auth_password
           , smtp_auth_authentication_method
           , smtp_auth_protocol
           , styles
           , icon
           , default_language ) ->
        let tenant =
          Pool_tenant.(
            Write.create
              (Title.create title |> get_or_failwith)
              (Description.create description |> get_or_failwith)
              (Url.create url |> get_or_failwith)
              (Pool_tenant.Database.create database_label database_url
              |> get_or_failwith)
              SmtpAuth.(
                Write.create
                  (Server.create smtp_auth_server |> get_or_failwith)
                  (Port.create smtp_auth_port |> get_or_failwith)
                  (Username.create smtp_auth_username |> get_or_failwith)
                  (Password.create smtp_auth_password |> get_or_failwith)
                  (AuthenticationMethod.create smtp_auth_authentication_method
                  |> get_or_failwith)
                  (Protocol.create smtp_auth_protocol |> get_or_failwith)
                |> get_or_failwith)
              (Styles.Write.create styles |> get_or_failwith)
              (Icon.Write.create icon |> get_or_failwith)
              (Pool_common.Language.create default_language |> get_or_failwith))
        in
        let logo_mappings =
          let open Pool_tenant.LogoMapping in
          [ LogoType.TenantLogo, tenant_logo.Assets.id
          ; LogoType.PartnerLogo, partner_logo.Assets.id
          ]
          |> CCList.map (fun (logo_type, asset_id) ->
               { Write.id = Pool_common.Id.create ()
               ; tenant_id = tenant.Pool_tenant.Write.id
               ; asset_id = Pool_common.Id.of_string asset_id
               ; logo_type
               })
        in
        [ Pool_tenant.Created tenant; Pool_tenant.LogosUploaded logo_mappings ]
        |> Lwt_list.iter_s (Pool_tenant.handle_event Pool_database.root))
      data
  in
  Lwt.return_unit
;;

let signup csrf message channels email firstname lastname recruitment_channel =
  let submit_url = Sihl.Web.externalize_path "/participant/signup" in
  let email = email |> Option.value ~default:"" in
  let firstname = firstname |> Option.value ~default:"" in
  let lastname = lastname |> Option.value ~default:"" in
  let children =
    let open Tyxml.Html in
    let channel_select =
      let default =
        option
          ~a:
            (match recruitment_channel with
            | None -> [ a_disabled (); a_selected () ]
            | Some _ -> [ a_disabled () ])
          (txt "Choose")
      in
      channels
      |> CCList.map (fun channel ->
             let is_selected =
               recruitment_channel
               |> CCOpt.map_or ~default:false (String.equal channel)
             in
             option
               ~a:
                 (if is_selected
                 then [ a_value channel; a_selected () ]
                 else [ a_value channel ])
               (txt channel))
      |> CCList.cons default
    in
    div
      [ h1 [ txt "Participant SignUp" ]
      ; form
          ~a:[ a_action submit_url; a_method `Post ]
          [ input ~a:[ a_name "_csrf"; a_input_type `Hidden; a_value csrf ] ()
          ; div
              [ label [ txt "Email" ]
              ; input
                  ~a:
                    [ a_placeholder "example@mail.com"
                    ; a_required ()
                    ; a_name "email"
                    ; a_value email
                    ; a_input_type `Email
                    ]
                  ()
              ]
          ; div
              [ label [ txt "Firstname" ]
              ; input
                  ~a:
                    [ a_placeholder "Firstname"
                    ; a_required ()
                    ; a_name "firstname"
                    ; a_value firstname
                    ; a_input_type `Text
                    ]
                  ()
              ]
          ; div
              [ label [ txt "Lastname" ]
              ; input
                  ~a:
                    [ a_placeholder "Lastname"
                    ; a_required ()
                    ; a_name "lastname"
                    ; a_value lastname
                    ; a_input_type `Text
                    ]
                  ()
              ]
          ; div
              [ label [ txt "Password" ]
              ; input
                  ~a:
                    [ a_placeholder "Password"
                    ; a_required ()
                    ; a_name "password"
                    ; a_input_type `Password
                    ]
                  ()
              ]
          ; div
              [ label [ txt "Recruitment Channel" ]
              ; select
                  ~a:[ a_required (); a_name "recruitment_channel" ]
                  channel_select
              ]
          ; button ~a:[ a_button_type `Submit ] [ txt "Sign Up" ]
          ]
      ]
  in
  Page_layout.create children message
;;
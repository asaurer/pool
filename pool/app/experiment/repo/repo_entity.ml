open Entity
module Common = Pool_common
module Id = Common.Id
module RepoId = Common.Repo.Id

module Title = struct
  include Title

  let t =
    let encode = Utils.fcn_ok value in
    let decode m =
      m |> create |> CCResult.map_err Common.(Utils.error_to_string Language.En)
    in
    Caqti_type.(custom ~encode ~decode string)
  ;;
end

module Description = struct
  include Description

  let t =
    let encode = Utils.fcn_ok value in
    let decode m =
      m |> create |> CCResult.map_err Common.(Utils.error_to_string Language.En)
    in
    Caqti_type.(custom ~encode ~decode string)
  ;;
end

let t =
  let encode (m : t) =
    Ok
      ( m.id
      , ( Title.value m.title
        , (m.description, (m.filter, (m.created_at, m.updated_at))) ) )
  in
  let decode (id, (title, (description, (filter, (created_at, updated_at))))) =
    let open CCResult in
    Ok { id; title; description; filter; created_at; updated_at }
  in
  Caqti_type.(
    custom
      ~encode
      ~decode
      (tup2
         RepoId.t
         (tup2
            Title.t
            (tup2
               Description.t
               (tup2
                  string
                  (tup2 Common.Repo.CreatedAt.t Common.Repo.UpdatedAt.t))))))
;;

module Write = struct
  let t =
    let encode (m : t) =
      Ok
        ( m.id
        , (Title.value m.title, (Description.value m.description, m.filter)) )
    in
    let decode _ = failwith "Write only model" in
    Caqti_type.(
      custom
        ~encode
        ~decode
        (tup2 RepoId.t (tup2 Title.t (tup2 Description.t string))))
  ;;
end

module Public = struct
  open Entity.Public

  let t =
    let encode (m : t) = Ok (m.id, Description.value m.description) in
    let decode (id, description) =
      let open CCResult in
      map_err (fun _ ->
          Common.(
            Utils.error_to_string
              Language.En
              (Message.Decode Message.Field.I18n)))
      @@ let* description = Description.create description in
         Ok { id; description }
    in
    Caqti_type.(custom ~encode ~decode (tup2 RepoId.t Description.t))
  ;;
end

module ResentAt = struct
  include Entity.ResentAt

  let t = Caqti_type.ptime
end

type t =
  { id : Pool_common.Id.t
  ; experiment_id : Experiment.Id.t
  ; contact_id : Pool_common.Id.t
  ; resent_at : Entity.ResentAt.t option
  ; created_at : Pool_common.CreatedAt.t
  ; updated_at : Pool_common.UpdatedAt.t
  }

let to_entity (m : t) (contact : Contact.t) : Entity.t =
  Entity.
    { id = m.id
    ; contact
    ; resent_at = m.resent_at
    ; created_at = m.created_at
    ; updated_at = m.updated_at
    }
;;

let of_entity (experiment_id : Experiment.Id.t) (m : Entity.t) : t =
  { id = m.Entity.id
  ; experiment_id
  ; contact_id = Contact.id m.Entity.contact
  ; resent_at = m.Entity.resent_at
  ; created_at = m.Entity.created_at
  ; updated_at = m.Entity.updated_at
  }
;;

let t =
  let encode m =
    Ok
      ( m.id
      , ( m.experiment_id
        , (m.contact_id, (m.resent_at, (m.created_at, m.updated_at))) ) )
  in
  let decode
    (id, (experiment_id, (contact_id, (resent_at, (created_at, updated_at)))))
    =
    let open CCResult in
    Ok { id; experiment_id; contact_id; resent_at; created_at; updated_at }
  in
  Caqti_type.(
    custom
      ~encode
      ~decode
      (tup2
         Pool_common.Repo.Id.t
         (tup2
            Experiment.Repo.Id.t
            (tup2
               Pool_common.Repo.Id.t
               (tup2
                  (option ResentAt.t)
                  (tup2
                     Pool_common.Repo.CreatedAt.t
                     Pool_common.Repo.UpdatedAt.t))))))
;;

module Update = struct
  type t =
    { id : Pool_common.Id.t
    ; resent_at : Entity.ResentAt.t option
    }

  let t =
    let encode (m : Entity.t) = Ok (m.Entity.id, m.Entity.resent_at) in
    let decode _ = failwith "Write model only" in
    Caqti_type.(
      custom ~encode ~decode (tup2 Pool_common.Repo.Id.t (option ResentAt.t)))
  ;;
end

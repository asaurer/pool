open Entity

module Comment = struct
  include Comment

  let t = Caqti_type.string
end

type t =
  { id : Pool_common.Id.t
  ; contact_id : Pool_common.Id.t
  ; experiment_id : Pool_common.Id.t
  ; comment : Comment.t option
  ; created_at : Pool_common.CreatedAt.t
  ; updated_at : Pool_common.UpdatedAt.t
  }
[@@deriving eq, show]

let create ?(id = Pool_common.Id.create ()) contact_id experiment_id comment =
  { id
  ; contact_id
  ; experiment_id
  ; comment
  ; created_at = Pool_common.CreatedAt.create ()
  ; updated_at = Pool_common.UpdatedAt.create ()
  }
;;

let to_entity (m : t) contact experiment =
  Entity.
    { id = m.id
    ; contact
    ; experiment
    ; comment = m.comment
    ; created_at = m.created_at
    ; updated_at = m.updated_at
    }
;;

let t =
  let encode (m : t) =
    Ok
      ( Pool_common.Id.value m.id
      , ( Pool_common.Id.value m.contact_id
        , ( Pool_common.Id.value m.experiment_id
          , (m.comment, (m.created_at, m.updated_at)) ) ) )
  in
  let decode
      (id, (contact_id, (experiment_id, (comment, (created_at, updated_at)))))
    =
    let open CCResult in
    Ok
      { id = Pool_common.Id.of_string id
      ; contact_id = Pool_common.Id.of_string contact_id
      ; experiment_id = Pool_common.Id.of_string experiment_id
      ; comment = CCOption.map Comment.create comment
      ; created_at
      ; updated_at
      }
  in
  Caqti_type.(
    custom
      ~encode
      ~decode
      (tup2
         Pool_common.Repo.Id.t
         (tup2
            Pool_common.Repo.Id.t
            (tup2
               Pool_common.Repo.Id.t
               (tup2
                  (option Comment.t)
                  (tup2
                     Pool_common.Repo.CreatedAt.t
                     Pool_common.Repo.UpdatedAt.t))))))
;;

module Experiment = struct
  open Entity.ExperimentList

  let t =
    let encode (m : waiting_list_entry) =
      Ok
        ( Pool_common.Id.value m.id
        , (m.contact, (m.comment, (m.created_at, m.updated_at))) )
    in
    let decode (id, (contact, (comment, (created_at, updated_at)))) =
      let open CCResult in
      Ok
        { id = Pool_common.Id.of_string id
        ; contact
        ; comment = CCOption.map Comment.create comment
        ; created_at
        ; updated_at
        }
    in
    Caqti_type.(
      custom
        ~encode
        ~decode
        (tup2
           Pool_common.Repo.Id.t
           (tup2
              Contact.Repo.Preview.t
              (tup2
                 (option Comment.t)
                 (tup2
                    Pool_common.Repo.CreatedAt.t
                    Pool_common.Repo.UpdatedAt.t)))))
  ;;
end

open Entity

let t =
  let encode m =
    Ok (m.id, (m.title, (m.description, (m.created_at, m.updated_at))))
  in
  let decode (id, (title, (description, (created_at, updated_at)))) =
    Ok { id; title; description; created_at; updated_at }
  in
  Caqti_type.(
    custom
      ~encode
      ~decode
      (tup2 Id.t (tup2 Title.t (tup2 Description.t (tup2 ptime ptime)))))
;;

let find_by_id = Utils.todo
let list_all = Utils.todo
let insert = Utils.todo
let update = Utils.todo
let destroy = Utils.todo

include Entity
include Event

let find id =
  Repo.find Database.root id |> Lwt_result.map_err (fun _ -> "No tenant found!")
;;

let find_full id =
  Repo.find_full Database.root id
  |> Lwt_result.map_err (fun _ -> "No tenant found!")
;;

let find_by_participant = Utils.todo
let find_by_user = Utils.todo
let find_all = Repo.find_all Database.root
let find_databases = Repo.find_databases Database.root

type handle_list_recruiters = unit -> Sihl_user.t list Lwt.t
type handle_list_tenants = unit -> t list Lwt.t

module Selection = struct
  include Selection

  let find_all = Repo.find_selectable Database.root
end

(* Logo mappings *)
module LogoMapping = struct
  include LogoMapping
end

(* MONITORING AND MANAGEMENT *)

(* The system should proactively report degraded health to operators *)
type generate_status_report = StatusReport.t Lwt.t

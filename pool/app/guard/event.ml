let log_rules =
  let open CCFun in
  Lwt_result.map (fun success ->
    Logs.debug (fun m ->
      m
        "Save rules successful: %s"
        Core.Authorizer.([%show: auth_rule list] success));
    success)
  %> Lwt_result.map_error (fun err ->
       Logs.err (fun m ->
         m "Save rules failed: %s" Core.Authorizer.([%show: auth_rule list] err));
       err)
;;

type event =
  | DefaultRestored of Core.Authorizer.auth_rule list
  | RolesGranted of Repo.Uuid.Actor.t * Core.ActorRoleSet.t
  | RulesSaved of Core.Authorizer.auth_rule list
[@@deriving eq, show]

let handle_event pool : event -> unit Lwt.t =
  let open Repo in
  let ctx = [ "pool", Pool_database.Label.value pool ] in
  function
  | DefaultRestored permissions ->
    let%lwt (_ : (auth_rule list, auth_rule list) result) =
      Actor.save_rules ~ctx permissions |> log_rules
    in
    Lwt.return_unit
  | RolesGranted (actor, roles) ->
    let%lwt (_ : (unit, Pool_common.Message.error) result) =
      Actor.grant_roles ~ctx actor roles
      |> Lwt_result.map_error (fun err ->
           Pool_common.Utils.with_log_error
             (Pool_common.Message.authorization err))
    in
    Lwt.return_unit
  | RulesSaved rules ->
    let%lwt (_ : (auth_rule list, auth_rule list) result) =
      Actor.save_rules ~ctx rules |> log_rules
    in
    Lwt.return_unit
;;

let find_request =
  {sql|
    SELECT
      LOWER(CONCAT(
        SUBSTR(HEX(user_users.uuid), 1, 8), '-',
        SUBSTR(HEX(user_users.uuid), 9, 4), '-',
        SUBSTR(HEX(user_users.uuid), 13, 4), '-',
        SUBSTR(HEX(user_users.uuid), 17, 4), '-',
        SUBSTR(HEX(user_users.uuid), 21)
      ))
      user_users.email,
      user_users.username,
      user_users.name,
      user_users.given_name,
      user_users.password,
      user_users.status,
      user_users.admin,
      user_users.confirmed,
      user_users.created_at,
      user_users.updated_at
      pool_participants.recruitment_channel,
      pool_participants.terms_accepted_at,
      pool_participants.paused,
      pool_participants.disabled,
      pool_participants.verified,
      pool_participants.created_at,
      pool_participants.updated_at
    FROM pool_participants
      LEFT JOIN storage_handles
      ON pool_participants.user_uuid = user_users.uuid
    WHERE uuid = UNHEX(REPLACE(?, '-', ''));
  |sql}
  |> Caqti_request.find Caqti_type.string Repo_model.t
;;

let find db_pool =
  Utils.Database.find (Pool_common.Database.Label.value db_pool) find_request
;;

let insert_request =
  Caqti_request.exec
    Repo_model.participant
    {sql|
      INSERT INTO pool_participants (
        user_uuid,
        recruitment_channel,
        terms_accepted_at,
        paused,
        disabled,
        verified,
        created_at,
        updated_at
      ) VALUES (
        UNHEX(REPLACE($1, '-', '')),
        $2,
        $3,
        $4,
        $5,
        $6,
        $7,
        $8
      )
    |sql}
;;

let insert db_pool =
  Utils.Database.exec (Pool_common.Database.Label.value db_pool) insert_request
;;
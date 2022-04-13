DROP TABLE IF EXISTS user;
CREATE TABLE user (                                       -- ユーザー
    `id`              INTEGER PRIMARY KEY AUTOINCREMENT,  -- ID (例: 5)
    `loginid`         TEXT,                               -- ログインID名 (例: 'info@gmail.com')
    `password`        TEXT,                               -- ログインパスワード (例: 'info')
    `approved`        INTEGER,                            -- 承認フラグ (例: 0: 承認していない, 1: 承認済み)
    `deleted`         INTEGER,                            -- 削除フラグ (例: 0: 削除していない, 1: 削除済み)
    `created_ts`      TEXT,                               -- 登録日時 (例: '2022-01-23 23:49:12')
    `modified_ts`     TEXT                                -- 修正日時 (例: '2022-01-23 23:49:12')
);

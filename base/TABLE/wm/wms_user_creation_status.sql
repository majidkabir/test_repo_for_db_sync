CREATE TABLE [wm].[wms_user_creation_status]
(
    [USER_NAME] nvarchar(100) NOT NULL,
    [USER_TYPE] int NOT NULL DEFAULT ((1)),
    [LDAP_DOMAIN] nvarchar(50) NULL DEFAULT (''),
    [STATUS] int NOT NULL DEFAULT ((1)),
    [CREATED_DATE] datetime NOT NULL DEFAULT (suser_sname()),
    [UPDATED_DATE] datetime NULL,
    [WMS_USER_NAME] nvarchar(128) NOT NULL DEFAULT (''),
    [WMS_LOGIN_SYNC] int NOT NULL DEFAULT ((0)),
    [WMS_LOGIN_CREATED_DATE] datetime NULL,
    [SYNC_ERROR_NO] int NOT NULL DEFAULT ((0)),
    [SYNC_ERROR_MESSAGE] nvarchar(1024) NOT NULL DEFAULT (''),
    [SYNC_LAST_RUN_DATE] datetime NULL,
    [SYNC_NO_OF_TRY] int NOT NULL DEFAULT ((0)),
    CONSTRAINT [PK_WMS_USER_CREATION_STATUS] PRIMARY KEY ([USER_NAME])
);
GO

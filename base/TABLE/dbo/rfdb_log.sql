CREATE TABLE [dbo].[rfdb_log]
(
    [adddate] datetime NOT NULL DEFAULT (getdate()),
    [user_id] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [message] nvarchar(250) NULL
);
GO

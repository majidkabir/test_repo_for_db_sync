CREATE TABLE [dbo].[user_connections]
(
    [indkey] uniqueidentifier NOT NULL DEFAULT (newid()),
    [login_name] nchar(256) NULL,
    [login_date] datetime NULL,
    [Application] nvarchar(20) NULL DEFAULT (' '),
    [Hostname] nvarchar(256) NULL DEFAULT (''),
    CONSTRAINT [PK_user_connections] PRIMARY KEY ([indkey])
);
GO

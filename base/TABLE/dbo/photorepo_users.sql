CREATE TABLE [dbo].[photorepo_users]
(
    [UserID] bigint IDENTITY(1,1) NOT NULL,
    [UserName] nvarchar(128) NOT NULL DEFAULT (''),
    [Password] nvarchar(100) NOT NULL DEFAULT (''),
    [IsAdmin] bit NULL DEFAULT ((0)),
    [Account] nvarchar(15) NOT NULL DEFAULT (''),
    [Modules] nvarchar(500) NULL DEFAULT (''),
    [IsSuperUser] bit NULL DEFAULT ((0)),
    [LockoutEnabled] bit NOT NULL DEFAULT ((0)),
    [LockoutEndDateUtc] datetime NULL,
    [AccessFailedCount] int NOT NULL DEFAULT ((0)),
    [SecurityStamp] nvarchar(MAX) NULL,
    CONSTRAINT [PK_PhotoRepo_Users] PRIMARY KEY ([UserID])
);
GO

CREATE UNIQUE INDEX [IX_PhotoRepo_Users_UNIQ] ON [dbo].[photorepo_users] ([UserName]);
GO
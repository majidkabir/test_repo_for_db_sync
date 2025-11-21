CREATE TABLE [dbo].[ids_menuuser]
(
    [UserID] nvarchar(128) NOT NULL DEFAULT (''),
    [Groupkey] nvarchar(10) NULL,
    [UserName] nvarchar(128) NULL,
    [UserGroup] nvarchar(40) NULL,
    [UserRole] nvarchar(40) NULL,
    CONSTRAINT [PK_IDS_MenuUser] PRIMARY KEY ([UserID])
);
GO

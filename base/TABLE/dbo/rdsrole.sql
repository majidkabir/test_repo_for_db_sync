CREATE TABLE [dbo].[rdsrole]
(
    [RoleID] nvarchar(20) NOT NULL,
    [RoleDesc] nvarchar(60) NOT NULL,
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    CONSTRAINT [PK_rdsRole] PRIMARY KEY ([RoleID])
);
GO

CREATE TABLE [dbo].[rdsuser]
(
    [UserId] nvarchar(128) NOT NULL,
    [Password] nvarchar(15) NOT NULL DEFAULT (''),
    [FirstName] nvarchar(50) NOT NULL DEFAULT (''),
    [LastName] nvarchar(50) NOT NULL DEFAULT (''),
    [DefaultStorer] nvarchar(15) NOT NULL DEFAULT (''),
    [MenuID] int NULL,
    [LastLogin] datetime NOT NULL DEFAULT (getdate()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    CONSTRAINT [PK_lrdsUser] PRIMARY KEY ([UserId])
);
GO

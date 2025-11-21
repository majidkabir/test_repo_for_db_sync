CREATE TABLE [dbo].[execdebug]
(
    [UserName] nvarchar(128) NOT NULL,
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [Debug] bit NOT NULL DEFAULT ((0)),
    [Remark] nvarchar(512) NOT NULL DEFAULT (''),
    CONSTRAINT [PK_ExecDebug] PRIMARY KEY ([UserName])
);
GO

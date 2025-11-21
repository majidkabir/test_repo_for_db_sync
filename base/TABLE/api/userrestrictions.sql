CREATE TABLE [api].[userrestrictions]
(
    [RowRefNo] int IDENTITY(1,1) NOT NULL,
    [UserName] nvarchar(128) NOT NULL,
    [Restrictions] nvarchar(60) NULL,
    [Value] nvarchar(30) NOT NULL,
    [AddWho] nvarchar(128) NOT NULL,
    [AddDate] datetime NOT NULL,
    [EditWho] nvarchar(128) NOT NULL,
    [EditDate] datetime NOT NULL,
    CONSTRAINT [PK_OMS.UserRestrictions] PRIMARY KEY ([RowRefNo])
);
GO

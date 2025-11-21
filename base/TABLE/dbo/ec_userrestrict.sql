CREATE TABLE [dbo].[ec_userrestrict]
(
    [UserName] nvarchar(256) NOT NULL,
    [Type] nvarchar(20) NOT NULL DEFAULT (''),
    [Value] nvarchar(30) NOT NULL,
    [AddDate] datetime NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    CONSTRAINT [PK_EC_UserRestrict] PRIMARY KEY ([UserName], [Type], [Value])
);
GO

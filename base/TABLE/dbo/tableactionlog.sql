CREATE TABLE [dbo].[tableactionlog]
(
    [RowRef] bigint IDENTITY(1,1) NOT NULL,
    [TableName] nvarchar(50) NULL,
    [Action] nvarchar(30) NULL,
    [Description] nvarchar(2000) NULL,
    [Userdefine01] nvarchar(60) NULL,
    [Userdefine02] nvarchar(60) NULL,
    [Userdefine03] nvarchar(60) NULL,
    [Userdefine04] nvarchar(60) NULL,
    [Userdefine05] nvarchar(60) NULL,
    [SourceType] nvarchar(30) NULL,
    [AddDate] datetime NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    CONSTRAINT [PK_TableActionLog] PRIMARY KEY ([RowRef])
);
GO

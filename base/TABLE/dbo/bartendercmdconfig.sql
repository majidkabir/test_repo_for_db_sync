CREATE TABLE [dbo].[bartendercmdconfig]
(
    [LabelType] nvarchar(30) NOT NULL,
    [LabelDesc] nvarchar(80) NULL,
    [SQL_Select] nvarchar(4000) NULL,
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [Type01] nvarchar(20) NOT NULL DEFAULT (''),
    [Type02] nvarchar(20) NOT NULL DEFAULT (''),
    [Type03] nvarchar(20) NOT NULL DEFAULT (''),
    CONSTRAINT [PK_BartenderCmdConfig] PRIMARY KEY ([LabelType], [Type01], [Type02], [Type03])
);
GO

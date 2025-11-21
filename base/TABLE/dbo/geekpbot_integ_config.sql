CREATE TABLE [dbo].[geekpbot_integ_config]
(
    [InterfaceName] nvarchar(45) NOT NULL DEFAULT (''),
    [StorerKey] nvarchar(15) NOT NULL DEFAULT (''),
    [ReservedSQLQuery1] nvarchar(MAX) NOT NULL DEFAULT (''),
    [ReservedSQLQuery2] nvarchar(MAX) NOT NULL DEFAULT (''),
    [ReservedSQLQuery3] nvarchar(MAX) NOT NULL DEFAULT (''),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    CONSTRAINT [PK_GEEKPBOT_INTEG_CONFIG] PRIMARY KEY ([InterfaceName], [StorerKey])
);
GO

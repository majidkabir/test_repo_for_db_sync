CREATE TABLE [dbo].[xml_message]
(
    [RowID] bigint IDENTITY(1,1) NOT NULL,
    [BatchNo] nvarchar(50) NOT NULL,
    [Server_IP] nvarchar(20) NULL DEFAULT (''),
    [Server_Port] int NULL DEFAULT ((0)),
    [XML_Message] nvarchar(MAX) NULL DEFAULT (''),
    [Status] nvarchar(10) NULL DEFAULT ('0'),
    [RefNo] nvarchar(20) NULL DEFAULT (''),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PK_XML_Message] PRIMARY KEY ([RowID])
);
GO

CREATE INDEX [IX_XML_Message_01] ON [dbo].[xml_message] ([BatchNo], [RowID]);
GO
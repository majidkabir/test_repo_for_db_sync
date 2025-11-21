CREATE TABLE [dbo].[docinfo]
(
    [RecordID] bigint IDENTITY(1,1) NOT NULL,
    [TableName] nvarchar(20) NOT NULL,
    [Key1] nvarchar(20) NOT NULL,
    [Key2] nvarchar(20) NOT NULL,
    [Key3] nvarchar(20) NOT NULL,
    [StorerKey] nvarchar(15) NULL DEFAULT (''),
    [LineSeq] int NOT NULL,
    [Data] nvarchar(4000) NULL DEFAULT (''),
    [DataType] nvarchar(10) NULL DEFAULT (''),
    [StoredProc] nvarchar(200) NULL DEFAULT (''),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [ArchiveCop] nchar(1) NULL,
    CONSTRAINT [PK_DocInfo] PRIMARY KEY ([RecordID])
);
GO

CREATE INDEX [IX_DocInfo_01] ON [dbo].[docinfo] ([TableName], [StorerKey], [Key1], [Key2], [Key3]);
GO
CREATE INDEX [IX_DocInfo_Key1] ON [dbo].[docinfo] ([Key1], [StorerKey]);
GO
CREATE INDEX [IX_DocInfo_Key3] ON [dbo].[docinfo] ([Key3], [Key1]);
GO
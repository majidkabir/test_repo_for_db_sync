CREATE TABLE [dbo].[qcmd_transmitlogconfig]
(
    [RowRefNo] int IDENTITY(1,1) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL DEFAULT (''),
    [PhysicalTableName] nvarchar(50) NOT NULL DEFAULT (''),
    [TableName] nvarchar(20) NOT NULL DEFAULT (''),
    [App_Name] nvarchar(20) NULL,
    [App_DB_Name] nvarchar(20) NOT NULL DEFAULT (''),
    [StoredProcName] nvarchar(1024) NOT NULL DEFAULT (''),
    [DataStream] nvarchar(10) NOT NULL DEFAULT (''),
    [ThreadPerAcct] int NOT NULL DEFAULT ((1)),
    [ThreadPerStream] int NOT NULL DEFAULT ((1)),
    [MilisecondDelay] int NOT NULL DEFAULT ((0)),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [IP] nvarchar(20) NOT NULL DEFAULT (''),
    [Port] nvarchar(5) NOT NULL DEFAULT ('0'),
    [IniFilePath] nvarchar(200) NOT NULL DEFAULT (''),
    [QCmdClass] nvarchar(10) NOT NULL DEFAULT (''),
    [TargetDB] nvarchar(20) NOT NULL DEFAULT (''),
    [CmdType] nvarchar(10) NOT NULL DEFAULT (''),
    [TaskType] nvarchar(1) NOT NULL DEFAULT (''),
    [SkipTryCheck] nvarchar(1) NULL DEFAULT (''),
    [Migration] nvarchar(1) NULL DEFAULT (''),
    [Priority] int NOT NULL DEFAULT ('0'),
    [StopSocketMsg] nvarchar(1) NULL DEFAULT (''),
    [Facility] nvarchar(5) NOT NULL DEFAULT (''),
    CONSTRAINT [PK_QCmd_TransmitlogConfig] PRIMARY KEY ([RowRefNo])
);
GO

CREATE INDEX [IX_QCmd_TransmitlogConfig_PhysicalTableName_StorerKey_DataStream] ON [dbo].[qcmd_transmitlogconfig] ([PhysicalTableName], [StorerKey], [DataStream]);
GO
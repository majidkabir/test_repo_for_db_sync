CREATE TABLE [dbo].[backendprocessqueue_log]
(
    [ProcessID] int NOT NULL DEFAULT ((0)),
    [Storerkey] nvarchar(30) NOT NULL DEFAULT (''),
    [ModuleID] nvarchar(30) NOT NULL DEFAULT (''),
    [DocumentKey1] nvarchar(50) NOT NULL DEFAULT (''),
    [DocumentKey2] nvarchar(30) NOT NULL DEFAULT (''),
    [DocumentKey3] nvarchar(30) NOT NULL DEFAULT (''),
    [ProcessType] nvarchar(30) NOT NULL DEFAULT (''),
    [SourceType] nvarchar(30) NOT NULL DEFAULT (''),
    [CallType] nvarchar(50) NOT NULL DEFAULT (''),
    [Priority] nvarchar(10) NOT NULL DEFAULT (''),
    [RefKey1] nvarchar(30) NOT NULL DEFAULT (''),
    [RefKey2] nvarchar(30) NOT NULL DEFAULT (''),
    [RefKey3] nvarchar(30) NOT NULL DEFAULT (''),
    [QueueID] bigint NOT NULL DEFAULT (''),
    [ExecCmd] nvarchar(MAX) NOT NULL DEFAULT (''),
    [Status] nvarchar(10) NOT NULL DEFAULT ('0'),
    [StatusMsg] nvarchar(250) NOT NULL DEFAULT (''),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [TrafficCop] nchar(1) NULL,
    [ArchiveCop] nchar(1) NULL,
    CONSTRAINT [PK_BackEndProcessQueue_Log] PRIMARY KEY ([ProcessID])
);
GO

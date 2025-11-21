CREATE TABLE [dbo].[executionlog]
(
    [LogId] int IDENTITY(1,1) NOT NULL,
    [TimeStart] datetime NOT NULL DEFAULT (getdate()),
    [TimeEnd] datetime NULL,
    [ClientId] nvarchar(50) NOT NULL DEFAULT (''),
    [ParamIn] nvarchar(4000) NOT NULL DEFAULT (''),
    [ParamOut] nvarchar(4000) NULL,
    [RowCnt] int NOT NULL DEFAULT ((0)),
    [Sch] nvarchar(128) NOT NULL DEFAULT (isnull(object_schema_name(@@procid),'')),
    [SP] nvarchar(128) NOT NULL DEFAULT (isnull(object_name(@@procid),'')),
    [UserName] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [HostName] nvarchar(128) NOT NULL DEFAULT (isnull(host_name(),'')),
    [IP] varchar(48) NOT NULL DEFAULT (isnull(TRY_CAST(connectionproperty('client_net_address') AS [varchar](48)),'')),
    [AppName] nvarchar(128) NOT NULL DEFAULT (isnull(app_name(),'')),
    [NestLvl] tinyint NOT NULL DEFAULT (@@nestlevel),
    [ErrNo] int NOT NULL DEFAULT ((0)),
    [ErrMsg] nvarchar(1024) NOT NULL DEFAULT (''),
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PK_ExecutionLog] PRIMARY KEY ([LogId])
);
GO

CREATE INDEX [IX_ExecutionLog_TimeStart] ON [dbo].[executionlog] ([TimeStart]);
GO
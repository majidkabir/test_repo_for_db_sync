CREATE TABLE [dbo].[lwms_webapiconfig]
(
    [SeqNo] int IDENTITY(1,1) NOT NULL,
    [OperationType] nvarchar(60) NOT NULL DEFAULT (' '),
    [TargetDB] nvarchar(20) NOT NULL DEFAULT (' '),
    [TargetSchema] nvarchar(10) NOT NULL DEFAULT (' '),
    [WSPostingSP01] nvarchar(100) NOT NULL DEFAULT (' '),
    [SPTJSON] varchar(1) NOT NULL DEFAULT ('Y'),
    [SPTXML] varchar(1) NOT NULL DEFAULT ('Y'),
    [Descr] nvarchar(256) NULL DEFAULT (''),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [ResponseOriContent] int NULL DEFAULT ((0)),
    CONSTRAINT [PK_LWMS_WebApiConfig] PRIMARY KEY ([SeqNo])
);
GO

CREATE INDEX [LWMS_WebApiConfig_Index01] ON [dbo].[lwms_webapiconfig] ([OperationType], [WSPostingSP01]);
GO
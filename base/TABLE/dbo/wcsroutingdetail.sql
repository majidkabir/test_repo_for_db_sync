CREATE TABLE [dbo].[wcsroutingdetail]
(
    [WCSKey] nvarchar(10) NOT NULL,
    [ToteNo] nvarchar(20) NULL,
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [Zone] nvarchar(10) NOT NULL DEFAULT (' '),
    [Status] nvarchar(10) NOT NULL DEFAULT ('0'),
    [ActionFlag] nvarchar(1) NOT NULL DEFAULT (' '),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PK_WCSRoutingDetail] PRIMARY KEY ([WCSKey], [RowRef])
);
GO

CREATE INDEX [IX_WCSRoutingDetail_ToteNo] ON [dbo].[wcsroutingdetail] ([ToteNo]);
GO
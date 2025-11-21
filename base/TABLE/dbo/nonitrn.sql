CREATE TABLE [dbo].[nonitrn]
(
    [NonItrnKey] nvarchar(10) NOT NULL,
    [Facility] nvarchar(5) NOT NULL,
    [Storerkey] nvarchar(15) NOT NULL,
    [NonInvSku] nvarchar(80) NOT NULL,
    [Descr] nvarchar(80) NULL,
    [TranType] nvarchar(10) NULL DEFAULT (' '),
    [ToLoc] nvarchar(10) NULL DEFAULT (' '),
    [Qty] int NULL DEFAULT ((0)),
    [ReferenceNumber] nvarchar(30) NULL,
    [Notes] nvarchar(4000) NULL,
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PK_NonItrn] PRIMARY KEY ([NonItrnKey])
);
GO

CREATE TABLE [dbo].[palletdetail]
(
    [PalletKey] nvarchar(30) NOT NULL,
    [PalletLineNumber] nvarchar(5) NOT NULL,
    [CaseId] nvarchar(20) NULL DEFAULT (' '),
    [StorerKey] nvarchar(15) NOT NULL DEFAULT (' '),
    [Sku] nvarchar(20) NOT NULL DEFAULT (' '),
    [Loc] nvarchar(10) NOT NULL DEFAULT ('UNKNOWN'),
    [Qty] int NOT NULL DEFAULT ((0)),
    [Status] nvarchar(10) NOT NULL DEFAULT ('0'),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [TimeStamp] nvarchar(18) NULL,
    [UserDefine01] nvarchar(30) NULL DEFAULT (''),
    [UserDefine02] nvarchar(40) NULL DEFAULT (''),
    [UserDefine03] nvarchar(30) NULL DEFAULT (''),
    [UserDefine04] nvarchar(30) NULL DEFAULT (''),
    [UserDefine05] nvarchar(30) NULL DEFAULT (''),
    [Orderkey] nvarchar(10) NULL DEFAULT (''),
    [TrackingNo] nvarchar(40) NULL DEFAULT (''),
    CONSTRAINT [PKPalletDetail] PRIMARY KEY ([PalletKey], [PalletLineNumber]),
    CONSTRAINT [FK_PALLETDETAIL_LOC_01] FOREIGN KEY ([Loc]) REFERENCES [dbo].[LOC] ([Loc]),
    CONSTRAINT [CK_PALLETDETAIL_Status] CHECK ([Status]>='0' AND [Status]<='9')
);
GO

CREATE INDEX [IDX_PalletDetail01] ON [dbo].[palletdetail] ([StorerKey], [CaseId]);
GO
CREATE INDEX [IX_Palletdetail_Orderkey] ON [dbo].[palletdetail] ([Orderkey], [StorerKey]);
GO
CREATE INDEX [IX_Palletdetail_TrackingNo] ON [dbo].[palletdetail] ([TrackingNo], [StorerKey]);
GO
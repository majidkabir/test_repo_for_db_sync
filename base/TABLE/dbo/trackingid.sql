CREATE TABLE [dbo].[trackingid]
(
    [TrackingIDKey] bigint IDENTITY(1,1) NOT NULL,
    [TrackingID] nvarchar(30) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL,
    [SKU] nvarchar(20) NOT NULL DEFAULT (''),
    [UOM] nvarchar(10) NOT NULL,
    [QTY] int NOT NULL DEFAULT ((1)),
    [Status] nvarchar(10) NOT NULL DEFAULT ('0'),
    [DropID] nvarchar(20) NOT NULL DEFAULT (''),
    [ParentTrackingID] nvarchar(30) NOT NULL DEFAULT (''),
    [UserDefine01] nvarchar(50) NULL DEFAULT (''),
    [UserDefine02] nvarchar(50) NULL DEFAULT (''),
    [UserDefine03] nvarchar(50) NULL DEFAULT (''),
    [UserDefine04] nvarchar(50) NULL DEFAULT (''),
    [UserDefine05] nvarchar(MAX) NULL DEFAULT (''),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [ReceiptKey] nvarchar(10) NULL DEFAULT (''),
    [Facility] nvarchar(5) NULL DEFAULT (''),
    [PickMethod] nvarchar(10) NOT NULL DEFAULT (''),
    CONSTRAINT [PK_TrackingID] PRIMARY KEY ([TrackingIDKey])
);
GO

CREATE INDEX [IX_TrackingID_ParentTrackingID_StorerKey] ON [dbo].[trackingid] ([ParentTrackingID], [StorerKey]);
GO
CREATE INDEX [IX_TrackingID_TrackingID_StorerKey] ON [dbo].[trackingid] ([TrackingID], [StorerKey]);
GO
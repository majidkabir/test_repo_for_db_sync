CREATE TABLE [dbo].[channeltransfer]
(
    [ChannelTransferKey] nvarchar(10) NOT NULL,
    [ExternChannelTransferKey] nvarchar(20) NOT NULL DEFAULT (' '),
    [FromStorerKey] nvarchar(15) NOT NULL DEFAULT (' '),
    [ToStorerKey] nvarchar(15) NOT NULL DEFAULT (' '),
    [Type] nvarchar(10) NULL DEFAULT (' '),
    [OpenQty] int NOT NULL DEFAULT ((0)),
    [Status] nvarchar(10) NOT NULL DEFAULT ('0'),
    [ReasonCode] nvarchar(10) NULL DEFAULT (' '),
    [CustomerRefNo] nvarchar(20) NULL DEFAULT (' '),
    [Remarks] nvarchar(200) NULL DEFAULT (' '),
    [Facility] nvarchar(5) NULL DEFAULT (' '),
    [ToFacility] nvarchar(15) NOT NULL DEFAULT (' '),
    [UserDefine01] nvarchar(30) NULL DEFAULT (' '),
    [UserDefine02] nvarchar(30) NULL DEFAULT (' '),
    [UserDefine03] nvarchar(30) NULL DEFAULT (' '),
    [UserDefine04] nvarchar(30) NULL DEFAULT (' '),
    [UserDefine05] nvarchar(30) NULL DEFAULT (' '),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PKChannelTransfer] PRIMARY KEY ([ChannelTransferKey])
);
GO

CREATE INDEX [IDX_ChannelTransfer_ExternKey] ON [dbo].[channeltransfer] ([FromStorerKey], [ExternChannelTransferKey]);
GO
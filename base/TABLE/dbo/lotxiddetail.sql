CREATE TABLE [dbo].[lotxiddetail]
(
    [LotxIdDetailKey] nvarchar(10) NOT NULL,
    [ReceiptKey] nvarchar(10) NOT NULL DEFAULT (' '),
    [ReceiptLineNumber] nvarchar(5) NOT NULL DEFAULT (' '),
    [PickDetailKey] nvarchar(18) NOT NULL DEFAULT (' '),
    [IOFlag] nvarchar(1) NOT NULL DEFAULT ('N'),
    [Lot] nvarchar(10) NOT NULL DEFAULT (' '),
    [ID] nvarchar(18) NOT NULL DEFAULT (' '),
    [Wgt] float NOT NULL DEFAULT ((0)),
    [OrderKey] nvarchar(10) NOT NULL DEFAULT (' '),
    [OrderLineNumber] nvarchar(5) NOT NULL DEFAULT (' '),
    [Other1] nvarchar(30) NOT NULL DEFAULT (' '),
    [Other2] nvarchar(30) NOT NULL DEFAULT (' '),
    [Other3] nvarchar(30) NOT NULL DEFAULT (' '),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PKLotxIdDetail] PRIMARY KEY ([LotxIdDetailKey])
);
GO

CREATE INDEX [IDX_LotIdDet_Id] ON [dbo].[lotxiddetail] ([ID]);
GO
CREATE INDEX [IDX_LotIdDet_Lot] ON [dbo].[lotxiddetail] ([Lot]);
GO
CREATE INDEX [IDX_LotIdDet_Order] ON [dbo].[lotxiddetail] ([OrderKey], [OrderLineNumber]);
GO
CREATE INDEX [IDX_LotIdDet_PickDetail] ON [dbo].[lotxiddetail] ([PickDetailKey]);
GO
CREATE INDEX [IDX_LotIdDet_Receipt] ON [dbo].[lotxiddetail] ([ReceiptKey], [ReceiptLineNumber]);
GO
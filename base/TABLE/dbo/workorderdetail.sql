CREATE TABLE [dbo].[workorderdetail]
(
    [WorkOrderKey] nvarchar(10) NOT NULL DEFAULT (' '),
    [WorkOrderLineNumber] nvarchar(5) NOT NULL DEFAULT (' '),
    [ExternWorkOrderKey] nvarchar(20) NULL DEFAULT (' '),
    [ExternLineNo] nvarchar(5) NULL DEFAULT (' '),
    [Type] nvarchar(12) NOT NULL DEFAULT (' '),
    [Reason] nvarchar(10) NOT NULL DEFAULT (' '),
    [Unit] nvarchar(10) NOT NULL DEFAULT (' '),
    [Qty] int NOT NULL DEFAULT ((0)),
    [Price] money NOT NULL DEFAULT ((0)),
    [LineValue] money NULL DEFAULT ((0)),
    [Remarks] nvarchar(215) NULL DEFAULT (' '),
    [WkOrdUdef1] nvarchar(50) NULL DEFAULT (' '),
    [WkOrdUdef2] nvarchar(18) NULL DEFAULT (' '),
    [WkOrdUdef3] nvarchar(18) NULL DEFAULT (' '),
    [WkOrdUdef4] nvarchar(18) NULL DEFAULT (' '),
    [WkOrdUdef5] nvarchar(18) NULL DEFAULT (' '),
    [Status] nvarchar(10) NULL DEFAULT ('0'),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [StorerKey] nvarchar(15) NULL DEFAULT (' '),
    [Sku] nvarchar(20) NULL DEFAULT (' '),
    [WkOrdUdef6] datetime NULL DEFAULT (' '),
    [WkOrdUdef7] datetime NULL DEFAULT (' '),
    [WkOrdUdef8] nvarchar(30) NULL DEFAULT (' '),
    [WkOrdUdef9] nvarchar(30) NULL DEFAULT (' '),
    [WkOrdUdef10] nvarchar(30) NULL DEFAULT (' '),
    CONSTRAINT [PK_WorkOrderDetail] PRIMARY KEY ([WorkOrderKey], [WorkOrderLineNumber])
);
GO

CREATE INDEX [IX_WORKORDERDETAIL_ExtWorkOrderKey] ON [dbo].[workorderdetail] ([ExternWorkOrderKey], [ExternLineNo]);
GO
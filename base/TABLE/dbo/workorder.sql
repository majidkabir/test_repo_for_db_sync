CREATE TABLE [dbo].[workorder]
(
    [WorkOrderKey] nvarchar(10) NOT NULL DEFAULT (' '),
    [ExternWorkOrderKey] nvarchar(20) NULL DEFAULT (' '),
    [StorerKey] nvarchar(15) NOT NULL DEFAULT (' '),
    [Facility] nvarchar(5) NOT NULL DEFAULT (' '),
    [Status] nvarchar(10) NULL DEFAULT ('0'),
    [ExternStatus] nvarchar(10) NULL DEFAULT ('0'),
    [Type] nvarchar(12) NOT NULL DEFAULT (' '),
    [Reason] nvarchar(10) NOT NULL DEFAULT (' '),
    [TotalPrice] money NULL DEFAULT ((0)),
    [GenerateCharges] nvarchar(10) NOT NULL DEFAULT ('No'),
    [Remarks] nvarchar(215) NULL DEFAULT (' '),
    [Notes1] nvarchar(215) NULL DEFAULT (' '),
    [Notes2] nvarchar(215) NULL DEFAULT (' '),
    [WkOrdUdef1] nvarchar(50) NULL DEFAULT (' '),
    [WkOrdUdef2] nvarchar(18) NULL DEFAULT (' '),
    [WkOrdUdef3] nvarchar(18) NULL DEFAULT (' '),
    [WkOrdUdef4] nvarchar(18) NULL DEFAULT (' '),
    [WkOrdUdef5] nvarchar(18) NULL DEFAULT (' '),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [WkOrdUdef6] datetime NULL DEFAULT (' '),
    [WkOrdUdef7] datetime NULL DEFAULT (' '),
    [WkOrdUdef8] nvarchar(50) NULL DEFAULT (' '),
    [WkOrdUdef9] nvarchar(30) NULL DEFAULT (' '),
    [WkOrdUdef10] nvarchar(30) NULL DEFAULT (' '),
    CONSTRAINT [PK_WorkOrder] PRIMARY KEY ([WorkOrderKey])
);
GO

CREATE INDEX [IX_WORKORDER_ExternWorkOrdKey] ON [dbo].[workorder] ([ExternWorkOrderKey]);
GO
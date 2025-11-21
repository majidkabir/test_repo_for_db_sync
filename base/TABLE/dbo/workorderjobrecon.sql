CREATE TABLE [dbo].[workorderjobrecon]
(
    [JobKey] nvarchar(10) NOT NULL DEFAULT (''),
    [JobReconLineNumber] nvarchar(5) NOT NULL DEFAULT (''),
    [WorkOrderkey] nvarchar(10) NOT NULL DEFAULT (''),
    [Storerkey] nvarchar(10) NOT NULL DEFAULT (''),
    [Sku] nvarchar(20) NOT NULL DEFAULT (''),
    [NonInvSku] nvarchar(80) NOT NULL DEFAULT (''),
    [Packkey] nvarchar(10) NULL DEFAULT (''),
    [UOM] nvarchar(10) NULL DEFAULT (''),
    [QtyReserved] int NULL DEFAULT ((0)),
    [WastageUOM] nvarchar(10) NULL DEFAULT (''),
    [QtyWastage] int NULL DEFAULT ((0)),
    [WastageReason] nvarchar(30) NULL DEFAULT (''),
    [RejectUOM] nvarchar(10) NULL DEFAULT (''),
    [QtyReject] int NULL DEFAULT ((0)),
    [RejectReason] nvarchar(30) NULL DEFAULT (''),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [RemainingUOM] nvarchar(10) NULL DEFAULT (''),
    [QtyRemaining] int NULL DEFAULT ((0)),
    CONSTRAINT [PK_WORKORDERJOBRECON] PRIMARY KEY ([JobKey], [JobReconLineNumber])
);
GO

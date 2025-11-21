CREATE TABLE [dbo].[vasrefkeylookup]
(
    [JobKey] nvarchar(10) NOT NULL DEFAULT (''),
    [JobLine] nvarchar(5) NOT NULL DEFAULT (''),
    [WorkOrderkey] nvarchar(10) NOT NULL DEFAULT (''),
    [WorkOrderName] nvarchar(50) NOT NULL DEFAULT (''),
    [MasterWorkOrder] nvarchar(50) NOT NULL DEFAULT (''),
    [StepNumber] nvarchar(5) NOT NULL DEFAULT (''),
    [WkOrdReqInputsKey] nvarchar(10) NOT NULL DEFAULT (''),
    [WkOrdReqOutputsKey] nvarchar(10) NOT NULL DEFAULT (''),
    [StepQty] int NULL DEFAULT ((0)),
    [AddWho] nvarchar(18) NULL DEFAULT (suser_sname()),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(18) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PK_VASRefKeyLookup] PRIMARY KEY ([JobKey], [JobLine], [WorkOrderkey], [StepNumber], [WkOrdReqInputsKey], [WkOrdReqOutputsKey])
);
GO

CREATE INDEX [IX_VASRefKeyLookup_joboperation] ON [dbo].[vasrefkeylookup] ([JobKey], [JobLine]);
GO
CREATE INDEX [IX_VASRefKeyLookup_Routing] ON [dbo].[vasrefkeylookup] ([WorkOrderName], [MasterWorkOrder]);
GO
CREATE INDEX [IX_VASRefKeyLookup_WorkOrderRequests] ON [dbo].[vasrefkeylookup] ([WorkOrderkey], [StepNumber], [WkOrdReqInputsKey], [WkOrdReqOutputsKey]);
GO
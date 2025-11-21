CREATE TABLE [dbo].[workordersteps]
(
    [MasterWorkOrder] nvarchar(50) NOT NULL DEFAULT (''),
    [WorkOrderName] nvarchar(50) NOT NULL DEFAULT (''),
    [StepNumber] nvarchar(5) NOT NULL DEFAULT (''),
    [HostStepNumber] nvarchar(20) NOT NULL DEFAULT (''),
    [WorkStation] nvarchar(50) NOT NULL DEFAULT (''),
    [WOOperation] nvarchar(30) NOT NULL DEFAULT (''),
    [STDTime] decimal(18, 6) NOT NULL DEFAULT ((0.000000)),
    [TimeRate] nvarchar(30) NOT NULL DEFAULT ('Rate Per Worker'),
    [CopyInputFromStep] nvarchar(5) NULL,
    [BillingUOMQty] int NOT NULL DEFAULT ((0)),
    [BillingUOM] nvarchar(20) NOT NULL DEFAULT (''),
    [BillingRate] money NOT NULL DEFAULT ((0.00)),
    [FromLoc] nvarchar(10) NOT NULL DEFAULT (''),
    [ToLoc] nvarchar(10) NOT NULL DEFAULT (''),
    [Instructions] nvarchar(4000) NOT NULL DEFAULT (''),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PK_WorkOrderSteps] PRIMARY KEY ([MasterWorkOrder], [WorkOrderName], [StepNumber])
);
GO

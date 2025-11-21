CREATE TABLE [dbo].[vas_plan]
(
    [VASPlanKey] bigint IDENTITY(1,1) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL DEFAULT (''),
    [Brand] nvarchar(15) NOT NULL DEFAULT (''),
    [Type] nvarchar(10) NOT NULL DEFAULT (''),
    [SeqNo] int NOT NULL DEFAULT ((0)),
    [RepackCode] nvarchar(20) NOT NULL DEFAULT (''),
    [SOSDate] datetime NULL,
    [PlanDate] datetime NULL,
    [DemandQty] int NOT NULL DEFAULT ((0)),
    [AllocatedQty] int NOT NULL DEFAULT ((0)),
    [UOM] nvarchar(10) NOT NULL DEFAULT (''),
    [KITKey] nvarchar(10) NOT NULL DEFAULT (''),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [VASDemandKey] bigint NULL,
    CONSTRAINT [PK_VAS_Plan] PRIMARY KEY ([VASPlanKey])
);
GO

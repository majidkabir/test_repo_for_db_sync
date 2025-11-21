CREATE TABLE [dbo].[loadplan_sup_detail]
(
    [RowRefNo] bigint IDENTITY(1,1) NOT NULL,
    [TYPE] nvarchar(1) NOT NULL DEFAULT ('0'),
    [Loadkey] nvarchar(10) NOT NULL,
    [PickMethod] nvarchar(10) NOT NULL DEFAULT (''),
    [Loc] nvarchar(10) NOT NULL DEFAULT (''),
    [SKU] nvarchar(20) NOT NULL DEFAULT (''),
    [Div] nvarchar(20) NOT NULL DEFAULT (''),
    [Class] nvarchar(20) NOT NULL DEFAULT (''),
    [Measurement] int NOT NULL DEFAULT ((0)),
    [CartonNo] int NOT NULL DEFAULT ((0)),
    [Qty] int NOT NULL DEFAULT ((0)),
    [QUOM] int NOT NULL DEFAULT ((0)),
    [TotalCarton] int NOT NULL DEFAULT ((0)),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [ArchiveCop] nchar(1) NULL,
    CONSTRAINT [PK_LoadPlan_SUP_Detail] PRIMARY KEY ([RowRefNo])
);
GO

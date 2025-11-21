CREATE TABLE [rdt].[rdtqcinquirylog]
(
    [QCInquiryLogKey] int IDENTITY(1,1) NOT NULL,
    [Mobile] int NOT NULL,
    [UserID] nvarchar(128) NOT NULL,
    [Status] nvarchar(10) NOT NULL DEFAULT ('0'),
    [Storerkey] nvarchar(15) NULL,
    [DropID] nvarchar(18) NULL,
    [DropIDType] nvarchar(10) NULL,
    [ReasonKey] nvarchar(10) NULL,
    [OrderKey] nvarchar(10) NULL,
    [SKU] nvarchar(20) NULL,
    [Loc] nvarchar(10) NULL,
    [Lot] nvarchar(10) NULL,
    [TaskdetailKey] nvarchar(10) NULL DEFAULT (''),
    [QtyAllocated] int NULL DEFAULT ((0)),
    [QtyPicked] int NULL DEFAULT ((0)),
    [QtyShortPick] int NULL,
    [ResolvedSPQty] int NULL DEFAULT ((0)),
    [NewDropID] nvarchar(18) NULL,
    [NewLoc] nvarchar(10) NULL,
    [AddDate] datetime NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    CONSTRAINT [PK_rdtQCInquiryLog] PRIMARY KEY ([QCInquiryLogKey])
);
GO

CREATE INDEX [idx_rdtQCInquiryLog_USerID] ON [rdt].[rdtqcinquirylog] ([UserID]);
GO
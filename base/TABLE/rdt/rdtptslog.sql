CREATE TABLE [rdt].[rdtptslog]
(
    [PTSLogKey] bigint IDENTITY(1,1) NOT NULL,
    [PTSPosition] nvarchar(20) NULL DEFAULT (''),
    [Status] nvarchar(2) NOT NULL DEFAULT ('0'),
    [DropID] nvarchar(20) NULL DEFAULT (''),
    [LabelNo] nvarchar(20) NULL DEFAULT (''),
    [StorerKey] nvarchar(15) NULL DEFAULT (''),
    [ConsigneeKey] nvarchar(15) NULL DEFAULT (''),
    [OrderKey] nvarchar(10) NULL DEFAULT (''),
    [SKU] nvarchar(20) NULL DEFAULT (''),
    [LOC] nvarchar(10) NULL DEFAULT (''),
    [LOT] nvarchar(10) NULL DEFAULT (''),
    [UOM] nvarchar(10) NULL DEFAULT (''),
    [ExpectedQty] int NULL DEFAULT (''),
    [Qty] int NULL DEFAULT (''),
    [Remarks] nvarchar(500) NULL DEFAULT (''),
    [Func] int NULL DEFAULT ((0)),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PK_rdtPTSLog] PRIMARY KEY ([PTSLogKey])
);
GO

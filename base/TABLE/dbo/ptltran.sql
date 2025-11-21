CREATE TABLE [dbo].[ptltran]
(
    [PTLKey] bigint IDENTITY(1,1) NOT NULL,
    [IPAddress] nvarchar(40) NOT NULL DEFAULT (''),
    [DeviceID] nvarchar(20) NOT NULL DEFAULT (''),
    [DevicePosition] nvarchar(10) NOT NULL DEFAULT (''),
    [Status] nvarchar(2) NOT NULL DEFAULT ('0'),
    [PTL_Type] nvarchar(20) NOT NULL,
    [DropID] nvarchar(20) NULL,
    [OrderKey] nvarchar(10) NULL DEFAULT (''),
    [Storerkey] nvarchar(15) NULL DEFAULT (''),
    [SKU] nvarchar(20) NULL DEFAULT (''),
    [LOC] nvarchar(10) NULL DEFAULT (''),
    [Lot] nvarchar(10) NULL,
    [ExpectedQty] int NULL DEFAULT ((0)),
    [Qty] int NULL DEFAULT ((0)),
    [Remarks] nvarchar(500) NULL DEFAULT (''),
    [MessageNum] nvarchar(10) NULL DEFAULT (''),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [DeviceProfileLogKey] nvarchar(10) NULL,
    [TrafficCop] nchar(1) NULL,
    [ArchiveCop] nchar(1) NULL,
    [SourceKey] nvarchar(20) NULL DEFAULT (''),
    [ConsigneeKey] nvarchar(15) NULL DEFAULT (''),
    [CaseID] nvarchar(20) NULL DEFAULT (''),
    [LightUp] nvarchar(1) NULL DEFAULT ((0)),
    [LightMode] nvarchar(10) NULL DEFAULT (''),
    [LightSequence] nvarchar(10) NULL DEFAULT (''),
    [UOM] nvarchar(10) NULL DEFAULT (''),
    [RefPTLKey] nvarchar(10) NULL DEFAULT (''),
    CONSTRAINT [PK_PTLTran] PRIMARY KEY ([PTLKey])
);
GO

CREATE INDEX [IDX_PTLTRAN_01] ON [dbo].[ptltran] ([DeviceProfileLogKey], [DevicePosition]);
GO
CREATE INDEX [IDX_PTLTRAN_02] ON [dbo].[ptltran] ([DeviceID], [LightUp]);
GO
CREATE INDEX [IDX_PTLTRAN_DeviceID] ON [dbo].[ptltran] ([DeviceID]);
GO
CREATE INDEX [IX_PTLTran_Key1] ON [dbo].[ptltran] ([IPAddress], [DevicePosition], [Status]);
GO
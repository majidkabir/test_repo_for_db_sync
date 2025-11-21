CREATE TABLE [rdt].[rdtptlcartlog]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [CartID] nvarchar(10) NOT NULL,
    [ToteID] nvarchar(20) NOT NULL,
    [Position] nvarchar(10) NOT NULL,
    [DeviceProfileLogKey] nvarchar(10) NOT NULL,
    [Method] nvarchar(1) NOT NULL,
    [PickZone] nvarchar(10) NOT NULL DEFAULT (''),
    [PickSeq] nvarchar(1) NOT NULL DEFAULT (''),
    [OrderKey] nvarchar(10) NOT NULL DEFAULT (''),
    [LoadKey] nvarchar(10) NOT NULL DEFAULT (''),
    [WaveKey] nvarchar(10) NOT NULL DEFAULT (''),
    [PickSlipNo] nvarchar(10) NOT NULL DEFAULT (''),
    [BatchKey] nvarchar(20) NOT NULL DEFAULT (''),
    [StorerKey] nvarchar(15) NOT NULL DEFAULT (''),
    [SKU] nvarchar(20) NOT NULL DEFAULT (''),
    [MaxTask] int NOT NULL DEFAULT ((0)),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [CaseID] nvarchar(20) NOT NULL DEFAULT (''),
    [ItemClass] nvarchar(10) NOT NULL DEFAULT (''),
    [Route] nvarchar(10) NOT NULL DEFAULT (''),
    CONSTRAINT [PK_rdtPTLCartLog] PRIMARY KEY ([RowRef])
);
GO

CREATE UNIQUE INDEX [IX_rdtPTLCartLog_CartID_ToteID_Position] ON [rdt].[rdtptlcartlog] ([CartID], [ToteID], [Position]);
GO
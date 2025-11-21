CREATE TABLE [dbo].[pickinginfo]
(
    [PickSlipNo] nvarchar(10) NOT NULL,
    [ScanInDate] datetime NULL,
    [PickerID] nvarchar(128) NULL,
    [ScanOutDate] datetime NULL,
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [WaveKey] nvarchar(20) NOT NULL DEFAULT (''),
    [CaseID] nvarchar(60) NOT NULL DEFAULT (''),
    CONSTRAINT [PK_PickingInfo] PRIMARY KEY ([PickSlipNo])
);
GO

CREATE INDEX [PickingInfo3] ON [dbo].[pickinginfo] ([ScanInDate]);
GO
CREATE TABLE [dbo].[packheader]
(
    [PickSlipNo] nvarchar(10) NOT NULL,
    [StorerKey] nvarchar(20) NOT NULL,
    [Route] nvarchar(10) NULL DEFAULT (' '),
    [OrderKey] nvarchar(10) NOT NULL,
    [OrderRefNo] nvarchar(18) NULL DEFAULT (' '),
    [LoadKey] nvarchar(10) NULL DEFAULT (' '),
    [ConsigneeKey] nvarchar(15) NULL DEFAULT (' '),
    [Status] nvarchar(1) NULL DEFAULT ('0'),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [ArchiveCop] nvarchar(1) NULL,
    [TTLCNTS] int NULL DEFAULT ((0)),
    [CtnTyp1] nvarchar(10) NULL DEFAULT (''),
    [CtnTyp2] nvarchar(10) NULL DEFAULT (''),
    [CtnTyp3] nvarchar(10) NULL DEFAULT (''),
    [CtnTyp4] nvarchar(10) NULL DEFAULT (''),
    [CtnTyp5] nvarchar(10) NULL DEFAULT (''),
    [CtnCnt1] int NULL DEFAULT ((0)),
    [CtnCnt2] int NULL DEFAULT ((0)),
    [CtnCnt3] int NULL DEFAULT ((0)),
    [CtnCnt4] int NULL DEFAULT ((0)),
    [CtnCnt5] int NULL DEFAULT ((0)),
    [TotCtnWeight] float NULL DEFAULT ((0)),
    [TotCtnCube] float NULL DEFAULT ((0)),
    [CartonGroup] nvarchar(10) NULL DEFAULT (''),
    [ManifestPrinted] nvarchar(10) NULL DEFAULT ('0'),
    [ConsoOrderKey] nvarchar(30) NULL DEFAULT (''),
    [TaskBatchNo] nvarchar(10) NOT NULL DEFAULT (''),
    [ComputerName] nvarchar(30) NOT NULL DEFAULT (''),
    [PackStatus] nvarchar(10) NOT NULL DEFAULT ('0'),
    [EstimateTotalCtn] int NULL DEFAULT ((0)),
    CONSTRAINT [PKPackHeader] PRIMARY KEY ([PickSlipNo])
);
GO

CREATE INDEX [IDX_PackHeader_orderkey] ON [dbo].[packheader] ([OrderKey]);
GO
CREATE INDEX [IDX_PACKHEADER_TaskBatchOrder] ON [dbo].[packheader] ([TaskBatchNo], [OrderKey]);
GO
CREATE INDEX [IX_PackHeader_ConsoOrderKey] ON [dbo].[packheader] ([ConsoOrderKey]);
GO
CREATE INDEX [IX_PackHeader_Loadkey] ON [dbo].[packheader] ([LoadKey]);
GO
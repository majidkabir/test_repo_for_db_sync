CREATE TABLE [dbo].[packdetaillabel]
(
    [RowID] bigint IDENTITY(1,1) NOT NULL,
    [PickSlipNo] nvarchar(10) NOT NULL DEFAULT (''),
    [LabelNo] nvarchar(20) NOT NULL DEFAULT (''),
    [CartonNo] int NOT NULL DEFAULT ((0)),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PK_PackdetailLabel] PRIMARY KEY ([RowID])
);
GO

CREATE INDEX [IDX_PackdetailLabel_labelno] ON [dbo].[packdetaillabel] ([PickSlipNo], [LabelNo], [CartonNo]);
GO
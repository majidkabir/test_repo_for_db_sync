CREATE TABLE [dbo].[packdetailinfo]
(
    [PackDetailInfoKey] bigint IDENTITY(1,1) NOT NULL,
    [PickSlipNo] nvarchar(10) NOT NULL,
    [CartonNo] int NOT NULL,
    [LabelNo] nvarchar(20) NOT NULL,
    [LabelLine] nvarchar(5) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL,
    [SKU] nvarchar(20) NOT NULL,
    [UserDefine01] nvarchar(60) NOT NULL,
    [UserDefine02] nvarchar(60) NOT NULL,
    [UserDefine03] nvarchar(60) NOT NULL,
    [QTY] int NOT NULL,
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PK_PackDetailInfo] PRIMARY KEY ([PackDetailInfoKey])
);
GO

CREATE INDEX [IX_PackDetailInfo_PickSlipNo_CartonNo_LabelNo_LabelLine] ON [dbo].[packdetailinfo] ([PickSlipNo], [CartonNo], [LabelNo], [LabelLine]);
GO
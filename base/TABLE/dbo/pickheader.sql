CREATE TABLE [dbo].[pickheader]
(
    [PickHeaderKey] nvarchar(18) NOT NULL,
    [WaveKey] nvarchar(10) NOT NULL DEFAULT (' '),
    [OrderKey] nvarchar(10) NOT NULL DEFAULT (' '),
    [ExternOrderKey] nvarchar(50) NOT NULL DEFAULT (' '),
    [StorerKey] nvarchar(15) NOT NULL DEFAULT (' '),
    [ConsigneeKey] nvarchar(30) NOT NULL DEFAULT (' '),
    [Priority] nvarchar(10) NOT NULL DEFAULT ('5'),
    [Type] nvarchar(10) NOT NULL DEFAULT ('5'),
    [Zone] nvarchar(18) NOT NULL DEFAULT (' '),
    [Status] nvarchar(10) NOT NULL DEFAULT ('0'),
    [PickType] nvarchar(10) NOT NULL DEFAULT ('3'),
    [EffectiveDate] datetime NOT NULL DEFAULT (getdate()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [ConsoOrderKey] nvarchar(30) NULL,
    [LoadKey] nvarchar(10) NULL DEFAULT (''),
    CONSTRAINT [PKPickHeader] PRIMARY KEY ([PickHeaderKey]),
    CONSTRAINT [CK_PICKHEADER_Status] CHECK (rtrim([Status]) like '[0-9]')
);
GO

CREATE INDEX [IX_PICKHEADER_Consignee] ON [dbo].[pickheader] ([ConsigneeKey]);
GO
CREATE INDEX [IX_PICKHEADER_ExternOrder] ON [dbo].[pickheader] ([ExternOrderKey], [Zone], [PickHeaderKey]);
GO
CREATE INDEX [IX_PickHeader_loadkey] ON [dbo].[pickheader] ([LoadKey], [Zone]);
GO
CREATE INDEX [IX_PICKHEADER_OrderKey] ON [dbo].[pickheader] ([OrderKey]);
GO
CREATE INDEX [IX_PickHeader_WaveKey] ON [dbo].[pickheader] ([WaveKey], [Zone], [PickType]);
GO
CREATE UNIQUE INDEX [IX_PICKHEADER_UNIQUE] ON [dbo].[pickheader] ([PickHeaderKey], [WaveKey], [OrderKey], [ExternOrderKey], [ConsoOrderKey]);
GO
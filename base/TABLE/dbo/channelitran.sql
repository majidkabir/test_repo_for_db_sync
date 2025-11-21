CREATE TABLE [dbo].[channelitran]
(
    [ChannelTran_ID] bigint IDENTITY(1,1) NOT NULL,
    [TranType] nvarchar(10) NOT NULL DEFAULT (''),
    [ChannelTranRefNo] nvarchar(20) NOT NULL DEFAULT (''),
    [SourceType] nvarchar(60) NOT NULL DEFAULT (''),
    [Storerkey] nvarchar(15) NOT NULL,
    [SKU] nvarchar(20) NOT NULL,
    [Facility] nvarchar(5) NOT NULL,
    [Channel_ID] bigint NULL DEFAULT (''),
    [Channel] nvarchar(20) NOT NULL DEFAULT (''),
    [C_Attribute01] nvarchar(30) NOT NULL DEFAULT (''),
    [C_Attribute02] nvarchar(30) NOT NULL DEFAULT (''),
    [C_Attribute03] nvarchar(30) NOT NULL DEFAULT (''),
    [C_Attribute04] nvarchar(30) NOT NULL DEFAULT (''),
    [C_Attribute05] nvarchar(30) NOT NULL DEFAULT (''),
    [Qty] int NOT NULL DEFAULT ((0)),
    [QtyOnHold] int NOT NULL DEFAULT ((0)),
    [Reasoncode] nvarchar(10) NULL DEFAULT (''),
    [CustomerRef] nvarchar(30) NULL DEFAULT (''),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [TrafficCop] char(1) NULL,
    [ArchiveCop] char(1) NULL,
    CONSTRAINT [PK_CHANNELITRAN] PRIMARY KEY ([ChannelTran_ID])
);
GO

CREATE INDEX [IDX_CHANNELITRAN_SourceType] ON [dbo].[channelitran] ([SourceType], [ChannelTranRefNo]);
GO
CREATE INDEX [IDX_CHANNELITRAN_TranType] ON [dbo].[channelitran] ([TranType]);
GO
CREATE TABLE [dbo].[dailyinventorychannel]
(
    [ROWRef] bigint IDENTITY(1,1) NOT NULL,
    [Channel_ID] bigint NOT NULL,
    [InventoryDate] datetime NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL,
    [SKU] nvarchar(20) NOT NULL,
    [Facility] nvarchar(5) NOT NULL,
    [Channel] nvarchar(20) NOT NULL DEFAULT (''),
    [C_Attribute01] nvarchar(30) NOT NULL,
    [C_Attribute02] nvarchar(30) NOT NULL DEFAULT (''),
    [C_Attribute03] nvarchar(30) NOT NULL DEFAULT (''),
    [C_Attribute04] nvarchar(30) NOT NULL DEFAULT (''),
    [C_Attribute05] nvarchar(30) NOT NULL DEFAULT (''),
    [Qty] int NOT NULL DEFAULT ((0)),
    [QtyAllocated] int NOT NULL DEFAULT ((0)),
    [QtyOnHold] int NOT NULL DEFAULT ((0)),
    [ArchiveCop] char(1) NULL,
    [Adddate] datetime NULL DEFAULT (getdate()),
    CONSTRAINT [PK_DailyInventoryChannel] PRIMARY KEY ([ROWRef])
);
GO

CREATE INDEX [IDX_DailyInvChannel] ON [dbo].[dailyinventorychannel] ([InventoryDate], [Channel_ID], [StorerKey], [SKU], [Channel]);
GO
CREATE INDEX [IDX_DailyInvChannel_SKU] ON [dbo].[dailyinventorychannel] ([SKU], [StorerKey], [Channel], [Facility]);
GO
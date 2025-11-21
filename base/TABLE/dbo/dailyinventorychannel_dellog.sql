CREATE TABLE [dbo].[dailyinventorychannel_dellog]
(
    [ROWRef] bigint IDENTITY(1,1) NOT NULL,
    [RowRefSource] int NOT NULL,
    [Channel_ID] bigint NOT NULL,
    [InventoryDate] datetime NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL,
    [SKU] nvarchar(20) NOT NULL,
    [Facility] nvarchar(5) NOT NULL,
    [Channel] nvarchar(20) NOT NULL,
    [C_Attribute01] nvarchar(30) NOT NULL,
    [C_Attribute02] nvarchar(30) NOT NULL,
    [C_Attribute03] nvarchar(30) NOT NULL,
    [C_Attribute04] nvarchar(30) NOT NULL,
    [C_Attribute05] nvarchar(30) NOT NULL,
    [Qty] int NOT NULL,
    [QtyAllocated] int NOT NULL,
    [QtyOnHold] int NOT NULL,
    [ArchiveCop] char(1) NULL,
    [Status] nchar(1) NOT NULL DEFAULT ('0'),
    [Adddate] datetime NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    CONSTRAINT [PK_DailyInventoryChannel_DELLOG] PRIMARY KEY ([ROWRef])
);
GO

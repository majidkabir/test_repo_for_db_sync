CREATE TABLE [dbo].[channelinv]
(
    [Channel_ID] bigint IDENTITY(1,1) NOT NULL,
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
    [AddDate] datetime NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [ArchiveCop] char(1) NULL,
    CONSTRAINT [PK_ChannelInv] PRIMARY KEY ([Channel_ID]),
    CONSTRAINT [CK_ChannelInv_Qty] CHECK ([Qty]>=(0)),
    CONSTRAINT [CK_ChannelInv_QtyAllocated] CHECK ([QtyAllocated]>=(0)),
    CONSTRAINT [CK_ChannelInv_QtyOnHold] CHECK ((([Qty]-[QtyAllocated])-[QtyonHold])>=(0)),
    CONSTRAINT [CK_ChannelInv_QtyOnHold2] CHECK ([QtyonHold]>=(0))
);
GO

CREATE INDEX [IX_ChannelInv_sku] ON [dbo].[channelinv] ([SKU], [Channel]);
GO
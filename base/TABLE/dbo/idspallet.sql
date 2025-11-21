CREATE TABLE [dbo].[idspallet]
(
    [ID] nvarchar(18) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL,
    [SKU] nvarchar(20) NOT NULL,
    [Qty] int NOT NULL,
    [uom] nvarchar(5) NOT NULL,
    [packkey] nvarchar(10) NOT NULL,
    [batchno] nvarchar(18) NOT NULL,
    [productiondate] datetime NOT NULL,
    [clearingdate] datetime NULL,
    [printed] nvarchar(1) NOT NULL DEFAULT ('N'),
    [addwho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [adddate] datetime NOT NULL DEFAULT (getdate()),
    [editwho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [editdate] datetime NOT NULL DEFAULT (getdate()),
    [SYSID] int NULL,
    [lottable01] nvarchar(18) NULL DEFAULT (' '),
    [lottable03] nvarchar(18) NULL DEFAULT (' ')
);
GO

CREATE INDEX [IX_idsPallet_sku] ON [dbo].[idspallet] ([SKU]);
GO
CREATE TABLE [dbo].[idsmovestock]
(
    [Rowid] int IDENTITY(1,1) NOT NULL,
    [StorerKey] nvarchar(15) NULL,
    [SKU] nvarchar(20) NULL,
    [LOT] nvarchar(10) NULL,
    [FromLoc] nvarchar(10) NULL,
    [FromID] nvarchar(18) NULL,
    [ToLoc] nvarchar(10) NULL,
    [ToID] nvarchar(18) NULL,
    [Qty] int NULL,
    [Lottable01] nvarchar(18) NOT NULL DEFAULT (' '),
    [Lottable02] nvarchar(18) NOT NULL DEFAULT (' '),
    [Lottable03] nvarchar(18) NOT NULL DEFAULT (' '),
    [Lottable04] datetime NULL,
    [Lottable05] datetime NULL,
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    CONSTRAINT [PK_idsMoveStock] PRIMARY KEY ([Rowid])
);
GO

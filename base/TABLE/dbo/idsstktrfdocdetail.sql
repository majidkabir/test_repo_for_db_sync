CREATE TABLE [dbo].[idsstktrfdocdetail]
(
    [STDNo] nvarchar(10) NOT NULL,
    [STDLineNO] nvarchar(5) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL,
    [SKU] nvarchar(20) NOT NULL,
    [Qty] int NOT NULL,
    [ID] nvarchar(18) NOT NULL,
    [BatchNo] nvarchar(18) NOT NULL,
    [ProductionDate] datetime NOT NULL,
    [Weight] float NOT NULL,
    [Printed] nvarchar(1) NOT NULL DEFAULT ('N'),
    [OriginCode] nvarchar(10) NOT NULL,
    [FromLoc] nvarchar(10) NOT NULL,
    [ToLoc] nvarchar(10) NOT NULL,
    [Exportstatus] nvarchar(5) NOT NULL DEFAULT ('0'),
    [PrintDate] datetime NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [Lottable01] nvarchar(18) NULL DEFAULT (' '),
    [Lottable03] nvarchar(18) NULL DEFAULT (' '),
    CONSTRAINT [PK_idsStkTrfDocDetail] PRIMARY KEY ([STDNo], [STDLineNO])
);
GO

CREATE UNIQUE INDEX [idx_idsStkTrfDocDetail_ID] ON [dbo].[idsstktrfdocdetail] ([ID]);
GO
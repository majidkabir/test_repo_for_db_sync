CREATE TABLE [dbo].[allocshortagelog]
(
    [OrderKey] nvarchar(10) NOT NULL,
    [OrderLineNumber] nvarchar(5) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL,
    [SKU] nvarchar(20) NOT NULL,
    [OrderedQty] int NOT NULL DEFAULT ((0)),
    [AllocatedQty] int NOT NULL DEFAULT ((0)),
    [QtyOnHand] int NOT NULL DEFAULT ((0)),
    [QtyOnHold] int NOT NULL DEFAULT ((0)),
    [QtyReceiptInProgress] int NOT NULL DEFAULT ((0)),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    CONSTRAINT [PK_AllocShortageLog] PRIMARY KEY ([OrderKey], [OrderLineNumber])
);
GO

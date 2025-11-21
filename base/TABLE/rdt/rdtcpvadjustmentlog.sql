CREATE TABLE [rdt].[rdtcpvadjustmentlog]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [Mobile] int NOT NULL,
    [ADJKey] nvarchar(10) NOT NULL,
    [Type] nvarchar(10) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL,
    [SKU] nvarchar(20) NOT NULL,
    [QTY] int NOT NULL,
    [Lottable07] nvarchar(30) NOT NULL,
    [Lottable08] nvarchar(30) NOT NULL,
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    CONSTRAINT [PK_rdtCPVAdjustmentLog] PRIMARY KEY ([RowRef])
);
GO

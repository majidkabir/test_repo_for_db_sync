CREATE TABLE [rdt].[rdtcpvorderlog]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [Mobile] int NOT NULL,
    [OrderKey] nvarchar(10) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL,
    [SKU] nvarchar(20) NOT NULL,
    [QTY] int NOT NULL,
    [Barcode] nvarchar(60) NOT NULL,
    [Lottable07] nvarchar(30) NOT NULL,
    [Lottable08] nvarchar(30) NOT NULL,
    [Remark] nvarchar(100) NULL DEFAULT (''),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    CONSTRAINT [PK_rdtCPVOrderLog] PRIMARY KEY ([RowRef])
);
GO

CREATE TABLE [dbo].[lotxbilldate]
(
    [Lot] nvarchar(10) NOT NULL,
    [TariffKey] nvarchar(10) NOT NULL,
    [LotBillThruDate] datetime NOT NULL DEFAULT (getdate()),
    [LastActivity] datetime NOT NULL DEFAULT (getdate()),
    [QtyBilledBalance] int NOT NULL DEFAULT ((0)),
    [QtyBilledGrossWeight] float NOT NULL DEFAULT ((0)),
    [QtyBilledNetWeight] float NOT NULL DEFAULT ((0)),
    [QtyBilledCube] float NOT NULL DEFAULT ((0)),
    [AnniversaryStartDate] datetime NULL,
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    CONSTRAINT [PKLOTxBILLDATE] PRIMARY KEY ([Lot]),
    CONSTRAINT [FK_LotXBillDate_LOT_01] FOREIGN KEY ([Lot]) REFERENCES [dbo].[LOT] ([Lot]),
    CONSTRAINT [FK_LotXBillDate_TariffKey_01] FOREIGN KEY ([TariffKey]) REFERENCES [dbo].[Tariff] ([TariffKey])
);
GO

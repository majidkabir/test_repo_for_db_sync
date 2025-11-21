CREATE TABLE [rdt].[rdtgohsettagelog]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [StorerKey] nvarchar(10) NOT NULL,
    [OrderKey] nvarchar(10) NOT NULL,
    [LoadKey] nvarchar(10) NOT NULL,
    [PickDetailKey] nvarchar(10) NOT NULL,
    [DropID] nvarchar(18) NOT NULL,
    [SKU] nvarchar(20) NOT NULL,
    [QTY] int NOT NULL,
    [QTYScan] int NOT NULL,
    [RemainQTY] int NOT NULL,
    [Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PKRdtGOHSettagelog] PRIMARY KEY ([RowRef])
);
GO

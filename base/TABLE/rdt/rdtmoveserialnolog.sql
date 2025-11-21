CREATE TABLE [rdt].[rdtmoveserialnolog]
(
    [MoveSerialNoLogKey] bigint IDENTITY(1,1) NOT NULL,
    [Mobile] int NOT NULL,
    [Func] int NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL,
    [SKU] nvarchar(20) NOT NULL,
    [SerialNo] nvarchar(30) NOT NULL,
    [QTY] int NOT NULL,
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PK_rdtMoveSerialNoLog] PRIMARY KEY ([MoveSerialNoLogKey])
);
GO

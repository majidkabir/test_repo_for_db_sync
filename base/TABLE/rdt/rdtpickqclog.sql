CREATE TABLE [rdt].[rdtpickqclog]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [Mobile] int NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL,
    [PickslipNo] nvarchar(10) NOT NULL,
    [SKU] nvarchar(20) NOT NULL,
    [ScanQTY] int NOT NULL,
    [MovedQTY] int NOT NULL,
    [ReasonCode] nvarchar(20) NOT NULL,
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (getdate()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    CONSTRAINT [PK_RDTPickQCLog] PRIMARY KEY ([RowRef])
);
GO

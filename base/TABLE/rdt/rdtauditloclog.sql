CREATE TABLE [rdt].[rdtauditloclog]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [LOC] nvarchar(10) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL,
    [SKU] nvarchar(20) NOT NULL,
    [QTY] int NOT NULL,
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    CONSTRAINT [PK_rdtAuditLOCLog] PRIMARY KEY ([RowRef])
);
GO

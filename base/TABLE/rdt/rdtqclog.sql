CREATE TABLE [rdt].[rdtqclog]
(
    [SeqNo] int IDENTITY(1,1) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL DEFAULT (' '),
    [PalletID] nvarchar(18) NOT NULL DEFAULT (' '),
    [ScanNo] int NOT NULL DEFAULT ((0)),
    [TranType] nvarchar(10) NOT NULL DEFAULT (' '),
    [CartonID] nvarchar(20) NOT NULL DEFAULT (' '),
    [TriageFlag] nvarchar(10) NOT NULL DEFAULT ('N'),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (' '),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [Status] nvarchar(10) NOT NULL DEFAULT ('0'),
    [MissingCtn] nvarchar(10) NOT NULL DEFAULT (' '),
    [Notes] nvarchar(4000) NULL,
    [Completed] nvarchar(1) NOT NULL DEFAULT ('N'),
    CONSTRAINT [PK_rdtQCLog] PRIMARY KEY ([SeqNo])
);
GO

CREATE INDEX [idx_rdtQCLog_PalletID_CartonID] ON [rdt].[rdtqclog] ([PalletID], [CartonID]);
GO
CREATE TABLE [rdt].[rdtpickpiecelock]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [PickSlipNo] nvarchar(10) NOT NULL,
    [PickZone] nvarchar(10) NOT NULL DEFAULT (''),
    [LOCAisle] nvarchar(10) NOT NULL DEFAULT (''),
    [PickSEQ] nvarchar(1) NOT NULL DEFAULT (''),
    [LockWho] nvarchar(128) NOT NULL DEFAULT (''),
    [LockDate] datetime NULL,
    [AddWho] nvarchar(128) NOT NULL DEFAULT (user_name()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    CONSTRAINT [PK_rdtPickPieceLock] PRIMARY KEY ([RowRef])
);
GO

CREATE UNIQUE INDEX [IX_rdtPickPieceLock01] ON [rdt].[rdtpickpiecelock] ([PickSlipNo], [PickZone], [LOCAisle]);
GO
CREATE TABLE [dbo].[wavedetail]
(
    [WaveDetailKey] nvarchar(10) NOT NULL,
    [WaveKey] nvarchar(10) NOT NULL,
    [OrderKey] nvarchar(10) NOT NULL DEFAULT (' '),
    [ProcessFlag] nvarchar(10) NOT NULL DEFAULT (' '),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PKWAVEDETAIL] PRIMARY KEY ([WaveDetailKey])
);
GO

CREATE INDEX [IX_WAVEDETAIL_OrderKey] ON [dbo].[wavedetail] ([OrderKey]);
GO
CREATE INDEX [IX_WAVEDETAIL_WaveKey] ON [dbo].[wavedetail] ([WaveKey], [WaveDetailKey]);
GO
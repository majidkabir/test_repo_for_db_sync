CREATE TABLE [dbo].[poll_update]
(
    [PollUpdateKey] int IDENTITY(1,1) NOT NULL,
    [UpdateString] nvarchar(250) NOT NULL DEFAULT (' '),
    [Status] nvarchar(10) NOT NULL DEFAULT ('0'),
    [RetryCount] int NOT NULL DEFAULT ((0)),
    [EffectiveDate] datetime NOT NULL DEFAULT (getdate()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL
);
GO

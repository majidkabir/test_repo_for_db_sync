CREATE TABLE [dbo].[poll_allocate]
(
    [orderkey] nvarchar(10) NOT NULL,
    [EffectiveDate] datetime NOT NULL DEFAULT (getdate()),
    [RetryCount] int NOT NULL DEFAULT ((0)),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [TimeStamp] timestamp NULL
);
GO

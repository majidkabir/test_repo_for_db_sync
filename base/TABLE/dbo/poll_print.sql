CREATE TABLE [dbo].[poll_print]
(
    [printtype] nvarchar(10) NOT NULL,
    [orderkey] nvarchar(10) NOT NULL DEFAULT (' '),
    [caseid] nvarchar(10) NOT NULL DEFAULT (' '),
    [dropid] nvarchar(18) NOT NULL DEFAULT (' '),
    [status] nvarchar(10) NOT NULL DEFAULT ('0'),
    [EffectiveDate] datetime NOT NULL DEFAULT (getdate()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL
);
GO

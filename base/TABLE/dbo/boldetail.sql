CREATE TABLE [dbo].[boldetail]
(
    [BolKey] nvarchar(10) NOT NULL,
    [BolLineNumber] nvarchar(5) NOT NULL,
    [OrderKey] nvarchar(10) NOT NULL DEFAULT (' '),
    [Description] nvarchar(30) NOT NULL DEFAULT (' '),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [TimeStamp] nvarchar(18) NULL,
    CONSTRAINT [PKBOLDETAIL] PRIMARY KEY ([BolKey], [BolLineNumber])
);
GO

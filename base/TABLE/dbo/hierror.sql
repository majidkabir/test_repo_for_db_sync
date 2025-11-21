CREATE TABLE [dbo].[hierror]
(
    [HiErrorGroup] nvarchar(10) NOT NULL,
    [ErrorText] nvarchar(254) NOT NULL,
    [ErrorType] nvarchar(20) NOT NULL,
    [SourceKey] nvarchar(20) NOT NULL,
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [TimeStamp] timestamp NULL
);
GO

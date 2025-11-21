CREATE TABLE [dbo].[appointmentstrategydetail]
(
    [AppointmentStrategyKey] nvarchar(10) NOT NULL DEFAULT (''),
    [AppointmentStrategyLineNumber] nvarchar(5) NOT NULL DEFAULT (''),
    [Description] nvarchar(60) NOT NULL DEFAULT (''),
    [FieldName] nvarchar(1000) NOT NULL DEFAULT (''),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PK_AppointmentStrategyDetail] PRIMARY KEY ([AppointmentStrategyKey], [AppointmentStrategyLineNumber])
);
GO

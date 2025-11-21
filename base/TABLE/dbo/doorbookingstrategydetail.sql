CREATE TABLE [dbo].[doorbookingstrategydetail]
(
    [DoorBookingStrategyKey] nvarchar(10) NOT NULL DEFAULT (''),
    [DoorBookingStrategyLineNumber] nvarchar(5) NOT NULL DEFAULT (''),
    [Description] nvarchar(60) NOT NULL DEFAULT (''),
    [Code] nvarchar(60) NOT NULL DEFAULT (''),
    [Value] nvarchar(4000) NOT NULL DEFAULT (''),
    [OptionCodes] nvarchar(4000) NOT NULL DEFAULT (''),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PK_DoorBookingStrategyDetail] PRIMARY KEY ([DoorBookingStrategyKey], [DoorBookingStrategyLineNumber])
);
GO

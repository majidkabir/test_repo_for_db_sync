CREATE TABLE [dbo].[booking_event]
(
    [BookingKey] int IDENTITY(1,1) NOT NULL,
    [BookingNo] int NOT NULL,
    [BookingType] nvarchar(5) NOT NULL DEFAULT (' '),
    [EventCode] nvarchar(30) NOT NULL DEFAULT (' '),
    [EventDate] datetime NULL,
    [ItrStatus] nvarchar(1) NOT NULL,
    [UserDefine01] nvarchar(50) NULL,
    [UserDefine02] nvarchar(50) NULL,
    [UserDefine03] nvarchar(50) NULL,
    [UserDefine04] nvarchar(50) NULL,
    [UserDefine05] nvarchar(50) NULL,
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PK_Booking_Event] PRIMARY KEY ([BookingKey])
);
GO

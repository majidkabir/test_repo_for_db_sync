CREATE TABLE [dbo].[booking_indetail]
(
    [BookingNo] int NOT NULL,
    [BookingLineNumber] nvarchar(5) NOT NULL,
    [TableName] nvarchar(20) NOT NULL,
    [Key1] nvarchar(30) NOT NULL,
    [Key2] nvarchar(30) NOT NULL DEFAULT (''),
    [Key3] nvarchar(30) NOT NULL DEFAULT (''),
    [Remark] nvarchar(1000) NULL,
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    CONSTRAINT [PK_Booking_InDetail] PRIMARY KEY ([BookingNo], [BookingLineNumber])
);
GO

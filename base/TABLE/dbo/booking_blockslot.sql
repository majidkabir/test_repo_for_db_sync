CREATE TABLE [dbo].[booking_blockslot]
(
    [Blockslotkey] nvarchar(10) NOT NULL,
    [Facility] nvarchar(5) NOT NULL DEFAULT (''),
    [Loc] nvarchar(10) NULL,
    [FromDate] datetime NULL DEFAULT (getdate()),
    [ToDate] datetime NULL,
    [FromTime] datetime NULL,
    [ToTime] datetime NULL,
    [Day] int NULL DEFAULT ((0)),
    [Descr] nvarchar(100) NULL,
    [Color] nvarchar(5) NOT NULL DEFAULT ('X'),
    [ColorOnly] nvarchar(1) NOT NULL DEFAULT ('N'),
    CONSTRAINT [PK_Booking_Block] PRIMARY KEY ([Blockslotkey])
);
GO

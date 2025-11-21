CREATE TABLE [dbo].[lotnewbillthrudate]
(
    [Lot] nvarchar(10) NOT NULL DEFAULT (' '),
    [BillThruDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    CONSTRAINT [PKLOTNEWBILLTHRUDATE] PRIMARY KEY ([Lot])
);
GO

CREATE TABLE [dbo].[palletmaster]
(
    [Pallet_type] nvarchar(10) NOT NULL,
    [Descr] nvarchar(60) NULL,
    [Maxcube] float NULL,
    [Maxwgt] float NULL,
    [Maxunit] int NULL,
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    CONSTRAINT [PKPALLETMASTER] PRIMARY KEY ([Pallet_type])
);
GO

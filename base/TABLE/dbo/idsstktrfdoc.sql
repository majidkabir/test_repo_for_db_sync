CREATE TABLE [dbo].[idsstktrfdoc]
(
    [STDNo] nvarchar(10) NOT NULL,
    [Facility] nvarchar(5) NOT NULL,
    [TruckNo] nvarchar(15) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL,
    [DriverName] nvarchar(60) NOT NULL,
    [Finalized] nvarchar(1) NOT NULL,
    [DestCode] nvarchar(10) NOT NULL,
    [WHSEID] nvarchar(5) NOT NULL,
    [TrxType] nvarchar(5) NOT NULL,
    [ReasonCode] nvarchar(10) NOT NULL,
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [SourceID] nvarchar(2) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PK_idsStkTrfDoc] PRIMARY KEY ([STDNo])
);
GO

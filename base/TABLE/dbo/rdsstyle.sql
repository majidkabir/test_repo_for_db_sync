CREATE TABLE [dbo].[rdsstyle]
(
    [Storerkey] nvarchar(15) NOT NULL,
    [Style] nvarchar(20) NOT NULL,
    [StyleDescr] nvarchar(30) NOT NULL,
    [GarmentType] nvarchar(10) NOT NULL,
    [HangFlat] nvarchar(1) NOT NULL,
    [SeasonCode] nvarchar(1) NOT NULL,
    [PO] nvarchar(1) NOT NULL,
    [Gender] nvarchar(10) NULL,
    [Division] nvarchar(18) NULL,
    [NMFCClass] nvarchar(30) NOT NULL,
    [NMFCCode] nvarchar(30) NOT NULL,
    [Remarks] nvarchar(4000) NULL,
    [Status] nvarchar(10) NOT NULL DEFAULT ('0'),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [ArchiveCop] nvarchar(1) NULL,
    [TrafficCop] nvarchar(1) NULL,
    CONSTRAINT [PK_RDSStyle] PRIMARY KEY ([Storerkey], [Style])
);
GO

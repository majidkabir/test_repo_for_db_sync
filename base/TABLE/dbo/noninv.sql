CREATE TABLE [dbo].[noninv]
(
    [Facility] nvarchar(5) NOT NULL,
    [Storerkey] nvarchar(15) NOT NULL,
    [NonInvSku] nvarchar(80) NOT NULL,
    [Descr] nvarchar(80) NULL,
    [InvType] nvarchar(30) NULL DEFAULT (' '),
    [MaintainBalances] nvarchar(30) NULL DEFAULT (' '),
    [LastLoc] nvarchar(10) NULL DEFAULT (' '),
    [CurrentBalance] int NULL DEFAULT ((0)),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PK_NonInv] PRIMARY KEY ([Facility], [Storerkey], [NonInvSku])
);
GO

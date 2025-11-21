CREATE TABLE [dbo].[workstationloc]
(
    [Facility] nvarchar(5) NOT NULL,
    [WorkStation] nvarchar(50) NOT NULL,
    [LocType] nvarchar(10) NOT NULL,
    [Location] nvarchar(10) NOT NULL,
    [TMMVWS] nvarchar(3) NULL,
    [TMMVFG] nvarchar(3) NULL,
    [TMMVOPC] nvarchar(3) NULL,
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PK_WorkStationLoc] PRIMARY KEY ([WorkStation], [LocType], [Location])
);
GO

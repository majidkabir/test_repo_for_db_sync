CREATE TABLE [dbo].[loadplanlanedetail]
(
    [LoadKey] nvarchar(10) NOT NULL DEFAULT (' '),
    [ExternOrderKey] nvarchar(50) NOT NULL,
    [ConsigneeKey] nvarchar(15) NOT NULL,
    [LP_LaneNumber] nvarchar(5) NOT NULL,
    [LocationCategory] nvarchar(10) NOT NULL,
    [LOC] nvarchar(10) NOT NULL,
    [Status] nvarchar(10) NOT NULL DEFAULT ('0'),
    [Notes] nvarchar(215) NOT NULL DEFAULT (''),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [MBOLKey] nvarchar(10) NOT NULL DEFAULT (' '),
    CONSTRAINT [PK_LoadPlanLaneDetail] PRIMARY KEY ([LoadKey], [ExternOrderKey], [ConsigneeKey], [LP_LaneNumber], [MBOLKey])
);
GO

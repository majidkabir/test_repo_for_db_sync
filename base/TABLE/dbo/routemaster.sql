CREATE TABLE [dbo].[routemaster]
(
    [Route] nvarchar(10) NOT NULL,
    [Descr] nvarchar(60) NULL,
    [TruckType] nvarchar(10) NULL,
    [Volume] float NULL,
    [Weight] float NULL,
    [CarrierKey] nvarchar(15) NULL,
    [CarrierDesc] nvarchar(60) NULL,
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [ZipCodeFrom] nvarchar(15) NULL DEFAULT (' '),
    [ZipCodeTo] nvarchar(15) NULL DEFAULT (' '),
    [SelfDelivery] nvarchar(1) NULL,
    [HandledByWH] nvarchar(1) NULL,
    [NoOfDrops] int NULL,
    [TMS_Type] nvarchar(10) NULL,
    [TMS_Interface] nvarchar(1) NULL DEFAULT (' '),
    [ScheduleKey] nvarchar(30) NULL DEFAULT (' '),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    CONSTRAINT [PK_RouteMaster] PRIMARY KEY ([Route])
);
GO

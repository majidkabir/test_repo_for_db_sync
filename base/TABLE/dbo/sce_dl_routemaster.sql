CREATE TABLE [dbo].[sce_dl_routemaster]
(
    [RowRefNo] bigint IDENTITY(1,1) NOT NULL,
    [Route] nvarchar(10) NULL,
    [Descr] nvarchar(60) NULL,
    [TruckType] nvarchar(10) NULL,
    [Volume] float NULL,
    [Weight] float NULL,
    [CarrierKey] nvarchar(15) NULL,
    [CarrierDesc] nvarchar(60) NULL,
    [ZipCodeFrom] nvarchar(15) NULL DEFAULT (' '),
    [ZipCodeTo] nvarchar(15) NULL DEFAULT (' '),
    [SelfDelivery] nvarchar(1) NULL,
    [HandledByWH] nvarchar(1) NULL,
    [NoOfDrops] int NULL,
    [TMS_Type] nvarchar(10) NULL,
    [TMS_Interface] nvarchar(1) NULL DEFAULT (' '),
    [ScheduleKey] nvarchar(30) NULL DEFAULT (' '),
    [AddWho] nvarchar(128) NOT NULL,
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    CONSTRAINT [PK_SCE_DL_ROUTEMASTER] PRIMARY KEY ([RowRefNo])
);
GO

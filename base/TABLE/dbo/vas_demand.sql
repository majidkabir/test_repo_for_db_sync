CREATE TABLE [dbo].[vas_demand]
(
    [VASDemandKey] bigint IDENTITY(1,1) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL DEFAULT (''),
    [Brand] nvarchar(15) NOT NULL DEFAULT (''),
    [Catogry] nvarchar(45) NULL,
    [Charge] nvarchar(5) NOT NULL DEFAULT (''),
    [VASMode] nvarchar(10) NOT NULL DEFAULT (''),
    [Type] nvarchar(10) NOT NULL DEFAULT (''),
    [OperationType] nvarchar(5) NOT NULL DEFAULT (''),
    [Priority] nvarchar(10) NOT NULL DEFAULT (''),
    [RepackCode] nvarchar(20) NOT NULL DEFAULT (''),
    [SOSDate] datetime NULL,
    [Qty] int NOT NULL DEFAULT ((0)),
    [UOM] nvarchar(10) NOT NULL DEFAULT (''),
    [SKUReady] nchar(1) NOT NULL DEFAULT (''),
    [BOMReady] nchar(1) NOT NULL DEFAULT (''),
    [PIReady] nchar(1) NOT NULL DEFAULT (''),
    [PMReady] nchar(1) NOT NULL DEFAULT (''),
    [ComponentReady] nchar(1) NOT NULL DEFAULT (''),
    [Status] nvarchar(20) NOT NULL DEFAULT ('WAIT'),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    CONSTRAINT [PK_VAS_Demand] PRIMARY KEY ([VASDemandKey])
);
GO

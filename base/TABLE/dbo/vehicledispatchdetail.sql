CREATE TABLE [dbo].[vehicledispatchdetail]
(
    [VehicleDispatchKey] nvarchar(10) NOT NULL DEFAULT (''),
    [VehicleDispatchLineNumber] nvarchar(5) NOT NULL DEFAULT (''),
    [Orderkey] nvarchar(10) NULL DEFAULT (''),
    [ExternOrderkey] nvarchar(50) NOT NULL DEFAULT (''),
    [OrderLineNumber] nvarchar(10) NULL DEFAULT (''),
    [Storerkey] nvarchar(15) NULL DEFAULT (''),
    [Sku] nvarchar(20) NOT NULL DEFAULT (''),
    [Qty] int NOT NULL DEFAULT ((0)),
    [Cube] float NULL DEFAULT ((0.00)),
    [Weight] float NULL DEFAULT ((0.00)),
    [NoOfPallet] int NULL DEFAULT ((0)),
    [NoOfCarton] int NULL DEFAULT ((0)),
    [FinalizeFlag] nvarchar(1) NOT NULL DEFAULT ('N'),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(18) NOT NULL DEFAULT (suser_name()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(18) NOT NULL DEFAULT (suser_name()),
    CONSTRAINT [PK_VehicleDispatchDetail] PRIMARY KEY ([VehicleDispatchKey], [VehicleDispatchLineNumber])
);
GO

CREATE INDEX [IDX_VehicleDispatchDetail_ExternOrderkey] ON [dbo].[vehicledispatchdetail] ([ExternOrderkey]);
GO
CREATE INDEX [IDX_VehicleDispatchDetail_OrderLineNumber] ON [dbo].[vehicledispatchdetail] ([Orderkey], [OrderLineNumber]);
GO
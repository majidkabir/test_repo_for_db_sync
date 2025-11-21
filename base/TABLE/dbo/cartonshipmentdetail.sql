CREATE TABLE [dbo].[cartonshipmentdetail]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [Storerkey] nvarchar(15) NULL,
    [Orderkey] nvarchar(10) NULL,
    [Loadkey] nvarchar(10) NULL,
    [Mbolkey] nvarchar(10) NULL,
    [Externorderkey] nvarchar(50) NULL,
    [Buyerpo] nvarchar(20) NULL,
    [UCCLabelNo] nvarchar(20) NULL,
    [CartonWeight] float NULL,
    [DestinationZipCode] nvarchar(18) NULL,
    [CarrierCode] nvarchar(10) NULL,
    [ClassOfService] nvarchar(10) NULL,
    [TrackingIdType] nvarchar(10) NULL,
    [FormCode] nvarchar(10) NULL,
    [TrackingNumber] nvarchar(30) NULL,
    [GroundBarcodeString] nvarchar(30) NULL,
    [RoutingCode] nvarchar(10) NULL,
    [ASTRA_Barcode] nvarchar(45) NULL,
    [PlannedServiceLevel] nvarchar(30) NULL,
    [ServiceTypeDescription] nvarchar(45) NULL,
    [SpecialHandlingIndicators] nvarchar(30) NULL,
    [DestinationAirportID] nvarchar(5) NULL,
    [ServiceCode] nvarchar(5) NULL,
    [Adddate] datetime NOT NULL DEFAULT (getdate()),
    [Addwho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [2dBarcode] nvarchar(1000) NULL,
    [CartonCube] float NULL,
    [FreightCharge] float NULL,
    [InsCharge] float NULL,
    [Editdate] datetime NOT NULL DEFAULT (getdate()),
    [Editwho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [PackageID] nvarchar(30) NULL,
    [UPS_RoutingCode] nvarchar(20) NULL,
    [UPS_URCVersion] nvarchar(30) NULL,
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PK_cartonshipmentdetail] PRIMARY KEY ([RowRef])
);
GO

CREATE INDEX [IX_CartonShipmentDetail_ExtrnOrd] ON [dbo].[cartonshipmentdetail] ([Externorderkey], [Storerkey]);
GO
CREATE INDEX [IX_CartonShipmentDetail_OrdKeyLblNo] ON [dbo].[cartonshipmentdetail] ([Orderkey], [UCCLabelNo]);
GO
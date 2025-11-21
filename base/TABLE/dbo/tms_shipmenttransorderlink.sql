CREATE TABLE [dbo].[tms_shipmenttransorderlink]
(
    [Rowref] int IDENTITY(1,1) NOT NULL,
    [ProvShipmentID] nvarchar(50) NOT NULL,
    [ShipmentGID] nvarchar(50) NOT NULL,
    CONSTRAINT [PKTMS_ShipmentTransOrderLink] PRIMARY KEY ([Rowref])
);
GO

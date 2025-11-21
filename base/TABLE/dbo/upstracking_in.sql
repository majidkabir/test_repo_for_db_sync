CREATE TABLE [dbo].[upstracking_in]
(
    [RowID] int IDENTITY(1,1) NOT NULL,
    [CartonID] nvarchar(20) NOT NULL DEFAULT (''),
    [WMS_RefKey] nvarchar(30) NOT NULL DEFAULT (''),
    [WMS_RefType] nvarchar(2) NULL DEFAULT (''),
    [ServiceIndicator] nvarchar(30) NULL DEFAULT (''),
    [UPSTrackingNo] nvarchar(18) NULL DEFAULT (''),
    [FreightCharge] nvarchar(19) NULL DEFAULT ((0)),
    [InsuranceCharge] nvarchar(19) NULL DEFAULT ((0)),
    [Weight] nvarchar(19) NULL DEFAULT ((0)),
    [VoidIndicator] nvarchar(1) NULL,
    [Status] nvarchar(1) NULL DEFAULT ('0'),
    [AddDate] datetime NULL DEFAULT (getdate()),
    CONSTRAINT [PK_UPSTracking_In] PRIMARY KEY ([RowID])
);
GO

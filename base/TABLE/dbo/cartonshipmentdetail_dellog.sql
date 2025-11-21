CREATE TABLE [dbo].[cartonshipmentdetail_dellog]
(
    [Rowref] int IDENTITY(1,1) NOT NULL,
    [RowRefSource] int NOT NULL,
    [Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [ArchiveCop] nvarchar(1) NULL,
    [Storerkey] nvarchar(15) NULL,
    [Orderkey] nvarchar(10) NULL,
    [Externorderkey] nvarchar(50) NULL,
    [CarrierCode] nvarchar(10) NULL,
    [TrackingIDType] nvarchar(10) NULL,
    CONSTRAINT [PK_cartonshipmentdetail_dellog] PRIMARY KEY ([Rowref])
);
GO

CREATE TABLE [dbo].[ids_consignee_thai]
(
    [customer_id] int NOT NULL,
    [customer_number] nvarchar(30) NOT NULL,
    [customer_name] nvarchar(150) NOT NULL,
    [location_number] nvarchar(30) NOT NULL,
    [address6] nvarchar(150) NOT NULL,
    [address1] nvarchar(150) NULL,
    [address2] nvarchar(150) NULL,
    [address3] nvarchar(150) NULL,
    [address4] nvarchar(150) NULL,
    CONSTRAINT [PK_IDS_CONSIGNEE_THAI] PRIMARY KEY ([customer_number], [address6])
);
GO

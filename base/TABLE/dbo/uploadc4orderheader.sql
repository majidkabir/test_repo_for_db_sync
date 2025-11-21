CREATE TABLE [dbo].[uploadc4orderheader]
(
    [Orderkey] nvarchar(10) NOT NULL,
    [Storerkey] nvarchar(15) NULL,
    [externorderkey] nvarchar(50) NULL,
    [OrderGroup] nvarchar(10) NULL,
    [Orderdate] datetime NULL DEFAULT (getdate()),
    [Deliverydate] datetime NULL DEFAULT (getdate()),
    [Type] nvarchar(10) NULL,
    [ConsigneeKey] nvarchar(15) NULL,
    [Priority] nvarchar(10) NULL DEFAULT ('5'),
    [Salesman] nvarchar(10) NULL,
    [c_contact1] nvarchar(30) NULL,
    [c_contact2] nvarchar(30) NULL,
    [c_company] nvarchar(45) NULL,
    [c_address1] nvarchar(45) NULL,
    [c_address2] nvarchar(45) NULL,
    [c_address3] nvarchar(45) NULL,
    [c_address4] nvarchar(45) NULL,
    [c_city] nvarchar(45) NULL,
    [c_state] nvarchar(2) NULL,
    [c_zip] nvarchar(18) NULL,
    [buyerpo] nvarchar(20) NULL,
    [notes] nvarchar(80) NULL,
    [invoiceno] nvarchar(10) NULL,
    [notes2] nvarchar(80) NULL,
    [pmtterm] nvarchar(10) NULL,
    [invoiceamount] float NULL,
    [ROUTE] nvarchar(10) NULL DEFAULT ('99'),
    [Mode] nvarchar(3) NULL,
    [status] nvarchar(1) NULL DEFAULT ('0'),
    [remarks] nvarchar(150) NULL,
    [AddDate] datetime NULL DEFAULT (getdate()),
    [ExternPOKey] nvarchar(20) NULL,
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    CONSTRAINT [PK_UPLOADC4ORDERHEADER] PRIMARY KEY ([Orderkey])
);
GO

CREATE INDEX [IX_UPLOADC4ORDERHEADER_ExtOrderKey] ON [dbo].[uploadc4orderheader] ([externorderkey]);
GO
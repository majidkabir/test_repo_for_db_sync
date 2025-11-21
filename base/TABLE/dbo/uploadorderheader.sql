CREATE TABLE [dbo].[uploadorderheader]
(
    [Orderkey] nvarchar(10) NULL,
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
    [AddDate] datetime NULL DEFAULT (getdate())
);
GO

CREATE INDEX [IX_externorderkey] ON [dbo].[uploadorderheader] ([externorderkey]);
GO
CREATE INDEX [IX_status] ON [dbo].[uploadorderheader] ([status]);
GO
CREATE UNIQUE INDEX [IX_orderkey] ON [dbo].[uploadorderheader] ([Orderkey]);
GO
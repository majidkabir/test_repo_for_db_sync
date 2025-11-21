CREATE TABLE [dbo].[ids_label_count]
(
    [storerkey] nvarchar(15) NOT NULL,
    [salesord] nvarchar(30) NOT NULL,
    [shipdate] nvarchar(10) NULL,
    [consigneekey] nvarchar(15) NULL,
    [company] nvarchar(45) NULL,
    [addr1] nvarchar(45) NULL,
    [addr2] nvarchar(45) NULL,
    [addr3] nvarchar(45) NULL,
    [addr4] nvarchar(45) NULL,
    [city] nvarchar(45) NULL,
    [zip] nvarchar(18) NULL,
    [phone] nvarchar(18) NULL,
    [nocarton] int NULL,
    [printdate] datetime NOT NULL,
    CONSTRAINT [PK_ids_label_count] PRIMARY KEY ([storerkey], [salesord], [printdate])
);
GO

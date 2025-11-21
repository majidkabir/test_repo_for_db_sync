CREATE TABLE [dbo].[uploadinvdata]
(
    [Storerkey] nvarchar(15) NULL,
    [ExternOrderkey] nvarchar(50) NULL,
    [Invoice_Number] nvarchar(10) NULL,
    [Invoice_Date] datetime NULL,
    [Invoice_Amount] nvarchar(10) NULL,
    [Status] nvarchar(1) NULL DEFAULT ('0'),
    [Remarks] nvarchar(255) NULL
);
GO

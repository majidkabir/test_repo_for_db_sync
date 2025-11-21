CREATE TABLE [dbo].[pbsrpt_category]
(
    [category_id] int NOT NULL,
    [category] nvarchar(40) NOT NULL,
    CONSTRAINT [category_id_ndx] PRIMARY KEY ([category_id])
);
GO

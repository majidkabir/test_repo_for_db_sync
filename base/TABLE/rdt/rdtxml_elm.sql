CREATE TABLE [rdt].[rdtxml_elm]
(
    [mobile] int NOT NULL,
    [typ] nvarchar(20) NULL,
    [x] nvarchar(10) NULL,
    [y] nvarchar(10) NULL,
    [length] nvarchar(10) NULL,
    [id] nvarchar(20) NULL,
    [default] nvarchar(60) NULL,
    [type] nvarchar(20) NULL,
    [value] nvarchar(125) NULL,
    [ltext] nvarchar(125) NULL DEFAULT (''),
    [dcolor] nvarchar(50) NULL DEFAULT (''),
    [vmatch] nvarchar(50) NULL DEFAULT (''),
    [Rowid] int IDENTITY(1,1) NOT NULL,
    CONSTRAINT [PKRDTXML_Elm] PRIMARY KEY ([Rowid])
);
GO

CREATE INDEX [IX_RDTXML_Elm_Mobile] ON [rdt].[rdtxml_elm] ([mobile], [id], [typ]);
GO
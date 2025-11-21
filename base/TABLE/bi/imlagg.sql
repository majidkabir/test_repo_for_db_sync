CREATE TABLE [bi].[imlagg]
(
    [PromoID] smallint NOT NULL,
    [Batch] int NOT NULL,
    [DATETIME] smalldatetime NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL,
    [ModifyDate] datetime NOT NULL DEFAULT (getdate()),
    [num_CALLS_SWebServiceLog_IN] bigint NOT NULL,
    [num_CALLS_SWebServiceLog_OUT] bigint NOT NULL,
    [num_IML_IN_File] int NULL,
    [num_IML_OUT_File] int NULL,
    CONSTRAINT [PK_IMLAgg] PRIMARY KEY ([StorerKey])
);
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Stored Procedure: isp_SCE_DL_GenericImportStagingData                */
/* Creation Date: 27-Aug-2021                                           */
/* Copyright: LFL                                                       */
/* Written by: GHChan                                                   */
/*                                                                      */
/* Purpose: Generic import staging data                                 */
/*                                                                      */
/* Called By:  SCE Data Loader                                          */
/*                                                                      */
/* PVCS Version: -                                                      */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 27-Aug-2021  GHChan   1.0  Initial Development                       */
/************************************************************************/
CREATE PROC [dbo].[isp_SCE_DL_GenericImportStagingData] (
   @json        NVARCHAR(MAX) = ''
 , @c_TableName NVARCHAR(255) = ''
 , @SQL         NVARCHAR(MAX) = '' OUTPUT
)
AS
BEGIN
   DECLARE @SQL1 NVARCHAR(MAX) = N'';
   DECLARE @FirstRow NVARCHAR(MAX) = (
           SELECT TOP 1 Value
           FROM OPENJSON(@json)
           );

   DECLARE @Columns TABLE (
      Position     INT         IDENTITY PRIMARY KEY
    , ColumnName   sysname     NOT NULL UNIQUE
    , JSONDataType INT         NULL
    , SQLDataType  VARCHAR(30) NULL
   );

   DECLARE @DbColumns TABLE (
      ColumnName  NVARCHAR(255)
    , DataType    NVARCHAR(255)
    , [MaxLength] INT
    , IsNullable  BIT
   );

   INSERT INTO @DbColumns
   (
      ColumnName
    , DataType
    , [MaxLength]
    , IsNullable
   )
   (SELECT UPPER(c.[name])
         , UPPER(t.[name])
         , CASE WHEN t.[name] IN ('nvarchar', 'nchar', 'ntext') THEN IIF(c.max_length = -1, c.max_length, (c.max_length / 2))
                WHEN t.[name] IN ('varchar', 'char', 'varbinary', 'binary', 'text') THEN c.max_length
                ELSE 0
           END
         , c.is_nullable
    FROM sys.columns     c WITH (NOLOCK)
    INNER JOIN sys.types t WITH (NOLOCK)
    ON c.user_type_id = t.user_type_id
    WHERE c.object_id = OBJECT_ID(@c_TableName));

   INSERT INTO @Columns
   (
      ColumnName
    , JSONDataType
    , SQLDataType
   )
   SELECT [Key]
        , Type
        , CASE Type WHEN 0 THEN 'NULL'
                    WHEN 1 THEN 'nvarchar(1000)'
                    WHEN 2 THEN 'float'
                    WHEN 3 THEN 'bit'
                    ELSE ''
          END
   FROM OPENJSON(@FirstRow);

   SET @SQL = '('
              + (
                SELECT CHAR(13) + CHAR(10) + CHAR(9) + '[' + c.ColumnName + '] ' + UPPER(t.[name])
                       + CASE WHEN t.[name] IN ('varchar', 'char', 'varbinary', 'binary', 'text') THEN
                                   '('
                                   + CASE WHEN sysC.max_length = -1 THEN 'MAX'
                                          ELSE
                                               CAST(sysC.max_length AS NVARCHAR(5))
                                     END + ')'
                              WHEN t.[name] IN ('nvarchar', 'nchar', 'ntext') THEN
                                   '('
                                   + CASE WHEN sysC.max_length = -1 THEN 'MAX'
                                          ELSE
                                               CAST(sysC.max_length / 2 AS NVARCHAR(5))
                                     END + ')'
                              WHEN t.[name] IN ('decimal', 'numeric') THEN
                                   '(' + CAST(sysC.precision AS NVARCHAR(5)) + ',' + CAST(sysC.scale AS NVARCHAR(5)) + ')'
                              ELSE ''
                         END + CASE WHEN c.Position = MAX(c.Position) OVER () THEN ''
                                    ELSE                                                                             ','
                               END
                FROM @Columns          c
                INNER JOIN sys.columns sysC WITH (NOLOCK)
                ON c.ColumnName      = sysC.[name]
                INNER JOIN sys.types   t WITH (NOLOCK)
                ON sysC.user_type_id = t.user_type_id
                WHERE sysC.object_id = OBJECT_ID(@c_TableName)
                --JOIN @DbColumns dbC  
                --ON RTRIM(c.ColumnName) = RTRIM(dbC.ColumnName)  
                ORDER BY c.Position
                FOR XML PATH(''), TYPE
                ).value('.', 'nvarchar(max)') + CHAR(13) + CHAR(10) + ')';

   SET @SQL1 = N'('
               + (
                 SELECT CHAR(13) + CHAR(10) + CHAR(9) + '[' + c.ColumnName + ']'
                        + CASE WHEN c.Position = MAX(c.Position) OVER () THEN ''
                               ELSE ','
                          END
                 FROM @Columns   c
                 JOIN @DbColumns dbC
                 ON RTRIM(c.ColumnName) = RTRIM(dbC.ColumnName)
                 ORDER BY c.Position
                 FOR XML PATH(''), TYPE
                 ).value('.', 'nvarchar(max)') + CHAR(13) + CHAR(10) + N')';

   SET @SQL = 'INSERT INTO ' + @c_TableName + ' ' + @SQL1 + CHAR(13) + CHAR(10) + 'SELECT * FROM OPENJSON(@json) WITH' + @SQL;
END;

GO
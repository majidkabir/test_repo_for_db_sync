SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Stored Procedure: isp_SCE_DL_PlainInsert                             */
/* Creation Date: 27-Aug-2021                                           */
/* Copyright: LFL                                                       */
/* Written by: GHChan                                                   */
/*                                                                      */
/* Purpose: Plain Insert data from STG TABLE into TGT Table.            */
/*                                                                      */
/* Called By:  SCE Data Loader                                          */
/*                                                                      */
/* PVCS Version: -                                                      */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 27-Aug-2021  GHChan   1.0  Initial Development                       */
/************************************************************************/
CREATE PROC [dbo].[isp_SCE_DL_PlainInsert] (
   @b_Debug   INT           = 0
 , @n_BatchNo INT           = 0
 , @c_STGTBL  NVARCHAR(250) = ''
 , @c_POSTTBL NVARCHAR(250) = ''
 , @b_Success INT           = 0 OUTPUT
 , @n_ErrNo   INT           = 0 OUTPUT
 , @c_ErrMsg  NVARCHAR(250) = '' OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON;
   SET ANSI_DEFAULTS OFF;
   SET QUOTED_IDENTIFIER OFF;
   SET CONCAT_NULL_YIELDS_NULL ON;
   SET ANSI_NULLS ON;
   SET ANSI_WARNINGS ON;
   SET ANSI_PADDING ON;

   /*********************************************/
   /* Variables Declaration (Start)             */
   /*********************************************/

   DECLARE @n_Continue   INT            = 1
         , @n_StartCnt   INT            = @@TRANCOUNT
         , @SQL          NVARCHAR(MAX)  = N''
         , @SQL1         NVARCHAR(MAX)  = N''
         , @SQL2         NVARCHAR(MAX)  = N''
         , @SQL3         NVARCHAR(MAX)  = N''
         --, @SQL4           NVARCHAR(MAX)  = ''
         --, @c_FParams      NVARCHAR(MAX) = ''
         --, @c_DCLParams    NVARCHAR(MAX) = ''
         , @c_ExecArgs1  NVARCHAR(2000) = N''
         , @c_ExecArgs2  NVARCHAR(2000) = N''
         , @c_lColumns   NVARCHAR(MAX)  = N''
         , @n_RowRefNo   INT
         , @n_RowCount   INT
         , @c_STG_Status NVARCHAR(2)
         , @c_STG_ErrMsg NVARCHAR(250);

   SET @b_Success = 1;

   DECLARE @DbColumns TABLE (
      Rowref     INT           IDENTITY(1, 1) NOT NULL
    , ColumnName NVARCHAR(255) NOT NULL
   --, DataType   NVARCHAR(100) NOT NULL
   );

   DECLARE @t TABLE (ID INT);
   /*********************************************/
   /* Variables Declaration (End)               */
   /*********************************************/

   BEGIN TRY
      INSERT INTO @DbColumns (ColumnName)
      SELECT UPPER(c.[name])
      FROM sys.columns               c WITH (NOLOCK)
      LEFT JOIN sys.identity_columns ic WITH (NOLOCK)
      ON  c.is_identity  = 1
      AND c.[object_id] = ic.[object_id]
      AND c.column_id   = ic.column_id
      WHERE c.object_id   = OBJECT_ID(@c_POSTTBL)
      AND   (
             ic.is_identity      <> 1
          OR ic.is_identity IS NULL
          OR ic.is_identity = 0
      );

      SELECT @c_lColumns = STUFF((
                                 SELECT ',' + QUOTENAME(ColumnName)
                                 FROM @DbColumns
                                 ORDER BY Rowref ASC
                                 FOR XML PATH('')
                                 ), 1, 1, ''
                           );

      SET @SQL1 = N''
      SET @c_ExecArgs1 = N'';

      SET @SQL1 = N' SELECT RowRefNo FROM ' + @c_STGTBL + ' WITH(NOLOCK) WHERE STG_BatchNo=@n_BatchNo AND STG_Status=''1'' ' 

      SET @c_ExecArgs1 = N' @n_BatchNo INT';

      IF @b_Debug = 1
      BEGIN
         PRINT @SQL1;
      END;

      INSERT INTO @t (ID)
      EXEC sp_executesql @SQL1
                        , @c_ExecArgs1
                        , @n_BatchNo;
      IF @b_Debug = 1
      BEGIN
         SELECT ID FROM @t
      END;

      SET @SQL1 = N''
      SET @c_ExecArgs1 = N'';

      SET @SQL2 = N''
      SET @c_ExecArgs2 = N'';

      SET @SQL1 = N' INSERT INTO ' + @c_POSTTBL + N'(' + @c_lColumns + N') ' 
                + N' SELECT ' + @c_lColumns + N' FROM ' + @c_STGTBL + N' WITH(NOLOCK) ' 
                + N' WHERE RowRefNo=@n_RowRefNo '

      SET @c_ExecArgs1 = N' @n_RowRefNo INT';

      SET @SQL2 = N' UPDATE ' + @c_STGTBL + N' WITH (ROWLOCK) '
                + N' SET STG_Status = @c_STG_Status , STG_ErrMsg =  @c_STG_ErrMsg '
                + N' WHERE RowRefNo=@n_RowRefNo '

      SET @c_ExecArgs2 = N' @c_STG_Status NVARCHAR(2) '
                       + N',@c_STG_ErrMsg NVARCHAR(250) '
                       + N',@n_RowRefNo INT ';

      IF @b_Debug = 1
      BEGIN
         PRINT @SQL1;
         PRINT @SQL2;
      END;

      WHILE EXISTS(SELECT 1 FROM @t)
      BEGIN
         SET @n_RowCount = 0

         SELECT TOP (1) @n_RowRefNo=ID 
         FROM @t 
         ORDER BY ID ASC
            
         EXEC sp_executesql @SQL1
                        , @c_ExecArgs1
                        , @n_RowRefNo;
         SET @n_RowCount = @@ROWCOUNT

         SET @c_STG_Status = CASE WHEN @n_RowCount = 1 THEN '9' ELSE '5' END
         SET @c_STG_ErrMsg = CASE WHEN @n_RowCount = 1 THEN ''  ELSE 'Failed to insert records into target table.' END

         EXEC sp_executesql @SQL2
                        , @c_ExecArgs2
                        , @c_STG_Status
                        , @c_STG_ErrMsg
                        , @n_RowRefNo;

         IF @@ROWCOUNT = 0
         BEGIN
            SET @n_Continue = 3;
            SET @b_Success = 0;
            SET @n_ErrNo = N'13000';
            SET @c_ErrMsg = N'Failed to Update Staging Records Status!' + '(isp_SCE_DL_PlainInsert)';
            GOTO QUIT
         END

         DELETE FROM @t WHERE ID = @n_RowRefNo
      END

   --INSERT INTO @DbColumns (ColumnName,DataType)
   --SELECT   UPPER(c.[name]) AS [ColumnName] 
   --      ,  CASE 
   --      WHEN ISNULL(RTRIM(LOWER(t.[name])),'') = 'char'     THEN ' CHAR('+CASE WHEN c.max_length = -1 THEN 'MAX' ELSE CAST(c.max_length AS NVARCHAR(5) ) END+')'
   --      WHEN ISNULL(RTRIM(LOWER(t.[name])),'') = 'nchar'    THEN ' NCHAR('+CASE WHEN c.max_length = -1 THEN 'MAX' ELSE CAST(c.max_length/2 AS NVARCHAR(5) ) END+')' 
   --      WHEN ISNULL(RTRIM(LOWER(t.[name])),'') = 'varchar'  THEN ' VARCHAR('+CASE WHEN c.max_length = -1 THEN 'MAX' ELSE CAST(c.max_length AS NVARCHAR(5) ) END+')' 
   --      WHEN ISNULL(RTRIM(LOWER(t.[name])),'') = 'nvarchar' THEN ' NVARCHAR('+CASE WHEN c.max_length = -1 THEN 'MAX' ELSE CAST(c.max_length/2 AS NVARCHAR(5) ) END+')' 
   --      --WHEN ISNULL(RTRIM(LOWER(t.[name])),'') = 'text'     THEN ' TEXT = ''''' 
   --      --WHEN ISNULL(RTRIM(LOWER(t.[name])),'') = 'ntext'    THEN ' NTEXT = ''''' 
   --      WHEN ISNULL(RTRIM(LOWER(t.[name])),'') = 'binary'   THEN ' BINARY('+CASE WHEN c.max_length = -1 THEN 'MAX' ELSE CAST(c.max_length AS NVARCHAR(5) ) END+')' 
   --      WHEN ISNULL(RTRIM(LOWER(t.[name])),'') = 'varbinary'THEN ' VARBINARY('+CASE WHEN c.max_length = -1 THEN 'MAX' ELSE CAST(c.max_length AS NVARCHAR(5) ) END+')' 
   --      WHEN ISNULL(RTRIM(LOWER(t.[name])),'') = 'decimal'THEN ' DECIMAL('+CAST(c.precision AS NVARCHAR(5) )+',' + CAST(c.scale AS NVARCHAR(5) ) + ')' 
   --      WHEN ISNULL(RTRIM(LOWER(t.[name])),'') = 'numeric'THEN ' NUMERIC('+CAST(c.precision AS NVARCHAR(5) )+',' + CAST(c.scale AS NVARCHAR(5) ) + ')' 
   --      --WHEN ISNULL(RTRIM(LOWER(t.[name])),'') = 'image'    THEN ' IMAGE = ''''' 
   --      --WHEN ISNULL(RTRIM(LOWER(t.[name])),'') = 'datetime' THEN ' DATETIME' 
   --      --WHEN ISNULL(RTRIM(LOWER(t.[name])),'') = 'date'     THEN ' DATE' 
   --      ELSE ' ' + UPPER(t.[name])
   --   END--+dbC.DataType  
   --FROM sys.columns c  WITH(NOLOCK) 
   --INNER JOIN sys.types t WITH (NOLOCK) 
   --   ON c.user_type_id = t.user_type_id   
   --LEFT JOIN sys.identity_columns ic WITH (NOLOCK) 
   --   ON c.is_identity = 1 
   --   AND c.[object_id] = ic.[object_id] 
   --   AND c.column_id = ic.column_id
   --WHERE c.object_id = OBJECT_ID(@c_POSTTBL)
   --AND (ic.is_identity <> 1 OR ic.is_identity IS NULL OR ic.is_identity = 0)

   --SELECT @c_DCLParams = STUFF((SELECT ',' + '@C' + CAST(Rowref AS NVARCHAR(4)) + '' + DataType
   --FROM @DbColumns
   --ORDER BY Rowref ASC
   --FOR XML PATH('')), 1, 1, '') 

   --SELECT @c_FParams = STUFF((SELECT ',' + '@C' + CAST(Rowref AS NVARCHAR(4))
   --FROM @DbColumns
   --ORDER BY Rowref ASC
   --FOR XML PATH('')), 1, 1, '') 

   --SET @SQL1 = N' DECLARE @C0 INT ' --, @nCnt INT, @nTtlCnt INT
   --          --+ N' SET @nCnt=0 '
   --          --+ N' SELECT @nTtlCnt=COUNT(1) FROM ' + @c_STGTBL + ' WITH(NOLOCK) '
   --          --+ N' WHERE STG_BatchNo=@n_BatchNo '
   --          + N' DECLARE @t TABLE (ID INT) '
   --          + N' INSERT INTO @t (ID) SELECT RowRefNo FROM ' + @c_STGTBL + ' WITH(NOLOCK) ' 
   --          + N' WHERE STG_BatchNo=@n_BatchNo '
   --          + N' AND STG_Status=''1'' '
   --          + N' WHILE EXISTS(SELECT 1 FROM @t) '
   --          + N' BEGIN '
   --          + N' SELECT TOP (1) @C0=ID FROM @t ' 
   --          --+ N' IF EXISTS(SELECT 1 FROM ' + @c_STGTBL + ' WITH(NOLOCK) WHERE RowRefNo=@C0 ) '
   --          --+ N' BEGIN '
   --          + N' INSERT INTO ' + @c_POSTTBL + '(' + @c_lColumns + ') ' 
   --SET @SQL2 = N' SELECT ' + @c_lColumns + ' FROM ' + @c_STGTBL + ' WITH(NOLOCK) ' 
   --          + N' WHERE RowRefNo=@C0 ' 
   --          + N' IF @@ROWCOUNT = 1 '
   --          + N' BEGIN '
   --          + N' UPDATE  ' + @c_STGTBL + ' WITH (ROWLOCK) '
   --          + N' SET STG_Status =''9'' '
   --          + N' WHERE RowRefNo = @C0'
   --          + N' END '
   --          + N' ELSE '
   --SET @SQL3 = N' BEGIN '
   --          + N' UPDATE  ' + @c_STGTBL + ' WITH (ROWLOCK) '
   --          + N' SET STG_Status =''5'' '
   --          + N' ,STG_ErrMsg=''Failed to insert records into target table.'' '
   --          + N' WHERE RowRefNo = @C0'
   --          + N' END '
   --          --+ N' END '
   --          + N' DELETE FROM @t WHERE ID=@C0'
   --          --+ N' SET @nCnt += 1'
   --          + N' END '


   --SET @SQL1 = N' DECLARE @C0 INT, @RC INT '
   --          + N' DECLARE @t TABLE (ID INT) '
   --          + N' INSERT INTO @t (ID) SELECT RowRefNo FROM ' + @c_STGTBL + ' WITH(NOLOCK) ' 
   --          + N' WHERE STG_BatchNo=@n_BatchNo '
   --          + N' AND STG_Status=''1'' '
   --          + N' WHILE EXISTS(SELECT 1 FROM @t) '
   --          + N' BEGIN '
   --          + N' SET @RC=0 '
   --          + N' SELECT TOP (1) @C0=ID FROM @t ' 
   --          + N' INSERT INTO ' + @c_POSTTBL + '(' + @c_lColumns + ') ' 
   --SET @SQL2 = N' SELECT ' + @c_lColumns + ' FROM ' + @c_STGTBL + ' WITH(NOLOCK) ' 
   --          + N' WHERE RowRefNo=@C0 ' 
   --          + N' SET @RC=@@ROWCOUNT '
   --          + N' UPDATE ' + @c_STGTBL + ' WITH (ROWLOCK) '
   --          + N' SET STG_Status = CASE WHEN @RC = 1 THEN ''9'' ELSE ''5'' END '
   --          + N' ,STG_ErrMsg = CASE WHEN @RC = 1 THEN '''' ELSE ''Failed to insert records into target table.'' END '
   --          + N' WHERE RowRefNo=@C0 '
   --          + N' DELETE FROM @t WHERE ID=@C0 '
   --          + N' END '

   END TRY
   BEGIN CATCH
      SET @n_Continue = 3;
      SET @b_Success = 0;
      SET @n_ErrNo = N'13001';
      SET @c_ErrMsg = N'Failed to Insert Records in Target Table!' + ERROR_MESSAGE() + '(isp_SCE_DL_PlainInsert)';
   END CATCH;

   QUIT:

   IF @n_Continue = 3 -- Error Occured - Process And Return          
   BEGIN
      SELECT @b_Success = 0;
      IF  @@TRANCOUNT = 1
      AND @@TRANCOUNT > @n_StartCnt
      BEGIN
         ROLLBACK TRAN;
      END;
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartCnt
         BEGIN
            COMMIT TRAN;
         END;
      END;

      RETURN;
   END;
   ELSE
   BEGIN
      IF ISNULL(RTRIM(@c_ErrMsg), '') <> ''
      BEGIN
         SELECT @b_Success = 0;
      END;
      ELSE
      BEGIN
         SELECT @b_Success = 1;
      END;

      WHILE @@TRANCOUNT > @n_StartCnt
      BEGIN
         COMMIT TRAN;
      END;

      RETURN;
   END;
/***********************************************/
/* Std - Error Handling (End)                  */
/***********************************************/
END; --End Procedure 

GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/*************************************************************************/
/* Stored Procedure: [isp_SCE_DLColumnMap_Inq]                           */
/* Creation Date: 28 Oct 2020                                            */
/* Copyright: LFL                                                        */
/* Written by: GHChan                                                    */
/*                                                                       */
/* Purpose: Retrieve List of ColumnMap from GTApps                       */
/*                                                                       */
/* Called By:  SCE Data Loader                                           */
/*                                                                       */
/* PVCS Version: -                                                       */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author   Ver  Purposes                                   */
/* 28-Oct-2020  GHChan   1.0  Initial Development                        */
/*************************************************************************/
CREATE PROC [dbo].[isp_SCE_DLColumnMap_Inq] (
   @b_Debug          INT           = 0
 , @c_Format         VARCHAR(10)   = ''
 , @c_UserID         NVARCHAR(256) = ''
 , @c_OperationType  NVARCHAR(60)  = ''
 , @c_RequestString  NVARCHAR(MAX) = ''
 , @b_Success        INT           = 0 OUTPUT
 , @n_ErrNo          INT           = 0 OUTPUT
 , @c_ErrMsg         NVARCHAR(250) = '' OUTPUT
 , @c_ResponseString NVARCHAR(MAX) = '' OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON;
   SET ANSI_DEFAULTS OFF;
   SET QUOTED_IDENTIFIER OFF;
   SET CONCAT_NULL_YIELDS_NULL OFF;
   SET ANSI_NULLS ON;
   SET ANSI_WARNINGS ON;
   /*********************************************/
   /* Variables Declaration (Start)             */
   /*********************************************/

   DECLARE @n_Continue    INT            = 1
         , @n_StartCnt    INT            = @@TRANCOUNT
         , @c_TgtDatabase NVARCHAR(100)  = N''
         , @c_TgtTables   NVARCHAR(1200) = N''
         , @c_FTBLNAME    NVARCHAR(300)  = N''
         , @n_TmpID       INT            = 0
         , @SQL           NVARCHAR(MAX)  = N''
         , @c_ExecArgs    NVARCHAR(MAX)  = N'';

   SET @b_Success = 1;

   DECLARE @t_ColumnMapHdr TABLE (
      ID        INT           IDENTITY(1, 1) NOT NULL
    , TableName NVARCHAR(500) NOT NULL
   );

   DECLARE @t_ColumnMapDet TABLE (
      ID         INT           NOT NULL
    , DBCol      NVARCHAR(500) NOT NULL
    , DataType   NVARCHAR(200) NOT NULL
    , isNullable BIT           NULL DEFAULT 0
   );
   /*********************************************/
   /* Variables Declaration (End)               */
   /*********************************************/

   --Extract RequestBody Data into Temp Table
   IF ISNULL(RTRIM(@c_RequestString), '') = ''
   BEGIN
      SET @n_Continue = 3;
      SET @b_Success = 0;
      SET @n_ErrNo = N'50000';
      SET @c_ErrMsg = N'RequestBody Cannot be NULL or EMPTY.(isp_SCE_DLColumnMap_Inq)';
      GOTO QUIT;
   END;

   BEGIN TRY
      SELECT @c_TgtDatabase = TgtDatabase
           , @c_TgtTables   = TgtTables
      FROM
         OPENJSON(@c_RequestString)
         WITH (
         TgtDatabase NVARCHAR(100) '$.TgtDatabase'
       , TgtTables NVARCHAR(1200) '$.TgtTables'
         );
   END TRY
   BEGIN CATCH
      SET @n_Continue = 3;
      SET @b_Success = 0;
      SET @n_ErrNo = N'50001';
      SET @c_ErrMsg = N'Failed to Extract RequestBody Data.(isp_SCE_DLColumnMap_Inq)';
      GOTO QUIT;
   END CATCH;

   BEGIN TRY
      DECLARE C_TBLARR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT value
      FROM STRING_SPLIT(@c_TgtTables, ',');

      OPEN C_TBLARR;
      FETCH NEXT FROM C_TBLARR
      INTO @c_FTBLNAME;

      WHILE (@@FETCH_STATUS <> -1)
      BEGIN
         IF ISNULL(RTRIM(@c_FTBLNAME), '') <> ''
         BEGIN
            SET @n_TmpID = 0;
            SET @SQL = N'';
            SET @c_FTBLNAME = N'[' + @c_TgtDatabase + N'].' + @c_FTBLNAME;
            INSERT INTO @t_ColumnMapHdr (TableName)
            VALUES
            (@c_FTBLNAME);
            SET @n_TmpID = SCOPE_IDENTITY();

            SET @SQL = N' SELECT @n_TmpID,c.[name],c.is_nullable, UPPER(t.[name]) + CASE '
                     + N' WHEN t.[name] IN (''varchar'',''char'',''varbinary'',''binary'',''text'') THEN ''(''+CASE WHEN c.max_length = -1 THEN ''MAX'' ELSE CAST(c.max_length AS NVARCHAR(5)) END+'')'' '
                     + N' WHEN t.[name] IN (''nvarchar'',''nchar'',''ntext'') THEN ''(''+CASE WHEN c.max_length = -1 THEN ''MAX'' ELSE CAST(c.max_length/2 AS NVARCHAR(5)) END+'')'' '
                     + N' WHEN t.[name] IN (''decimal'',''numeric'') THEN ''(''+CAST(c.precision AS NVARCHAR(5))+'','' + CAST(c.scale AS NVARCHAR(5)) + '')'' '
                     + N' ELSE '''' END '   
                     + N' FROM ' + QUOTENAME(@c_TgtDatabase) + '.sys.columns c WITH (NOLOCK)'   
                     + N' INNER JOIN ' + QUOTENAME(@c_TgtDatabase) + '.sys.types t WITH (NOLOCK)'    
                     + N' ON c.user_type_id = t.user_type_id '    
                     + N' WHERE c.object_id = OBJECT_ID(@c_FTBLNAME) '    
                     + N' AND c.is_identity <> 1 '

            SET @c_ExecArgs = N' @n_TmpID INT 
                                ,@c_FTBLNAME NVARCHAR(300)';

            IF @b_Debug = 1 PRINT @SQL;

            INSERT INTO @t_ColumnMapDet (ID, DBCol, isNullable, DataType)
            EXEC sp_executesql @SQL
                             , @c_ExecArgs
                             , @n_TmpID
                             , @c_FTBLNAME;
         END;
         FETCH NEXT FROM C_TBLARR
         INTO @c_FTBLNAME;
      END;
      CLOSE C_TBLARR;
      DEALLOCATE C_TBLARR;

      IF NOT EXISTS (SELECT 1 FROM @t_ColumnMapDet)
      BEGIN
         SET @n_Continue = 3;
         SET @b_Success = 0;
         SET @n_ErrNo = N'50002';
         SET @c_ErrMsg = N'These tables not found in DB(' + @c_TgtTables + ').(isp_SCE_DLColumnMap_Inq)';
         GOTO QUIT;
      END;
   END TRY
   BEGIN CATCH
      SET @n_Continue = 3;
      SET @b_Success = 0;
      SET @n_ErrNo = N'50003';
      SET @c_ErrMsg = N'Failed to Get Column Information.(isp_SCE_DLColumnMap_Inq)' + ERROR_MESSAGE();
      GOTO QUIT;
   END CATCH;

   QUIT:
   IF @n_Continue = 3
   BEGIN
      SET @c_ResponseString = (
      SELECT @n_ErrNo  AS [ErrNo]
           , @c_ErrMsg AS [ErrMsg]
      FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
      );
   END;
   ELSE
   BEGIN
      SET @c_ResponseString = (
      SELECT Hdr.TableName
           , [Data].DBCol
           , [Data].DataType
           , CASE WHEN [Data].isNullable = 1 THEN 'N'
                  ELSE 'Y'
             END AS [Mandatory]
      FROM @t_ColumnMapHdr       Hdr
      INNER JOIN @t_ColumnMapDet [Data]
      ON Hdr.ID = [Data].ID
      FOR JSON AUTO
      );
   END;

   IF ISNULL(@c_ResponseString, '') = ''
   BEGIN
      SET @n_Continue = 3;
      SET @n_ErrNo = 50004;
      SET @c_ErrMsg = '@c_ResponseString is NULL or EMPTY! (isp_SCE_DLColumnMap_Inq)';
   END;

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

      IF @b_Debug = 1
      BEGIN
         PRINT (@c_ResponseString);
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

      IF @b_Debug = 1
      BEGIN
         PRINT (@c_ResponseString);
      END;
      RETURN;
   END;
/***********************************************/
/* Std - Error Handling (End)                  */
/***********************************************/
END; --End Procedure 

GO
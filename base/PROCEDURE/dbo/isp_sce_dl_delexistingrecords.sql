SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/*************************************************************************/
/* Stored Procedure: isp_SCE_DL_DelExistingRecords                       */
/* Creation Date: 02 Dec 2020                                            */
/* Copyright: LFL                                                        */
/* Written by: GHChan                                                    */
/*                                                                       */
/* Purpose: Delete With Check Unique Key, Then Insert New into TGT Table.*/
/*                                                                       */
/* Called By:  SCE Data Loader                                           */
/*                                                                       */
/* PVCS Version: -                                                       */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author   Ver  Purposes                                   */
/* 02-Dec-2020  GHChan   1.0  Initial Development                        */
/*************************************************************************/
CREATE PROC [dbo].[isp_SCE_DL_DelExistingRecords] (
   @b_Debug      INT            = 0
 , @n_BatchNo    INT            = 0
 , @c_STGTBL     NVARCHAR(250)  = ''
 , @c_POSTTBL    NVARCHAR(250)  = ''
 , @c_UniqKeyCol NVARCHAR(1000) = ''
 , @b_Success    INT            = 0 OUTPUT
 , @n_ErrNo      INT            = 0 OUTPUT
 , @c_ErrMsg     NVARCHAR(250)  = '' OUTPUT
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

   DECLARE @n_Continue  INT            = 1
         , @n_StartCnt  INT            = @@TRANCOUNT
         , @SQL         NVARCHAR(MAX)  = N''
         , @SQL1        NVARCHAR(MAX)  = N''
         , @SQL2        NVARCHAR(MAX)  = N''
         --, @c_FParams            NVARCHAR(1000) = ''
         , @c_WHRParams NVARCHAR(2000) = N''
         , @c_SETValues NVARCHAR(2000) = N''
         , @c_DCLParams NVARCHAR(2000) = N''
         , @c_InnerJoins NVARCHAR(2000) =N''
         , @c_UKVal     NVARCHAR(200)  = N''
         , @c_ExecArgs1  NVARCHAR(2000) = N'';

   SET @b_Success = 1;
   SET @c_WHRParams = N'';
   SET @c_InnerJoins = N'';
   /*********************************************/
   /* Variables Declaration (End)               */
   /*********************************************/

   BEGIN TRY
      --USING UNIQUE KEYS TO CHECK DUPLICATE RECORDS IN STAGING OR TARGET TABLE
         --SET @c_FParams = ''

      DECLARE CUR_UNIKEYS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT LTRIM(RTRIM(value))
      FROM STRING_SPLIT(@c_UniqKeyCol, ',');
      OPEN CUR_UNIKEYS;

      FETCH FROM CUR_UNIKEYS
      INTO @c_UKVal;

      WHILE @@FETCH_STATUS = 0
      BEGIN

         SET @c_InnerJoins += N' STG.' + @c_UKVal + N' = TGT.' + @c_UKVal;

         FETCH FROM CUR_UNIKEYS
         INTO @c_UKVal;

         IF @@FETCH_STATUS = 0
         BEGIN
            SET @c_InnerJoins += N' AND ';
         END;
      END;
      CLOSE CUR_UNIKEYS;
      DEALLOCATE CUR_UNIKEYS;

      --IF CHARINDEX(',', @c_UniqKeyCol) <> 0
      --BEGIN
      --   --SET @c_FParams = ''
      --   SET @c_WHRParams = N'';
      --   SET @c_DCLParams = N'';

      --   DECLARE CUR_UNIKEYS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      --   SELECT LTRIM(RTRIM(value))
      --   FROM STRING_SPLIT(@c_UniqKeyCol, ',');
      --   OPEN CUR_UNIKEYS;
      --   FETCH FROM CUR_UNIKEYS
      --   INTO @c_UKVal;

      --   WHILE @@FETCH_STATUS = 0
      --   BEGIN
      --      SET @n_UKCount += 1;

      --      IF @n_UKCount = 1 -- ISNULL(RTRIM(@c_WHRParams), '') = '' AND ISNULL(RTRIM(@c_FParams), '') = '' 
      --      BEGIN
      --         SET @c_DCLParams = N' @PK' + CAST(@n_UKCount AS NVARCHAR(2)) + N' NVARCHAR(200)=''''';
      --         --SET @c_FParams    = N'@C0, @PK' + CAST(@n_UKCount AS NVARCHAR(2))  
      --         SET @c_WHRParams = N' ' + @c_UKVal + N'=@PK' + CAST(@n_UKCount AS NVARCHAR(2));
      --         SET @c_SETValues = N' @PK' + CAST(@n_UKCount AS NVARCHAR(2)) + N'=' + @c_UKVal;
      --      END;
      --      ELSE
      --      BEGIN
      --         SET @c_DCLParams += N', @PK' + CAST(@n_UKCount AS NVARCHAR(2)) + N' NVARCHAR(200)=''''';
      --         --SET @c_FParams    += N', @PK' + CAST(@n_UKCount AS NVARCHAR(2))  
      --         SET @c_WHRParams += N' AND ' + @c_UKVal + N'=@PK' + CAST(@n_UKCount AS NVARCHAR(2));
      --         SET @c_SETValues += N', @PK' + CAST(@n_UKCount AS NVARCHAR(2)) + N'=' + @c_UKVal;
      --      END;
      --      FETCH FROM CUR_UNIKEYS
      --      INTO @c_UKVal;

      --   END;
      --   CLOSE CUR_UNIKEYS;
      --   DEALLOCATE CUR_UNIKEYS;
      --END;
      --ELSE
      --BEGIN
      --   SET @c_DCLParams = N' @PK1 NVARCHAR(200) = ''''';
      --   --SET @c_FParams = N'@C0, @PK1 '  
      --   SET @c_WHRParams = N' ' + @c_UniqKeyCol + N'=@PK1 ';
      --   SET @c_SETValues = N' @PK1=' + @c_UniqKeyCol;
      --END;

      SET @SQL1 = N''
      SET @c_ExecArgs1 = N'';

      SET @SQL1 = N' DELETE TGT FROM ' + @c_POSTTBL + N' TGT INNER JOIN ' + @c_STGTBL + N' STG ON ' + @c_InnerJoins
                + N' WHERE STG.STG_BatchNo=@n_BatchNo AND STG.STG_Status=''1'' '

      SET @c_ExecArgs1 = N' @n_BatchNo INT';

      IF @b_Debug = 1
      BEGIN
         PRINT @SQL1;
      END;

      EXEC sp_executesql @SQL1
                       , @c_ExecArgs1
                       , @n_BatchNo;

      --SET @SQL1 = N' DECLARE @C0 INT, ' + @c_DCLParams
      --          + N' DECLARE @t TABLE (ID INT) '
      --          + N' INSERT INTO @t (ID) SELECT RowRefNo FROM ' + @c_STGTBL + ' WITH(NOLOCK) ' 
      --          + N' WHERE STG_BatchNo=@n_BatchNo AND STG_Status=''1'' '
      --          + N' WHILE EXISTS(SELECT 1 FROM @t) '
      --          + N' BEGIN '
      --          + N' SELECT TOP (1) @C0=ID FROM @t ' 
      --          + N' SELECT ' + @c_SETValues + ' FROM ' + @c_STGTBL +' WITH(NOLOCK) WHERE RowRefNo=@C0 ' 
      --          + N' IF EXISTS (SELECT 1 FROM ' + @c_POSTTBL + ' WITH (NOLOCK) WHERE ' + @c_WHRParams
      --SET @SQL2 = N' GROUP BY ' + @c_UniqKeyCol + ' HAVING COUNT(1)>1) '
      --          + N' BEGIN '
      --          + N' UPDATE ' + @c_STGTBL + ' WITH (ROWLOCK) '
      --          + N' SET STG_Status =''5'' '
      --          + N' ,STG_ErrMsg=''More than 1 same unique key records in target table. Unable to update this record into target table.'' '
      --          + N' WHERE RowRefNo = @C0'
      --          + N' END '
      --          + N' ELSE '
      --          + N' BEGIN '
      --          + N' DELETE FROM ' + @c_POSTTBL + ' WHERE ' + @c_WHRParams
      --          + N' END '
      --          + N' DELETE FROM @t WHERE ID=@C0 '
      --          + N' END '

      --SET @c_ExecArgs = N' @n_BatchNo INT';

      --SET @SQL = CONCAT(@SQL1, @SQL2);

      --IF @b_Debug = 1
      --BEGIN
      --   PRINT @SQL1;
      --   PRINT @SQL2;
      --   --PRINT @SQL3
      --   --PRINT @SQL4
      --   PRINT @SQL;
      --END;

      --EXEC sp_executesql @SQL
      --                 , @c_ExecArgs
      --                 , @n_BatchNo;

      --SET @SQL1 = N' DECLARE @C0 INT, @nCnt INT, @nTtlCnt INT, ' + @c_DCLParams
      --          + N' SET @nCnt=0 '
      --          + N' SELECT @nTtlCnt=COUNT(1) FROM ' + @c_STGTBL + ' WITH(NOLOCK) '
      --          + N' WHERE STG_BatchNo=@n_BatchNo '
      --          + N' WHILE @nCnt < @nTtlCnt '
      --          + N' BEGIN '
      --          + N' SELECT @C0=RowRefNo, ' + @c_SETValues + ' FROM ' + @c_STGTBL +' WITH(NOLOCK) ' 
      --          + N' WHERE STG_BatchNo=@n_BatchNo '
      --          + N' ORDER BY RowRefNo ASC ' 
      --          + N' OFFSET @nCnt ROWS '
      --          + N' FETCH NEXT 1 ROWS ONLY '
      --          + N' IF EXISTS(SELECT 1 FROM ' + @c_STGTBL + ' WITH(NOLOCK) WHERE RowRefNo=@C0 AND STG_Status=''1'') '
      --          + N' BEGIN '
      --SET @SQL2 = N' IF EXISTS(SELECT 1 FROM ' + @c_POSTTBL + ' WITH(NOLOCK) WHERE ' + @c_WHRParams + ' HAVING COUNT(1)>1) '
      --          + N' BEGIN '
      --          + N' UPDATE ' + @c_STGTBL + ' WITH (ROWLOCK) '
      --          + N' SET STG_Status =''5'' '
      --          + N' ,STG_ErrMsg=''More than 1 same unique key records in target table. Unable to update this record into target table.'' '
      --          + N' WHERE RowRefNo = @C0'
      --          + N' END '
      --          + N' ELSE '
      --          + N' BEGIN '
      --          + N' DELETE FROM ' + @c_POSTTBL + ' WHERE ' + @c_WHRParams
      --          + N' END '
      --          + N' END '
      --          + N' SET @nCnt += 1'
      --          + N' END '  


   END TRY
   BEGIN CATCH
      SET @n_Continue = 3;
      SET @b_Success = 0;
      SET @n_ErrNo = N'13000';
      SET @c_ErrMsg = N'Failed to Delete Existing Records in Target Table!' + ERROR_MESSAGE() + '(isp_SCE_DL_DelExistingRecords)';
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
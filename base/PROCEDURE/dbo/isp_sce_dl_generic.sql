SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Stored Procedure: isp_SCE_DL_Generic                                 */
/* Creation Date: 23 Oct 2020                                           */
/* Copyright: LFL                                                       */
/* Written by: GHChan                                                   */
/*                                                                      */
/* Purpose: Populate Excel Data                                         */
/*                                                                      */
/* Called By:  SCE Data Loader                                          */
/*                                                                      */
/* PVCS Version: -                                                      */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 23-Oct-2020  GHChan   1.0  Initial Development                       */
/************************************************************************/
CREATE PROC [dbo].[isp_SCE_DL_Generic] (
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
   SET CONCAT_NULL_YIELDS_NULL ON;
   SET ANSI_WARNINGS ON;
   SET ANSI_PADDING ON;

   /*********************************************/
   /* Variables Declaration (Start)             */
   /*********************************************/

   DECLARE @n_Continue              INT            = 1
         , @n_StartCnt              INT            = @@TRANCOUNT
         , @c_STGTBL                NVARCHAR(250)  = N''
         , @c_POSTTBL               NVARCHAR(250)  = N''
         , @n_Flag                  INT            = 0
         , @SQL                     NVARCHAR(MAX)  = N''
         , @SQL1                    NVARCHAR(MAX)  = N''
         , @n_BatchNo               INT            = 0
         , @c_ListNo                NVARCHAR(MAX)  = N''
         , @c_ActType               INT            = 0
         , @n_PageNum               INT            = 0
         , @n_Offset                INT            = 0
         , @n_Limit                 INT            = 0
         , @b_LastRequest           BIT            = 0
         , @c_STG_Data              NVARCHAR(MAX)  = N''
         , @c_UniqKeyCol            NVARCHAR(1000) = N''
         , @n_Count                 INT            = 0
         , @c_AliasName             NVARCHAR(20)   = N''
         , @c_PreAlias              NVARCHAR(20)   = N''
         , @c_WHRParams             NVARCHAR(2000) = N''
         , @c_ExecArgs              NVARCHAR(1000) = N''
         , @c_ExecArgs1             NVARCHAR(1000) = N''
         , @c_listTable             NVARCHAR(1000) = N''
         , @c_SortColumn            NVARCHAR(500)  = N''
         , @n_SortOrder             INT            = 0
         , @c_Username              NVARCHAR(128)  = N''
         , @c_SearchCriteria        NVARCHAR(MAX)  = N'[]'
         , @c_Column                NVARCHAR(500)  = N''
         , @c_Value                 NVARCHAR(500)  = N''
         , @n_TempRowCount          INT            = 0
         , @c_FSortColumn           NVARCHAR(500)  = N''
         , @ttlTableCount           INT            = ''
         , @ttlRowCount             INT            = ''
         , @c_Message               NVARCHAR(200)  = N''
         , @c_HdrStatus             NVARCHAR(50)   = N''
         , @n_Total                 INT            = 0
         , @c_innerJSON             NVARCHAR(MAX)  = N''
         , @c_outerJSON             NVARCHAR(MAX)  = N''
         , @c_subInnerJson          NVARCHAR(MAX)  = N''
         , @c_SubRuleJson           NVARCHAR(MAX)  = N''

         --Client Principal Columns Variables
         , @n_SubRuleID             INT            = 0
         , @n_SubRuleWebApiConfigID INT            = 0
         , @n_SubRuleConfigID       INT            = 0
         , @n_SubRuleClientCode     NVARCHAR(300)  = N''
         , @c_SubRuleCode           NVARCHAR(100)  = N''
         , @n_SubRuleFlag           INT            = 0
         , @n_SubRuleStep           INT            = 0
         , @n_SubRuleSEQ            INT            = 0
         , @c_SubRuleSP             NVARCHAR(300)  = N'';

   SET @b_Success = 1;
   SET @n_ErrNo = 0;
   SET @c_ErrMsg = '';
   SET @c_HdrStatus = N'success';
   SET @c_Message = N'Inquire Successful';

   DECLARE @t_SubRule TABLE (
      SubRuleID      INT           NULL DEFAULT 0
    , WebApiConfigID INT           NULL DEFAULT 0
    , ConfigID       INT           NULL DEFAULT 0
    , ClientCode     NVARCHAR(300) NULL DEFAULT ''
    , Code           NVARCHAR(100) NULL DEFAULT ''
    , Flag           INT           NULL DEFAULT 0
    , Step           INT           NULL DEFAULT 0
    , SEQ            INT           NULL DEFAULT 0
    , IsActive       CHAR(1)       NULL DEFAULT ''
    , SubRuleSP      NVARCHAR(300) NULL DEFAULT ''
   );

   DECLARE @t_LTableData TABLE (
      ID             INT            IDENTITY(1, 1) NOT NULL
    , STG_TBL        NVARCHAR(400)  NOT NULL
    , POST_TBL       NVARCHAR(400)  NOT NULL
    , ListNo         NVARCHAR(MAX)  NULL DEFAULT ''
    , UniqueKeyCol   NVARCHAR(1000) NULL DEFAULT ''
    , StagingData    NVARCHAR(MAX)  NULL DEFAULT ''
    , SearchCriteria NVARCHAR(MAX)  NULL DEFAULT '[]'
   );

   /*********************************************/
   /* Variables Declaration (End)               */
   /*********************************************/

   BEGIN --#region GENERIC NO ANY CHANGES NEED TO MAKE AT HERE--     
      --Extract RequestBody Data into Temp Table
      IF ISNULL(RTRIM(@c_RequestString), '') = ''
      BEGIN
         SET @n_Continue = 3;
         SET @b_Success = 0;
         SET @n_ErrNo = N'10001';
         SET @c_ErrMsg = N'RequestBody Cannot be NULL or EMPTY.(isp_SCE_DL_Generic)';
         GOTO QUIT;
      END;

      BEGIN TRY
         SELECT @n_Flag        = ISNULL(Flag, 0)
              , @n_BatchNo     = ISNULL(STG_BatchNo, 0)
              , @c_ActType     = CAST(ISNULL(RTRIM(ActionType), '0') AS INT)
              , @n_PageNum     = ISNULL(PageNum, 0)
              , @n_Offset      = ISNULL(Offset, -1)
              , @n_Limit       = ISNULL(Limit, 0)
              , @b_LastRequest = LastRequest
              , @c_SortColumn  = ISNULL(RTRIM(SortColumn), '')
              , @n_SortOrder   = ISNULL(SortOrder, 0)
              , @c_Username    = ISNULL(RTRIM(Username), '')
         FROM
            OPENJSON(@c_RequestString)
            WITH (
            Flag INT '$.Flag'
          , STG_BatchNo INT '$.STG_BatchNo'
          , ActionType CHAR(1) '$.ActionType'
          , PageNum INT '$.PageNum'
          , Offset INT '$.Offset'
          , Limit INT '$.Limit'
          , LastRequest BIT '$.LastRequest'
          , SortColumn NVARCHAR(500) '$.SortColumn'
          , SortOrder INT '$.SortOrder'
          , Username NVARCHAR(128) '$.Username'
            );

         IF @n_BatchNo <= 0
         BEGIN
            SET @n_Continue = 3;
            SET @b_Success = 0;
            SET @n_ErrNo = N'10002';
            SET @c_ErrMsg = N'Invalid BatchNo value.(isp_SCE_DL_Generic)';
            GOTO QUIT;
         END;

         IF @n_Offset < 0
         BEGIN
            SET @n_Continue = 3;
            SET @b_Success = 0;
            SET @n_ErrNo = N'10003';
            SET @c_ErrMsg = N'Invalid Offset value.(isp_SCE_DL_Generic)';
            GOTO QUIT;
         END;

         IF  @n_Flag IN (1, 2)
         AND (@n_Limit <= 0 OR @n_Limit > 1000)
         BEGIN
            SET @n_Continue = 3;
            SET @b_Success = 0;
            SET @n_ErrNo = N'10004';
            SET @c_ErrMsg = N'Invalid Limit value!(isp_SCE_DL_Generic)';
            GOTO QUIT;
         END;

         IF @n_Flag <= 0
         OR @n_Flag > 4
         BEGIN
            SET @n_Continue = 3;
            SET @b_Success = 0;
            SET @n_ErrNo = N'10005';
            SET @c_ErrMsg = N'Invalid Flag Indicator.(isp_SCE_DL_Generic)';
            GOTO QUIT;
         END;

         SELECT @ttlTableCount = COUNT(1)
         FROM OPENJSON(@c_RequestString, '$.Data');

         IF @ttlTableCount < 1
         BEGIN
            SET @n_Continue = 3;
            SET @b_Success = 0;
            SET @n_ErrNo = N'10006';
            SET @c_ErrMsg = N'Invalid Data Property. Data Property cannot be empty.(isp_SCE_DL_Generic)';
            GOTO QUIT;
         END;

         IF @n_Flag = 2
         BEGIN
            SELECT @ttlRowCount = COUNT(1)
            FROM OPENJSON(@c_RequestString, '$.Data[0].StagingData');

            IF @ttlTableCount * @ttlRowCount > 1000
            BEGIN
               SET @n_Continue = 3;
               SET @b_Success = 0;
               SET @n_ErrNo = N'10007';
               SET @c_ErrMsg = N'JSON request NOT allow more than one thousand of records.(isp_SCE_DL_Generic)';
               GOTO QUIT;
            END;
         END;

         IF  @n_Flag = 4
         AND (@c_ActType <= 0 OR @c_ActType > 3)
         BEGIN
            SET @n_Continue = 3;
            SET @b_Success = 0;
            SET @n_ErrNo = N'10008';
            SET @c_ErrMsg = N'Failed to Perform POSTING Action. Invalid Action Type!(isp_SCE_DL_Generic)';
            GOTO QUIT;
         END;

         IF @c_Username = ''
         BEGIN
            SET @n_Continue = 3;
            SET @b_Success = 0;
            SET @n_ErrNo = N'10009';
            SET @c_ErrMsg = N'Username cannot be null.(isp_SCE_DL_Generic)';
            GOTO QUIT;
         END;

         SELECT @c_SubRuleJson = JSON_QUERY(@c_RequestString, '$.SubRule');
         INSERT INTO @t_SubRule
         (
            SubRuleID
          , WebApiConfigID
          , ConfigID
          , ClientCode
          , Code
          , Flag
          , Step
          , SEQ
          , IsActive
          , SubRuleSP
         )
         SELECT SubRuleID
              , WebApiConfigID
              , ConfigID
              , ClientCode
              , Code
              , Flag
              , Step
              , SEQ
              , IsActive
              , SubRuleSP
         FROM
            OPENJSON(@c_SubRuleJson)
            WITH (
            SubRuleID INT '$.SubRuleID'
          , WebApiConfigID INT '$.WebApiConfigID'
          , ConfigID INT '$.ConfigID'
          , ClientCode NVARCHAR(300) '$.ClientCode'
          , Code NVARCHAR(100) '$.Code'
          , Flag INT '$.Flag'
          , Step INT '$.Step'
          , SEQ INT '$.SEQ'
          , IsActive CHAR(1) '$.IsActive'
          , SubRuleSP NVARCHAR(300) '$.SubRuleSP'
            )
         WHERE IsActive = '1';

         IF EXISTS (SELECT 1 FROM @t_SubRule)
         BEGIN
            DECLARE C_SR1 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT ISNULL(RTRIM(SubRuleSP), '')
            FROM @t_SubRule
            WHERE Flag IN (1, 2, 3)
            --AND IsActive = '1'
            ORDER BY SEQ ASC
                   , Code ASC
                   , Step ASC;

            OPEN C_SR1;
            FETCH FROM C_SR1
            INTO @c_SubRuleSP;

            WHILE @@FETCH_STATUS <> -1
            BEGIN
               IF NOT EXISTS (
               SELECT 1
               FROM sys.objects WITH (NOLOCK)
               WHERE object_id = OBJECT_ID(@c_SubRuleSP)
               AND   type IN (N'P', N'PC')
               )
               BEGIN
                  SET @n_Continue = 3;
                  SET @b_Success = 0;
                  SET @n_ErrNo = N'10010';
                  SET @c_ErrMsg = N'Invalid SubRuleSP. SubRuleSP not found!(isp_SCE_DL_Generic)';
                  GOTO QUIT;
               END;

               FETCH FROM C_SR1
               INTO @c_SubRuleSP;
            END;
            CLOSE C_SR1;
            DEALLOCATE C_SR1;
         END;

         INSERT INTO @t_LTableData
         (
            STG_TBL
          , POST_TBL
          , ListNo
          , UniqueKeyCol
          , StagingData
          , SearchCriteria
         )
         SELECT SUBSTRING(TableName, 0, LEN(TableName)) + '_STG]' -- To replace target Table to become staging Table
              , TableName
              , ListNo
              , UniqueKeyCol
              , StagingData
              , SearchCriteria
         FROM
            OPENJSON(@c_RequestString, '$.Data')
            WITH (
            TableName NVARCHAR(400) '$.TableName'
          , ListNo NVARCHAR(MAX) '$.ListNo'
          , UniqueKeyCol NVARCHAR(1000) '$.UniqueKeyCol'
          , StagingData NVARCHAR(MAX) '$.StagingData' AS JSON
          , SearchCriteria NVARCHAR(MAX) '$.SearchCriteria' AS JSON
            );
      END TRY
      BEGIN CATCH
         SET @n_Continue = 3;
         SET @b_Success = 0;
         SET @n_ErrNo = N'10011';
         SET @c_ErrMsg = N'Failed to Extract RequestBody Data.' + ERROR_MESSAGE() + '(isp_SCE_DL_Generic)';
         GOTO QUIT;
      END CATCH;
   END;
   --#endregion GENERIC NO ANY CHANGES NEED TO MAKE AT HERE--

   --CHECK HOW MANY TABLES ARE NEED TO USE
   DECLARE C_TBL1 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT ISNULL(RTRIM(STG_TBL), '')
        , ISNULL(RTRIM(POST_TBL), '')
        , ISNULL(RTRIM(ListNo), '')
        , UniqueKeyCol
        , ISNULL(RTRIM(StagingData), '[]')
        , SearchCriteria
   FROM @t_LTableData
   ORDER BY ID ASC;
   OPEN C_TBL1;
   FETCH FROM C_TBL1
   INTO @c_STGTBL
      , @c_POSTTBL
      , @c_ListNo
      , @c_UniqKeyCol
      , @c_STG_Data
      , @c_SearchCriteria;

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @n_Count += 1;
      SET @c_AliasName = N'T' + CAST(@n_Count AS NVARCHAR(2));

      /*(Generic) CHECK STAGING TABLE EXISTS OR TAGET TABLE HAVE BEEN MODIFIED, THEN NEED ALTER STAGING TABLE  */
      /*CREATE STAGING TABLE                                                                                   */
      /*ALTER STAGING TABLE                                                                                    */
      /*ADD STAGING TABLE INTO PURGECONFIG TABLE                                                               */

      IF @c_POSTTBL = ''
      OR OBJECT_ID(@c_POSTTBL, 'U') IS NULL
      BEGIN
         SET @n_Continue = 3;
         SET @b_Success = 0;
         SET @n_ErrNo = N'10012';
         SET @c_ErrMsg = N'Invalid Target Table.(isp_SCE_DL_Generic)';
         GOTO QUIT;
      END;

      EXEC [dbo].[isp_SCE_DL_BUILD_STGTBL] @b_Debug = @b_Debug
                                         , @c_POSTTBLName = @c_POSTTBL
                                         , @b_Success = @b_Success OUTPUT
                                         , @n_ErrNo = @n_ErrNo OUTPUT
                                         , @c_ErrMsg = @c_ErrMsg OUTPUT;

      IF @n_ErrNo <> 0
      OR ISNULL(RTRIM(@c_ErrMsg), '') <> ''
      BEGIN
         SET @n_Continue = 3;
         GOTO QUIT;
      END;

      IF @c_STGTBL = ''
      OR OBJECT_ID(@c_STGTBL, 'U') IS NULL
      BEGIN
         SET @n_Continue = 3;
         SET @b_Success = 0;
         SET @n_ErrNo = N'10013';
         SET @c_ErrMsg = N'Invalid Staging Table.(isp_SCE_DL_Generic)';
         GOTO QUIT;
      END;

      IF NOT EXISTS (
      SELECT 1
      FROM sys.columns WITH (NOLOCK)
      WHERE name    = @c_SortColumn
      AND   object_id = OBJECT_ID(@c_STGTBL, 'U')
      )
      BEGIN
         SET @c_FSortColumn = @c_AliasName + N'.STG_SeqNo';
      END;
      ELSE
      BEGIN
         SET @c_FSortColumn = @c_AliasName + N'.' + @c_SortColumn;
      END;

      IF ISNULL(RTRIM(@c_listTable), '') <> ''
      BEGIN
         SET @c_listTable += N' INNER JOIN ' + @c_STGTBL + N' ' + @c_AliasName + N' WITH (NOLOCK) ' + N' ON ' + @c_PreAlias
                             + N'.STG_BatchNo=' + @c_AliasName + N'.STG_BatchNo ' + N' AND ' + @c_PreAlias + N'.STG_SeqNo='
                             + @c_AliasName + N'.STG_SeqNo ';
      END;
      ELSE
      BEGIN
         SET @c_listTable = @c_STGTBL + N' ' + @c_AliasName + N' WITH (NOLOCK) ';
      END;

      SET @c_PreAlias = @c_AliasName;

      -- (Generic) Return SELECT Statement for Pagination or Search  -- IF MORE THAN TWO TABLE HAVE TO ADD Table AliasName.
      IF @n_Flag = 1
      BEGIN
         IF EXISTS (
         SELECT 1
         FROM
            OPENJSON(@c_SearchCriteria)
            WITH (
            [Column] NVARCHAR(500) '$.Column'
          , [Value] NVARCHAR(500) '$.Value'
            )
         )
         BEGIN
            DECLARE C_SEARCH CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT ISNULL(RTRIM([Column]), '')
                 , ISNULL(RTRIM([Value]), '')
            FROM
               OPENJSON(@c_SearchCriteria)
               WITH (
               [Column] NVARCHAR(500) '$.Column'
             , [Value] NVARCHAR(500) '$.Value'
               );
            OPEN C_SEARCH;
            FETCH FROM C_SEARCH
            INTO @c_Column
               , @c_Value;

            WHILE @@FETCH_STATUS <> -1
            BEGIN

               IF  @c_Column <> ''
               AND @c_Value <> ''
               AND dbo.fnc_Check_String(@c_Value) = 1
               AND EXISTS (
               SELECT 1
               FROM sys.columns WITH (NOLOCK)
               WHERE object_id = OBJECT_ID(@c_POSTTBL)
               AND   [name]      = @c_Column
               )
               BEGIN
                  SET @c_WHRParams += N' AND ' + @c_AliasName + N'.' + QUOTENAME(@c_Column) + N' LIKE ''' + @c_Value + N'%''';
               END;

               FETCH FROM C_SEARCH
               INTO @c_Column
                  , @c_Value;
            END;
            CLOSE C_SEARCH;
            DEALLOCATE C_SEARCH;
         END;

         --***********(Generic) To get total count for SCE showing purpose************
         SET @SQL = N' SELECT @n_Total=COUNT(1) FROM ' + @c_STGTBL + N' WITH (NOLOCK) ' + N' WHERE 1 = 1 ' + @c_WHRParams
                    + N' AND STG_BatchNo = @n_BatchNo ';

         SET @c_ExecArgs = N' @n_Total INT OUTPUT ' + N',@n_BatchNo INT ';

         IF @b_Debug = 1 PRINT @SQL;

         EXEC sp_executesql @SQL
                          , @c_ExecArgs
                          , @n_Total OUTPUT
                          , @n_BatchNo;

         --IF @n_Total <= 0
         --BEGIN
         --   SET @n_Continue = 3;
         --   SET @b_Success = 0;
         --   SET @n_ErrNo = N'10020';
         --   SET @c_ErrMsg = N'No result has been found!(isp_SCE_DL_Generic)';
         --END;
         --***********(Generic) To get total count for SCE showing purpose************
      END;

      -- (Generic) When user click upload button -- THIS PART IS GENERIC CODE. --
      ELSE IF @n_Flag IN (2, 3)
      BEGIN

         IF ISJSON(@c_STG_Data) <> 1
         OR @c_STG_Data = '[]'
         BEGIN
            SET @n_Continue = 3;
            SET @b_Success = 0;
            SET @n_ErrNo = N'10014';
            SET @c_ErrMsg = N'No Staging data found.(isp_SCE_DL_Generic)';
            GOTO QUIT;
         END;

         --(Generic) Extract JSON Data and Store into Staging Table  
         BEGIN TRY

            -- (Generic) When user click validate button, then delete those error records and re-insert the data into table  
            --IF @c_ListNo <> ''  
            IF @n_Offset = 0
            BEGIN

               SET @SQL = N'';
               SET @c_ExecArgs = N'';

               SET @SQL = N' DELETE FROM ' + @c_STGTBL + N' WHERE STG_BatchNo = @n_BatchNo';
               --+ N' AND STG_SeqNo IN (SELECT TRIM(VALUE) FROM STRING_SPLIT(@c_ListNo, '',''))';  
               --+ N' AND STG_SeqNo IN (' + @c_ListNo + ')';  

               SET @c_ExecArgs = N'  @n_BatchNo INT';

               IF @b_Debug = 1 PRINT @SQL;

               BEGIN TRAN;

               EXEC sp_executesql @SQL
                                , @c_ExecArgs
                                , @n_BatchNo;

               COMMIT TRAN;
            END;

            SET @SQL = N'';
            EXEC [dbo].[isp_SCE_DL_GenericImportStagingData] @json = @c_STG_Data
                                                           , @c_TableName = @c_STGTBL
                                                           , @SQL = @SQL OUTPUT;

            IF @b_Debug = 1 PRINT @SQL;

            BEGIN TRAN;

            EXEC sp_executesql @SQL
                             , N' @json NVARCHAR(MAX)'
                             , @c_STG_Data;

            SELECT @n_TempRowCount = @@ROWCOUNT;

            COMMIT TRAN;

            IF @n_TempRowCount <= 0
            BEGIN
               SET @n_Continue = 3;
               SET @b_Success = 0;
               SET @n_ErrNo = N'10015';
               SET @c_ErrMsg = N'Failed to Import Data Into Staging Table.(isp_SCE_DL_Generic)';
               GOTO QUIT;
            END;
         END TRY
         BEGIN CATCH
            IF @@TRANCOUNT > 0
            BEGIN
               ROLLBACK TRAN;
            END;
            SET @n_Continue = 3;
            SET @b_Success = 0;
            SET @n_ErrNo = N'10016';
            SET @c_ErrMsg = N'Failed to Import Data Into Staging Table.' + ERROR_MESSAGE() + '(isp_SCE_DL_Generic)';
            GOTO QUIT;
         END CATCH;

         BEGIN TRY
            SET @SQL = N'';
            SET @c_ExecArgs = N'';

            SET @SQL = N' UPDATE ' + @c_STGTBL + N' WITH(ROWLOCK) ' + N' SET STG_Status = ''1'''
                       + N' WHERE STG_BatchNo = @n_BatchNo ';
            --+ N' AND STG_SeqNo IN (' + @c_ListNo + ')';        

            SET @c_ExecArgs = N' @n_BatchNo INT ';

            --SET @SQL = N' UPDATE ' + @c_STGTBL + ' WITH(ROWLOCK) '  
            --         + N' SET STG_Status = ''1'''  
            --         + N' WHERE RowRefNo IN ( '  
            --         + N' SELECT RowRefNo FROM ' + @c_STGTBL + ' WITH(NOLOCK) '  
            --         + N' WHERE STG_BatchNo = @n_BatchNo '  
            --         --+ N' AND STG_Status = ''0'' '  
            --         + N' ORDER BY RowRefNo ASC '  
            --         + N' OFFSET @n_Offset ROWS '  
            --         + N' FETCH NEXT @n_Limit ROWS ONLY) '  

            --SET @c_ExecArgs = N' @n_BatchNo INT '  
            --                + N',@n_Offset INT '  
            --                + N',@n_Limit INT '  

            IF @b_Debug = 1 PRINT @SQL;

            BEGIN TRAN;

            EXEC sp_executesql @SQL
                             , @c_ExecArgs
                             , @n_BatchNo;

            --EXEC sp_executesql @SQL, @c_ExecArgs, @n_BatchNo, @n_Offset, @n_Limit  


            COMMIT TRAN;

         END TRY
         BEGIN CATCH
            IF @@TRANCOUNT > 0
            BEGIN
               ROLLBACK TRAN;
            END;
            SET @n_Continue = 3;
            SET @b_Success = 0;
            SET @n_ErrNo = N'10017';
            SET @c_ErrMsg = N'Failed to Update STG_Status to 1.' + ERROR_MESSAGE() + '(isp_SCE_DL_Generic)';
            GOTO QUIT;
         END CATCH;

         --(Generic) USING UNIQUE KEYS TO CHECK DUPLICATE RECORDS IN STAGING OR TARGET TABLE
         IF  @c_ActType = 3
         AND @b_LastRequest = 1
         BEGIN
            EXEC [dbo].[isp_SCE_DL_ChkDuplicate] @b_Debug = @b_Debug
                                               , @n_BatchNo = @n_BatchNo
                                               , @c_STGTBL = @c_STGTBL
                                               , @c_POSTTBL = @c_POSTTBL
                                               , @c_UniqKeyCol = @c_UniqKeyCol
                                               , @b_Success = @b_Success OUTPUT
                                               , @n_ErrNo = @n_ErrNo OUTPUT
                                               , @c_ErrMsg = @c_ErrMsg OUTPUT;

            IF @n_ErrNo <> 0
            OR ISNULL(RTRIM(@c_ErrMsg), '') <> ''
            BEGIN
               SET @n_Continue = 3;
               GOTO QUIT;
            END;
         END;

         --**********************(Generic) START STAGING SUB RULE SP*********************
         IF  EXISTS (SELECT 1 FROM @t_SubRule)
         AND @b_LastRequest = 1
         BEGIN
            SET @SQL1 = N'';
            SET @c_ExecArgs1 = N'';
            DECLARE C_SUBRULES1 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT SubRuleID
                 , WebApiConfigID
                 , ConfigID
                 , ClientCode
                 , Code
                 , Flag
                 , Step
                 , SEQ
                 , SubRuleSP
            FROM @t_SubRule
            WHERE Flag = 1
            --AND IsActive = '1'
            ORDER BY SEQ ASC
                   , Code ASC
                   , Step ASC;

            OPEN C_SUBRULES1;
            FETCH FROM C_SUBRULES1
            INTO @n_SubRuleID
               , @n_SubRuleWebApiConfigID
               , @n_SubRuleConfigID
               , @n_SubRuleClientCode
               , @c_SubRuleCode
               , @n_SubRuleFlag
               , @n_SubRuleStep
               , @n_SubRuleSEQ
               , @c_SubRuleSP;

            WHILE @@FETCH_STATUS <> -1
            BEGIN
               SET @SQL1 = N'EXEC ' + @c_SubRuleSP + N'  @b_Debug       = @b_Debug ' + N', @n_BatchNo     = @n_BatchNo '
                           + N', @n_Flag        = @n_Flag ' + N', @c_SubRuleJson = @c_SubRuleJson '
                           + N', @c_STGTBL      = @c_STGTBL ' + N', @c_POSTTBL     = @c_POSTTBL '
                           + N', @c_UniqKeyCol  = @c_UniqKeyCol ' + N', @c_Username    = @c_Username '
                           + N', @b_Success     = @b_Success OUTPUT' + N', @n_ErrNo       = @n_ErrNo   OUTPUT'
                           + N', @c_ErrMsg      = @c_ErrMsg  OUTPUT';

               SET @c_ExecArgs1 = N'  @b_Debug       INT' + N', @n_BatchNo     INT' + N', @n_Flag        INT'
                                  + N', @c_SubRuleJson NVARCHAR(MAX)' + N', @c_STGTBL      NVARCHAR(250)'
                                  + N', @c_POSTTBL     NVARCHAR(250)' + N', @c_UniqKeyCol  NVARCHAR(1000)'
                                  + N', @c_Username    NVARCHAR(128)' + N', @b_Success     INT            OUTPUT'
                                  + N', @n_ErrNo       INT            OUTPUT' + N', @c_ErrMsg      NVARCHAR(250)  OUTPUT';

               EXEC sp_executesql @SQL1
                                , @c_ExecArgs1
                                , @b_Debug
                                , @n_BatchNo
                                , @n_Flag
                                , @c_SubRuleJson
                                , @c_STGTBL
                                , @c_POSTTBL
                                , @c_UniqKeyCol
                                , @c_Username
                                , @b_Success OUTPUT
                                , @n_ErrNo OUTPUT
                                , @c_ErrMsg OUTPUT;


               IF @n_ErrNo <> 0
               OR ISNULL(RTRIM(@c_ErrMsg), '') <> ''
               BEGIN
                  SET @n_Continue = 3;
                  GOTO QUIT;
               END;

               FETCH FROM C_SUBRULES1
               INTO @n_SubRuleID
                  , @n_SubRuleWebApiConfigID
                  , @n_SubRuleConfigID
                  , @n_SubRuleClientCode
                  , @c_SubRuleCode
                  , @n_SubRuleFlag
                  , @n_SubRuleStep
                  , @n_SubRuleSEQ
                  , @c_SubRuleSP;
            END;

            CLOSE C_SUBRULES1;
            DEALLOCATE C_SUBRULES1;
         END;
         --**********************(Generic) END STAGING SUB RULE SP***********************

         SET @n_Total = 0;
         --***********(Generic) To verify whether still got Status equal to 0************
         SET @SQL = N' SELECT @n_Total=COUNT(1) FROM ' + @c_STGTBL + N' WITH (NOLOCK) '
                    + N' WHERE STG_BatchNo = @n_BatchNo AND STG_Status = ''0'' ';


         SET @c_ExecArgs = N' @n_Total INT OUTPUT ' + N',@n_BatchNo INT ';

         IF @b_Debug = 1 PRINT @SQL;

         EXEC sp_executesql @SQL
                          , @c_ExecArgs
                          , @n_Total OUTPUT
                          , @n_BatchNo;

         IF @n_Total > 0
         BEGIN
            SET @n_Continue = 3;
            SET @b_Success = 0;
            SET @n_ErrNo = N'10018';
            SET @c_ErrMsg = N'Internal Stored Procedure Error! Some record status is still 0.(isp_SCE_DL_Generic)';
         END;
      --***********(Generic) To verify whether still got Status equal to 0************
      END;

      -- (Generic) When user click post button to import staging data into target table
      ELSE IF @n_Flag = 4
      BEGIN
         BEGIN TRY
            SET @SQL = N'';

            --**********************(Generic) START PRE-POSTING SUB RULE SP*********************
            IF EXISTS (SELECT 1 FROM @t_SubRule)
            BEGIN
               SET @SQL1 = N'';
               SET @c_ExecArgs1 = N'';
               DECLARE C_SUBRULES2 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT SubRuleID
                    , WebApiConfigID
                    , ConfigID
                    , ClientCode
                    , Code
                    , Flag
                    , Step
                    , SEQ
                    , SubRuleSP
               FROM @t_SubRule
               WHERE Flag = 2
               --AND IsActive = '1'
               ORDER BY SEQ ASC
                      , Code ASC
                      , Step ASC;

               OPEN C_SUBRULES2;
               FETCH FROM C_SUBRULES2
               INTO @n_SubRuleID
                  , @n_SubRuleWebApiConfigID
                  , @n_SubRuleConfigID
                  , @n_SubRuleClientCode
                  , @c_SubRuleCode
                  , @n_SubRuleFlag
                  , @n_SubRuleStep
                  , @n_SubRuleSEQ
                  , @c_SubRuleSP;

               WHILE @@FETCH_STATUS <> -1
               BEGIN
                  SET @SQL1 = N'EXEC ' + @c_SubRuleSP + N'  @b_Debug       = @b_Debug ' + N', @n_BatchNo     = @n_BatchNo '
                              + N', @n_Flag        = @n_Flag ' + N', @c_SubRuleJson = @c_SubRuleJson '
                              + N', @c_STGTBL      = @c_STGTBL ' + N', @c_POSTTBL     = @c_POSTTBL '
                              + N', @c_UniqKeyCol  = @c_UniqKeyCol ' + N', @c_Username    = @c_Username '
                              + N', @b_Success     = @b_Success OUTPUT' + N', @n_ErrNo       = @n_ErrNo   OUTPUT'
                              + N', @c_ErrMsg      = @c_ErrMsg  OUTPUT';

                  SET @c_ExecArgs1 = N'  @b_Debug       INT' + N', @n_BatchNo     INT' + N', @n_Flag        INT'
                                     + N', @c_SubRuleJson NVARCHAR(MAX)' + N', @c_STGTBL      NVARCHAR(250)'
                                     + N', @c_POSTTBL     NVARCHAR(250)' + N', @c_UniqKeyCol  NVARCHAR(1000)'
                                     + N', @c_Username    NVARCHAR(128)' + N', @b_Success     INT            OUTPUT'
                                     + N', @n_ErrNo       INT            OUTPUT' + N', @c_ErrMsg      NVARCHAR(250)  OUTPUT';

                  EXEC sp_executesql @SQL1
                                   , @c_ExecArgs1
                                   , @b_Debug
                                   , @n_BatchNo
                                   , @n_Flag
                                   , @c_SubRuleJson
                                   , @c_STGTBL
                                   , @c_POSTTBL
                                   , @c_UniqKeyCol
                                   , @c_Username
                                   , @b_Success OUTPUT
                                   , @n_ErrNo OUTPUT
                                   , @c_ErrMsg OUTPUT;


                  IF @n_ErrNo <> 0
                  OR ISNULL(RTRIM(@c_ErrMsg), '') <> ''
                  BEGIN
                     SET @n_Continue = 3;
                     GOTO QUIT;
                  END;

                  FETCH FROM C_SUBRULES2
                  INTO @n_SubRuleID
                     , @n_SubRuleWebApiConfigID
                     , @n_SubRuleConfigID
                     , @n_SubRuleClientCode
                     , @c_SubRuleCode
                     , @n_SubRuleFlag
                     , @n_SubRuleStep
                     , @n_SubRuleSEQ
                     , @c_SubRuleSP;

               END;
               CLOSE C_SUBRULES2;
               DEALLOCATE C_SUBRULES2;
            END;
            --**********************(Generic) END PRE-POSTING SUB RULE SP***********************

            BEGIN TRAN;

            --(Generic) Delete All Then Insert All
            IF @c_ActType = 2
            BEGIN
               SET @SQL = N'';
               SET @SQL = N' DELETE FROM ' + @c_POSTTBL;

               IF @b_Debug = 1 PRINT @SQL;

               EXEC sp_executesql @SQL;
            END;

            --(Generic) Delete With Check Unique Key, Then Insert New
            ELSE IF @c_ActType = 3
            BEGIN
               EXEC [dbo].[isp_SCE_DL_DelExistingRecords] @b_Debug = @b_Debug
                                                        , @n_BatchNo = @n_BatchNo
                                                        , @c_STGTBL = @c_STGTBL
                                                        , @c_POSTTBL = @c_POSTTBL
                                                        , @c_UniqKeyCol = @c_UniqKeyCol
                                                        , @b_Success = @b_Success OUTPUT
                                                        , @n_ErrNo = @n_ErrNo OUTPUT
                                                        , @c_ErrMsg = @c_ErrMsg OUTPUT;

               IF @n_ErrNo <> 0
               OR ISNULL(RTRIM(@c_ErrMsg), '') <> ''
               BEGIN
                  SET @n_Continue = 3;
                  GOTO QUIT;
               END;
            END;

            --(Generic) Plain Insert
            EXEC [dbo].[isp_SCE_DL_PlainInsert] @b_Debug = @b_Debug
                                              , @n_BatchNo = @n_BatchNo
                                              , @c_STGTBL = @c_STGTBL
                                              , @c_POSTTBL = @c_POSTTBL
                                              , @b_Success = @b_Success OUTPUT
                                              , @n_ErrNo = @n_ErrNo OUTPUT
                                              , @c_ErrMsg = @c_ErrMsg OUTPUT;

            IF @n_ErrNo <> 0
            OR ISNULL(RTRIM(@c_ErrMsg), '') <> ''
            BEGIN
               SET @n_Continue = 3;
               GOTO QUIT;
            END;

            COMMIT TRAN;

            --**********************(Generic) START POST-POSTING SUB RULE SP*********************
            IF EXISTS (SELECT 1 FROM @t_SubRule)
            BEGIN
               SET @SQL1 = N'';
               SET @c_ExecArgs1 = N'';
               DECLARE C_SUBRULES3 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT SubRuleID
                    , WebApiConfigID
                    , ConfigID
                    , ClientCode
                    , Code
                    , Flag
                    , Step
                    , SEQ
                    , SubRuleSP
               FROM @t_SubRule
               WHERE Flag = 3
               --AND IsActive = '1'
               ORDER BY SEQ ASC
                      , Code ASC
                      , Step ASC;

               OPEN C_SUBRULES3;
               FETCH FROM C_SUBRULES3
               INTO @n_SubRuleID
                  , @n_SubRuleWebApiConfigID
                  , @n_SubRuleConfigID
                  , @n_SubRuleClientCode
                  , @c_SubRuleCode
                  , @n_SubRuleFlag
                  , @n_SubRuleStep
                  , @n_SubRuleSEQ
                  , @c_SubRuleSP;

               WHILE @@FETCH_STATUS <> -1
               BEGIN
                  SET @SQL1 = N'EXEC ' + @c_SubRuleSP + N'  @b_Debug       = @b_Debug ' + N', @n_BatchNo     = @n_BatchNo '
                              + N', @n_Flag        = @n_Flag ' + N', @c_SubRuleJson = @c_SubRuleJson '
                              + N', @c_STGTBL      = @c_STGTBL ' + N', @c_POSTTBL     = @c_POSTTBL '
                              + N', @c_UniqKeyCol  = @c_UniqKeyCol ' + N', @c_Username    = @c_Username '
                              + N', @b_Success     = @b_Success OUTPUT' + N', @n_ErrNo       = @n_ErrNo   OUTPUT'
                              + N', @c_ErrMsg      = @c_ErrMsg  OUTPUT';

                  SET @c_ExecArgs1 = N'  @b_Debug       INT' + N', @n_BatchNo     INT' + N', @n_Flag        INT'
                                     + N', @c_SubRuleJson NVARCHAR(MAX)' + N', @c_STGTBL      NVARCHAR(250)'
                                     + N', @c_POSTTBL     NVARCHAR(250)' + N', @c_UniqKeyCol  NVARCHAR(1000)'
                                     + N', @c_Username    NVARCHAR(128)' + N', @b_Success     INT            OUTPUT'
                                     + N', @n_ErrNo       INT            OUTPUT' + N', @c_ErrMsg      NVARCHAR(250)  OUTPUT';

                  EXEC sp_executesql @SQL1
                                   , @c_ExecArgs1
                                   , @b_Debug
                                   , @n_BatchNo
                                   , @n_Flag
                                   , @c_SubRuleJson
                                   , @c_STGTBL
                                   , @c_POSTTBL
                                   , @c_UniqKeyCol
                                   , @c_Username
                                   , @b_Success OUTPUT
                                   , @n_ErrNo OUTPUT
                                   , @c_ErrMsg OUTPUT;


                  IF @n_ErrNo <> 0
                  OR ISNULL(RTRIM(@c_ErrMsg), '') <> ''
                  BEGIN
                     SET @n_Continue = 3;
                     GOTO QUIT;
                  END;

                  FETCH FROM C_SUBRULES3
                  INTO @n_SubRuleID
                     , @n_SubRuleWebApiConfigID
                     , @n_SubRuleConfigID
                     , @n_SubRuleClientCode
                     , @c_SubRuleCode
                     , @n_SubRuleFlag
                     , @n_SubRuleStep
                     , @n_SubRuleSEQ
                     , @c_SubRuleSP;
               END;
               CLOSE C_SUBRULES3;
               DEALLOCATE C_SUBRULES3;
            END;
         --**********************(Generic) END POST-POSTING SUB RULE SP***********************

         END TRY
         BEGIN CATCH
            IF  @@TRANCOUNT = 1
            AND @@TRANCOUNT > @n_StartCnt
            BEGIN
               ROLLBACK TRAN;
            END;
            SET @n_Continue = 3;
            SET @b_Success = 0;
            SET @n_ErrNo = N'10019';
            SET @c_ErrMsg = N'Failed to Perform Action to Delete or Insert!' + ERROR_MESSAGE() + '(isp_SCE_DL_Generic)';
         END CATCH;

         --***********(Generic) To get total count for SCE showing purpose************
         SET @SQL = N' SELECT @n_Total=COUNT(1) FROM ' + @c_STGTBL + N' WITH (NOLOCK) ' + N' WHERE 1 = 1 ' + @c_WHRParams
                    + N' AND STG_BatchNo = @n_BatchNo ';

         SET @c_ExecArgs = N' @n_Total INT OUTPUT ' + N',@n_BatchNo INT ';

         IF @b_Debug = 1 PRINT @SQL;

         EXEC sp_executesql @SQL
                          , @c_ExecArgs
                          , @n_Total OUTPUT
                          , @n_BatchNo;

         --IF @n_Total <= 0
         --BEGIN
         --   SET @n_Continue = 3;
         --   SET @b_Success = 0;
         --   SET @n_ErrNo = N'10020';
         --   SET @c_ErrMsg = N'No result has been found!(isp_SCE_DL_Generic)';
         --END;
         --***********(Generic) To get total count for SCE showing purpose************
      END;

      FETCH FROM C_TBL1
      INTO @c_STGTBL
         , @c_POSTTBL
         , @c_ListNo
         , @c_UniqKeyCol
         , @c_STG_Data
         , @c_SearchCriteria;
   END;
   CLOSE C_TBL1;
   DEALLOCATE C_TBL1;

   QUIT:
   IF @n_Continue = 3
   BEGIN
      SET @c_HdrStatus = N'failed';
      SET @c_Message = N'Inquire Failed';
      SET @c_innerJSON = (
      SELECT @c_Message      AS [message]
           , @n_PageNum      AS [pageNum]
           , @n_Limit        AS [pageSize]
           , @n_Total        AS [total]
           , @c_subInnerJson AS [data]
      FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
      );

      SET @c_outerJSON = (
      SELECT @c_innerJSON                 AS [data]
           , ISNULL(@n_ErrNo, 0)          AS [errorcode]
           , ISNULL(RTRIM(@c_ErrMsg), '') AS [errormessage]
           , @c_HdrStatus                 AS [status]
      FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
      );

      SET @c_ResponseString = (
      SELECT JSON_QUERY(@c_outerJSON) AS [result]
      FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
      );
   END;
   ELSE
   BEGIN
      SET @SQL = N' SELECT @c_subInnerJson = ISNULL(( ';

      IF @n_Flag = 1
      BEGIN
         SET @SQL += N' SELECT * FROM ' + @c_listTable + N' WHERE 1 = 1 ' + @c_WHRParams + N' AND T1.STG_BatchNo = @n_BatchNo '
                     + N' ORDER BY ' + @c_FSortColumn
                     + CASE WHEN @n_SortOrder = 0 THEN ' ASC '
                            ELSE
                                 ' DESC '
                       END;
      END;
      ELSE IF @n_Flag IN (2, 3, 4)
      BEGIN
         SET @SQL += N' SELECT T1.RowRefNo, T1.STG_BatchNo, T1.STG_SeqNo, T1.STG_Status, T1.STG_ErrMsg ' + N' FROM '
                     + @c_listTable + N' WHERE T1.STG_BatchNo = @n_BatchNo ' + N' ORDER BY T1.[STG_SeqNo] ASC ';
      END;

      SET @SQL += N' OFFSET @n_Offset ROWS ' + N' FETCH NEXT @n_Limit ROWS ONLY ' + N' FOR JSON AUTO),''[{}]'') ';

      SET @c_ExecArgs = N' @c_subInnerJson NVARCHAR(MAX) OUTPUT ' + N',@n_BatchNo INT ' + N',@n_Offset INT ' + N',@n_Limit INT ';

      IF @b_Debug = 1 PRINT @SQL;

      EXEC sp_executesql @SQL
                       , @c_ExecArgs
                       , @c_subInnerJson OUTPUT
                       , @n_BatchNo
                       , @n_Offset
                       , @n_Limit;

      SET @c_innerJSON = (
      SELECT @c_Message                  AS [message]
           , @n_PageNum                  AS [pageNum]
           , @n_Limit                    AS [pageSize]
           , @n_Total                    AS [total]
           , JSON_QUERY(@c_subInnerJson) AS [data]
      FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
      );

      SET @c_outerJSON = (
      SELECT JSON_QUERY(@c_innerJSON)     AS [data]
           , ISNULL(@n_ErrNo, 0)          AS [errorcode]
           , ISNULL(RTRIM(@c_ErrMsg), '') AS [errormessage]
           , @c_HdrStatus                 AS [status]
      FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
      );

      SET @c_ResponseString = (
      SELECT JSON_QUERY(@c_outerJSON) AS [result]
      FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
      );
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
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: lsp_TMCCRelease_Wrapper                             */  
/* Creation Date: 19-OCT-2018                                            */  
/* Copyright: LFL                                                        */  
/* Written by: Wan                                                       */  
/*                                                                       */  
/* Purpose: LFWM-1052 - Stored procedure - Supervisor Alerts -           */
/*          Release Cycle Count Tasks                                    */  
/*        : LFWM-1273 - Stored Procedures for Feature - Release Cycle    */
/*          Count                                                        */  
/* Called By:                                                            */  
/*                                                                       */  
/*                                                                       */  
/* Version: 1.4                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author   Ver   Purposes                                   */ 
/* 2020-06-04  Wan01    1.1   LFWM-2113- UAT  Release cycle count  should*/
/*                            enable Release cycle count task action button*/
/* 2021-02-09  mingle01 1.2   Add Big Outer Begin try/Catch              */
/*                            Execute Login if @c_UserName<>SUSER_SNAME()*/
/* 2021-12-16  Wan02    1.3   DevOps Combine Script                      */
/* 2021-12-16  Wan02    1.3   LFWM-3258 - CN NIKECN UAT Release cycle    */
/*                            count Options Deviation                    */
/* 2022-02-24  Wan03    1.4   LFWM-3287 - CN NIKECN Release Cycle Count  */
/*************************************************************************/   
CREATE PROCEDURE [WM].[lsp_TMCCRelease_Wrapper]
   @c_CountType            NVARCHAR(10)  
,  @c_Storerkey            NVARCHAR(15)
,  @c_Sku                  NVARCHAR(20)
,  @c_Loc                  NVARCHAR(10)
,  @c_Storerkey_Prev       NVARCHAR(15)
,  @c_Sku_Prev             NVARCHAR(20)
,  @c_Loc_Prev             NVARCHAR(10)
,  @c_AlertKey             NVARCHAR(18) = ''
,  @n_MaxCount             INT          = 0
,  @c_GroupKeyTableField   NVARCHAR(50) = ''
,  @c_FilterCode           NVARCHAR(30) = ''             --(Wan03) Rename @c_FitlerCode to correct Variable name 
,  @n_TotalTaskCnt         INT          = 0   OUTPUT
,  @n_TotalSkuCnt          INT          = 0   OUTPUT  
,  @n_TotalLocCnt          INT          = 0   OUTPUT              
,  @c_BatchNo              NVARCHAR(10) = ''  OUTPUT
,  @b_Success              INT          = 1   OUTPUT   
,  @n_Err                  INT          = 0   OUTPUT
,  @c_Errmsg               NVARCHAR(255)= ''  OUTPUT
,  @n_WarningNo            INT          = 0   OUTPUT
,  @c_ProceedWithWarning   CHAR(1)      = 'N' 
,  @c_UserName             NVARCHAR(128)= ''
,  @c_Facility             NVARCHAR(5)  = ''             --(Wan03)
,  @c_CountType_Code       NVARCHAR(10) = ''             --(Wan03)
,  @n_MaxAisleCount        INT          = 0              --(Wan03)

AS  
BEGIN  
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue        INT = 1
         , @n_StartTCnt       INT = @@TRANCOUNT

         , @n_Count           INT = 0 
         --, @c_Facility        NVARCHAR(5)              --(Wan03)
         , @c_LocAisle        NVARCHAR(10)
         , @c_LocLevel        INT

         , @c_BatchNo_Del     NVARCHAR(10) = ''

         , @c_TaskDetailKey   NVARCHAR(10) = ''
         , @c_TaskType        NVARCHAR(10) = ''
         , @c_CCkey           NVARCHAR(10) = ''
         , @c_SourceType      NVARCHAR(10) = 'TMCCRLSE'
         , @c_PickMethod      NVARCHAR(10) = ''
         , @c_Priority        NVARCHAR(10) = '5'
         , @c_ListKey         NVARCHAR(10) = 'ALERT'
         , @c_Message03       NVARCHAR(20) = ''
         , @c_RefTaskKey      NVARCHAR(10) = ''
         , @c_GroupKey        NVARCHAR(10) = ''

         , @b_InsertLog       BIT          = 0
         , @n_Pos             INT          = 0
         , @c_TableName       NVARCHAR(50) = ''
         , @c_ColumnName      NVARCHAR(50) = ''

         , @c_SQL             NVARCHAR(1000)= ''
         , @c_SQLParms        NVARCHAR(500) = ''
 
         , @CUR_INV           CURSOR

   SET @b_Success = 1
   SET @c_ErrMsg = ''

   SET @n_Err = 0 
   --(mingle01) - START   
   IF SUSER_SNAME() <> @c_UserName
   BEGIN
      EXEC [WM].[lsp_SetUser] 
            @c_UserName = @c_UserName  OUTPUT
         ,  @n_Err      = @n_Err       OUTPUT
         ,  @c_ErrMsg   = @c_ErrMsg    OUTPUT
                
      IF @n_Err <> 0 
      BEGIN
         GOTO EXIT_SP
      END
    
      EXECUTE AS LOGIN = @c_UserName
   END
   --(mingle01) - END
   
   BEGIN TRAN              --(Wan02)
   --(mingle01) - START
   BEGIN TRY
      SET @c_GroupKeyTableField = ISNULL(RTRIM(@c_GroupKeyTableField),'')
      SET @c_FilterCode = ISNULL(RTRIM(@c_FilterCode),'')

      SELECT @c_PickMethod = ISNULL(RTRIM(udf01), '') 
            ,@c_TaskType   = ISNULL(RTRIM(udf02), '')
      FROM CODELKUP WITH (NOLOCK)
      WHERE Listname = 'PITYPE'
      AND Code = @c_CountType

      IF @c_TaskType = ''
      BEGIN
         SET @c_TaskType = 'CC'
      END

      IF @c_ProceedWithWarning = 'N' AND @n_WarningNo = 0
      BEGIN
         IF @c_PickMethod = ''
         BEGIN
            SET @n_continue  = 3
            SET @n_Err       = 554251
            SET @c_ErrMsg= 'NSQL' + CONVERT(NCHAR(6), @n_Err) 
                         + ': Count Type is required for code ' + RTRIM(@c_CountType)  
                         + '. Please setup Count Type in Codelkup''s Listname ''PITYPE'''
                         + '. (lsp_TMCCRelease_Wrapper)'
                         + ' |' + RTRIM(@c_CountType) 

            GOTO EXIT_SP
         END

         IF @c_GroupKeyTableField <> ''
         BEGIN
            SET @n_Count = 0 
            SET @n_Pos = CHARINDEX('.', @c_GroupKeyTableField ) 

            IF @n_Pos > 0 
            BEGIN
               SET @n_Count = 1
               SET @c_TableName = LEFT (@c_GroupKeyTableField, @n_Pos - 1)
               SET @c_ColumnName= RIGHT(@c_GroupKeyTableField,LEN(@c_GroupKeyTableField) - @n_Pos)
            END

            IF @n_Count = 1
            BEGIN
               SET @n_Count = 0
               SELECT @n_Count = 1
               FROM   INFORMATION_SCHEMA.COLUMNS WITH (NOLOCK)                                                                                                                       
               WHERE  TABLE_NAME = @c_TableName                                                                                                                         
               AND   COLUMN_NAME = @c_ColumnName
            END


            IF @n_Count = 1
            BEGIN
              IF @c_CountType = 'LOC' AND @c_TableName <> 'LOC'
              BEGIN
                 SET @n_Count = 0
              END
              ELSE IF @c_CountType = 'SKU' AND @c_TableName NOT IN ('SKU', 'LOC')
              BEGIN
                 SET @n_Count = 0
              END
            END

            IF @n_Count = 0
            BEGIN
               SET @n_continue  = 3
               SET @n_Err       = 554258
               SET @c_ErrMsg= 'NSQL' + CONVERT(NCHAR(6), @n_Err) 
                            + ': Invalid table column setup for task group' 
                            + '. (lsp_TMCCRelease_Wrapper)'

               GOTO EXIT_SP
            END
         END

         SET @n_Count = 0
         SELECT @n_Count = 1
         FROM TaskDetail WITH (NOLOCK) 
         WHERE TaskType   = @c_TaskType
         AND   SourceType = @c_SourceType
         AND   [Status]   = '0'
         AND   PickMethod = @c_PickMethod 

         SET @n_continue  = 3
         SET @c_ErrMsg= 'There are ' + CONVERT(NVARCHAR(10),@n_Count) + '  pending ' + RTRIM(@c_TaskType)
                        + ' tasks. Do you want to generate ' + RTRIM(@c_CountType) + ' type?'
         SET @n_WarningNo = 1
         GOTO EXIT_SP
      END

      -----------------------------------------------
      -- Start Generating TASKDETAIL/ TASKDETAIL_WIP
      -----------------------------------------------
      --(Wan03) - START    ----Sku Release Data has BULK INserted to TASKDETAIL_WIP
      SET @c_Sku_Prev = ISNULL(RTRIM(@c_Sku_Prev),'')
      SET @c_Loc_Prev = ISNULL(RTRIM(@c_Loc_Prev),'')      
      SET @c_BatchNo = ISNULL(RTRIM(@c_BatchNo),'')
      SET @c_AlertKey = ISNULL(RTRIM(@c_AlertKey),'') 

      IF @c_Sku_Prev = '' AND @c_Loc_Prev = '' AND @c_BatchNo <> '' AND @c_AlertKey = ''     --First Record
      BEGIN
         SET @b_Success = 1
         EXEC dbo.isp_TMCCRelease_Wrapper   
              @c_TaskWIPBatchNo     = @c_BatchNo   
            , @c_Facility           = @c_Facility  
            , @c_Storerkey          = @c_Storerkey            
            , @c_Counttype_Code     = @c_CountType_Code   
            , @n_MaxCount           = @n_MaxCount  
            , @n_MaxAisleCount      = @n_MaxAisleCount   
            , @c_GroupKeyTableField = @c_GroupKeyTableField      
            , @c_ReleaseFilterCode  = @c_FilterCode   
            , @n_ttltaskcnt         = @n_TotalTaskCnt OUTPUT  
            , @n_distinctskucnt     = @n_TotalSkuCnt  OUTPUT  
            , @n_distinctloccnt     = @n_TotalLocCnt  OUTPUT                       
            , @b_Success            = @b_Success      OUTPUT--0: fail, 1= Success, 2: Continue PB Logic to generate TMCC  
            , @n_Err                = @n_Err          OUTPUT  
            , @c_ErrMsg             = @c_ErrMsg       OUTPUT 
            , @b_ForceAdvanceTMCC   = 0                     --If AdvanceTMCC = 0, Use Storerconfig to check SkipAdvanceCCRelease
            
         IF @b_Success IN ( 0, 1 )                          --If Return 2, continue to Release TMCC using AdvanceCCRelease method
         BEGIN
            SET @n_Continue = 4                             --Set to Stop Looping If no error
               
            GOTO EXIT_SP
         END
         
         -- Call isp_TMCCRelease_Wrapper to force and use Advance CC Release
         SET @b_Success = 1
         EXEC dbo.isp_TMCCRelease_Wrapper   
              @c_TaskWIPBatchNo     = @c_BatchNo   
            , @c_Facility           = @c_Facility  
            , @c_Storerkey          = @c_Storerkey            
            , @c_Counttype_Code     = @c_CountType_Code   
            , @n_MaxCount           = @n_MaxCount  
            , @n_MaxAisleCount      = @n_MaxAisleCount   
            , @c_GroupKeyTableField = @c_GroupKeyTableField      
            , @c_ReleaseFilterCode  = @c_FilterCode   
            , @n_ttltaskcnt         = @n_TotalTaskCnt OUTPUT  
            , @n_distinctskucnt     = @n_TotalSkuCnt  OUTPUT  
            , @n_distinctloccnt     = @n_TotalLocCnt  OUTPUT                        
            , @b_Success            = @b_Success      OUTPUT--0: fail, 1= Success, 2: Continue PB Logic to generate TMCC  
            , @n_Err                = @n_Err          OUTPUT  
            , @c_ErrMsg             = @c_ErrMsg       OUTPUT 
            , @b_ForceAdvanceTMCC   = 1 
         
          SET @n_Continue = 4                               --Set to Stop Looping If no error
               
          GOTO EXIT_SP
      END 
      --(Wan03) - END
      
      IF ISNULL(RTRIM(@c_BatchNo),'') = '' AND ISNULL(RTRIM(@c_AlertKey),'') = ''
      BEGIN
         WHILE 1= 1
         BEGIN
            SET @c_BatchNo_Del = ''
            SELECT TOP 1 @c_BatchNo_Del = TaskWIPBatchNo
            FROM TASKDETAIL_WIP WITH (NOLOCK)
            WHERE AddWho = @c_UserName

            IF @c_BatchNo_Del = ''  
            BEGIN
               BREAK
            END

            SET @b_success = 1  
            BEGIN TRY      
               EXEC WM.lsp_TaskDetail_WIP_Delete      
                 @c_BatchNo = @c_BatchNo_Del     
               , @b_success = @b_success  OUTPUT        
               , @n_err     = @n_err      OUTPUT        
               , @c_errmsg  = @c_errmsg   OUTPUT
               , @c_UserName= @c_UserName             --(Wan) 
            END TRY

            BEGIN CATCH
               SET @n_err = 554706
               SET @c_ErrMsg = ERROR_MESSAGE()
               SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) 
                              + ': Error Executing lsp_TaskDetail_WIP_Delete. (lsp_TMCCRelease_Wrapper)'
                              + '( ' + @c_errmsg + ' )'
            END CATCH    
                      
            IF @b_success = 0 OR @n_Err <> 0        
            BEGIN        
               SET @n_continue = 3      
               GOTO EXIT_SP
            END  
         END
      END

      IF @c_CountType = 'LOC' AND RTRIM(@c_Loc) = ''
      BEGIN
         SET @n_continue  = 3
         SET @n_Err       = 554252
         SET @c_ErrMsg= 'NSQL' + CONVERT(NCHAR(6), @n_Err) 
                        + ': Empty Loc Found'
                        + '. (lsp_TMCCRelease_Wrapper)'

         GOTO EXIT_SP
      END

      IF @c_CountType = 'SKU' AND RTRIM(@c_Sku) = ''
      BEGIN
         SET @n_continue  = 3
         SET @n_Err       = 554253
         SET @c_ErrMsg= 'NSQL' + CONVERT(NCHAR(6), @n_Err) 
                        + ': Empty Sku Found'
                        + '. (lsp_TMCCRelease_Wrapper)'

         GOTO EXIT_SP
      END

      IF @c_CountType = 'SKU'
      BEGIN
         IF @c_Storerkey = @c_Storerkey_Prev AND @c_Sku = @c_Sku_Prev AND @c_Loc = @c_Loc_Prev  --(Wan01)
         BEGIN
            GOTO EXIT_SP
         END

         IF @c_AlertKey = '' AND @n_MaxCount <= @n_TotalSkuCnt
         BEGIN
            SET @n_Continue = 4
            GOTO EXIT_SP
         END

         SET @n_Count = 0
         SELECT @n_Count = 1
         FROM TaskDetail WITH (NOLOCK) 
         WHERE TaskType   = @c_TaskType
         AND   SourceType = @c_SourceType
         AND   [Status]   = '0'
         AND   PickMethod = @c_PickMethod 
         AND   Storerkey  = @c_Storerkey
         AND   Sku        = @c_Sku

         IF @n_Count > 0
         BEGIN
            GOTO EXIT_SP         
         END
      END
      ELSE IF @c_CountType = 'LOC'
      BEGIN
      IF @c_Loc = @c_Loc_Prev 
         BEGIN
            GOTO EXIT_SP
         END

         IF @c_AlertKey = '' AND @n_MaxCount <= @n_TotalLocCnt
         BEGIN
            SET @n_Continue = 4
            GOTO EXIT_SP
         END

         SET @n_Count = 0
         SELECT @n_Count = 1
         FROM TaskDetail WITH (NOLOCK) 
         WHERE TaskType   = @c_TaskType
         AND   SourceType = @c_SourceType
         AND   [Status]   = '0'
         AND   PickMethod = @c_PickMethod 
         AND   FromLoc  = @c_Loc
         AND   Storerkey= @c_Storerkey             --(Wan02)

         IF @n_Count > 0
         BEGIN
            GOTO EXIT_SP         
         END

         --SET @c_Storerkey = ''                   --(Wan02)
         SET @c_Sku = ''
      END

      IF @c_FilterCode <> ''
      BEGIN
         SET @n_Count = 0
         SELECT @n_Count = 1 
         FROM sys.objects WITH (NOLOCK) 
         WHERE [name] = @c_FilterCode
         AND [type] = 'P'

         IF  @n_Count = 1 
         BEGIN
            BEGIN TRY 
               SET @b_success = 1
               SET @c_SQLParms= N'@c_CountType  NVARCHAR(10)'
                              + ',@c_Storerkey  NVARCHAR(15)'
                              + ',@c_Sku        NVARCHAR(20)'
                              + ',@c_Loc        NVARCHAR(10)'
                              + ',@b_success    INT  OUTPUT ' 

               EXEC sp_Execute @c_FilterCode
                           ,  @c_SQLParms
                           ,  @c_Storerkey
                           ,  @c_Sku
                           ,  @c_Loc
                           ,  @b_success  OUTPUT
            END TRY

            BEGIN CATCH
               SET @n_Continue = 3
               SET @c_ErrMsg = ERROR_MESSAGE()
               SET @n_err    = 554259
               SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) 
                             + ': Error Executing ' + @c_FilterCode + '. (lsp_TMCCRelease_Wrapper)'
                             + '( ' + @c_errmsg + ' )'
               GOTO EXIT_SP   
            END CATCH   

            IF @b_success = -1  
            BEGIN
               SET @n_Continue = 3
               GOTO EXIT_SP         
            END

            IF @b_success = 0  
            BEGIN
               GOTO EXIT_SP         
            END
         END 
      END

      IF @c_GroupKeyTableField <> ''
      BEGIN
         SET @n_Pos = CHARINDEX('.', @c_GroupKeyTableField) 
         IF @n_Pos > 0 
         BEGIN
            SET @c_TableName = LEFT (@c_GroupKeyTableField, @n_Pos - 1)
         END

         SET @c_GroupKey = ''
         IF @c_TableName = 'LOC'
         BEGIN
            SET @c_SQL = N'SELECT @c_GroupKey = ' + @c_GroupKeyTableField 
                       + ' FROM LOC WITH (NOLOCK) '
                       + ' WHERE LOC.Loc = @c_Loc'
         END
         ELSE IF @c_TableName = 'SKU'
         BEGIN
            SET @c_SQL = N'SELECT @c_GroupKey = ' + @c_GroupKeyTableField 
                       + ' FROM SKU WITH (NOLOCK) '
                       + ' WHERE SKU.Storerkey = @c_Storerkey'
                       + ' AND SKU.Storerkey = @c_Sku'
         END

         SET @c_SQLParms= N'@c_GroupKey   NVARCHAR(10) OUTPUT'
                        + ',@c_Storerkey  NVARCHAR(15) '
                        + ',@c_Sku        NVARCHAR(20) '
                        + ',@c_Loc        NVARCHAR(10) '

         EXEC sp_ExecuteSQL @c_SQL
                     ,  @c_SQLParms
                     ,  @c_GroupKey   OUTPUT
                     ,  @c_Storerkey
                     ,  @c_Sku
                     ,  @c_Loc

      END

      ----------------------------------------------
      -- Supervisor Alert Release CC Tasks ( START )
      ----------------------------------------------
      SUP_ALERT_RELEASE:
      IF @c_AlertKey <> ''
      BEGIN
         IF ISNULL(@c_BatchNo,'') = ''  
         BEGIN
            -- GEt CCKey
            SET @b_success = 1  
            BEGIN TRY      
               EXECUTE nspg_getkey        
               'CCKey'        
               , 10        
               , @c_BatchNo   OUTPUT        
               , @b_success   OUTPUT        
               , @n_err       OUTPUT        
               , @c_errmsg    OUTPUT        
            END TRY

            BEGIN CATCH
               SET @n_err = 554254
               SET @c_ErrMsg = ERROR_MESSAGE()
               SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) 
                             + ': Error Executing nspg_getkey - CCKey. (lsp_TMCCRelease_Wrapper)'
                             + '( ' + @c_errmsg + ' )'
            END CATCH    
                         
            IF @b_success = 0 OR @n_Err <> 0        
            BEGIN        
               SET @n_continue = 3      
               GOTO EXIT_SP
            END  
         END  
         SET @c_CCKey = @c_BatchNo    

         SET @b_success = 1  
         BEGIN TRY      
            EXECUTE nspg_getkey        
            'TaskDetailKey'        
            , 10        
            , @c_TaskDetailKey   OUTPUT        
            , @b_success         OUTPUT        
            , @n_err             OUTPUT        
            , @c_errmsg          OUTPUT        
         END TRY

         BEGIN CATCH
            SET @n_err = 554255
            SET @c_ErrMsg = ERROR_MESSAGE()
            SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) 
                           + ': Error Executing nspg_getkey - TaskDetailKey. (lsp_TMCCRelease_Wrapper)'
                           + '( ' + @c_errmsg + ' )'
         END CATCH    
                      
         IF @b_success = 0 OR @n_Err <> 0        
         BEGIN        
            SET @n_continue = 3      
            GOTO EXIT_SP
         END        

         SELECT @c_RefTaskKey = ISNULL(RTRIM(TaskDetailKey),'')
         FROM ALERT WITH (NOLOCK)
         WHERE AlertKey = @c_AlertKey

         SET @c_Message03 = @c_AlertKey

         BEGIN TRY
            INSERT INTO TASKDETAIL 
            (  TaskDetailKey
            ,  TaskType
            ,  Storerkey
            ,  Sku
            ,  Lot
            ,  FromLoc
            ,  FromID
            ,  ToLoc
            ,  ToID
            ,  Qty
            ,  SourceKey 
            ,  SourceType
            ,  PickMethod
            ,  [Priority] 
            ,  ListKey
            ,  Message03 
            ,  RefTaskKey 
            )
            VALUES
            (  @c_TaskdetailKey
            ,  @c_TaskType
            ,  @c_Storerkey
            ,  @c_Sku
            ,  ''
            ,  @c_Loc
            ,  ''
            ,  ''
            ,  ''
            ,  0
            ,  @c_CCKey 
            ,  @c_SourceType
            ,  @c_PickMethod
            ,  @c_Priority 
            ,  @c_ListKey
            ,  @c_Message03 
            ,  @c_RefTaskKey 
            )

         END TRY

         BEGIN CATCH
            SET @n_err = 554256
            SET @c_ErrMsg = ERROR_MESSAGE()
            SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Insert Into TASKDETAIL Fail. (lsp_TMCCRelease_Wrapper)'
                           + '( ' + @c_errmsg + ' )'
         END CATCH    

         IF @b_success = 0 OR @n_Err <> 0        
         BEGIN        
            SET @n_continue = 3      
            GOTO EXIT_SP
         END 

         BEGIN TRY
            UPDATE ALERT
               SET TaskDetailKey2 = @c_TaskDetailKey  
                  ,TrafficCop = NULL
            WHERE AlertKey = @c_AlertKey
         END TRY

         BEGIN CATCH
            SET @n_continue = 3 
            SET @n_err = 554257
            SET @c_ErrMsg = ERROR_MESSAGE()
            SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Update ALERT table Fail. (lsp_TMCCRelease_Wrapper)'
                           + '( ' + @c_errmsg + ' )'
            GOTO EXIT_SP
         END CATCH    
      END
      ----------------------------------------------
      -- Supervisor Alert Release CC Tasks ( END )
      ----------------------------------------------

      ----------------------------------------------
      -- CC Release Tasks ( START )
      ----------------------------------------------
      CC_RELEASE:
      IF @c_AlertKey = ''
      BEGIN
         IF ISNULL(@c_BatchNo,'') = ''  
         BEGIN
            -- GEt CCKey
            SET @b_success = 1  
            BEGIN TRY      
               EXECUTE nspg_getkey        
               'TASKWIPBATCHNO'        
               , 10        
               , @c_BatchNo   OUTPUT        
               , @b_success   OUTPUT        
               , @n_err       OUTPUT        
               , @c_errmsg    OUTPUT        
            END TRY

            BEGIN CATCH
               SET @n_err = 554260
               SET @c_ErrMsg = ERROR_MESSAGE()
               SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) 
                             + ': Error Executing nspg_getkey - TASKWIPBATCHNO. (lsp_TMCCRelease_Wrapper)'
                             + '( ' + @c_errmsg + ' )'
            END CATCH    
                         
            IF @b_success = 0 OR @n_Err <> 0        
            BEGIN        
               SET @n_continue = 3      
               GOTO EXIT_SP
            END  

            SET @b_InsertLog = 1
         END   

         SET @c_ListKey = CONVERT(VARCHAR(10), @n_MaxCount)

         BEGIN TRY
            INSERT INTO TASKDETAIL_WIP 
            (  TaskWIPBatchNo
            ,  TaskDetailKey
            ,  TaskType
            ,  Storerkey
            ,  Sku
            ,  Lot
            ,  FromLoc
            ,  FromID
            ,  ToLoc
            ,  ToID
            ,  Qty
            ,  SourceKey 
            ,  SourceType
            ,  PickMethod
            ,  [Priority] 
            ,  ListKey
            ,  Message03 
            ,  RefTaskKey 
            ,  Groupkey
            )
            VALUES
            (  @c_BatchNo
            ,  ''
            ,  @c_TaskType
            ,  @c_Storerkey
            ,  @c_Sku
            ,  ''
            ,  @c_Loc
            ,  ''
            ,  ''
            ,  ''
            ,  0
            ,  @c_CCKey 
            ,  @c_SourceType
            ,  @c_PickMethod
            ,  @c_Priority 
            ,  @c_ListKey
            ,  @c_Message03 
            ,  @c_RefTaskKey 
            ,  @c_GroupKey
            )

         END TRY

         BEGIN CATCH
            SET @n_continue = 3 
            SET @n_err = 554261
            SET @c_ErrMsg = ERROR_MESSAGE()
            SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Insert Into TASKDETAIL_WIP Fail. (lsp_TMCCRelease_Wrapper)'
                           + '( ' + @c_errmsg + ' )'
            GOTO EXIT_SP
         END CATCH    

         IF @b_InsertLog = 1 
         BEGIN
            BEGIN TRY
               INSERT INTO IDS_GENERALLOG (udf01, udf02, udf03, udf04, udf05)
               VALUES ('SKURELOPTION', @c_BatchNo, @c_PickMethod, @c_GroupKeyTableField , @c_FilterCode )
            END TRY

            BEGIN CATCH
               SET @n_Continue = 3
               SET @n_err = 554262
               SET @c_ErrMsg = ERROR_MESSAGE()
               SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Insert into IDS_GeneralLog Fail. (lsp_TMCCRelease_Wrapper)'
                              + '( ' + @c_errmsg + ' )'

               GOTO EXIT_SP
            END CATCH  
         END
      END
      ----------------------------------------------
      -- CC Release Tasks ( END )
      ----------------------------------------------

      TASK_SUMMARY:

      SET @n_TotalTaskCnt = @n_TotalTaskCnt + 1  
      IF @c_CountType = 'SKU'
      BEGIN
         SET @n_TotalSkuCnt = @n_TotalTaskCnt 

         --(Wan02) - START
         --SELECT @n_TotalLocCnt = COUNT(DISTINCT FROMLOC)
         --FROM TASKDETAIL WITH (NOLOCK)
         --WHERE TaskType = @c_TaskType
         --AND   SourceKey= @c_CCKey
         SET @c_SQL = N'SELECT @n_TotalLocCnt = COUNT(DISTINCT FROMLOC)'
                    + ' FROM ' + CASE WHEN @c_AlertKey = '' THEN 'TASKDETAIL_WIP' ELSE 'TASKDETAIL' END +' WITH (NOLOCK)' 
                    + ' WHERE TaskType = @c_TaskType'
                    + ' AND   SourceKey= @c_CCKey'
         SET @c_SQLParms = N'@n_TotalLocCnt  INT OUTPUT' 
                         + ',@c_TaskType     NVARCHAR(10)'  
                         + ',@c_CCKey        NVARCHAR(10)' 
                         
         EXECUTE sp_ExecuteSQL @c_SQL
                              ,@c_SQLParms 
                              ,@n_TotalLocCnt   OUTPUT
                              ,@c_TaskType   
                              ,@c_CCKey   
         --(Wan02) - END                        
                                                                        
      END
      ELSE IF  @c_CountType = 'LOC'             --(Wan02)
      BEGIN
         SET @n_TotalLocCnt = @n_TotalTaskCnt 
         SET @n_TotalSkuCnt = 0
      END
   END TRY
   
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH
   --(mingle01) - END
   
   EXIT_SP:
   --(Wan02) - START
   IF (XACT_STATE()) = -1  
   BEGIN
      SET @n_Continue = 3 
      ROLLBACK TRAN
   END 
   --(Wan02) - END
   
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @n_StartTCnt = 0 AND @@TRANCOUNT > @n_StartTCnt               --(Wan02)
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_TMCCRelease_Wrapper'
   END
   ELSE
   BEGIN
      IF @n_Continue = 4 
      BEGIN 
         SET @b_Success = 2      -- MAxCount reached. Discontinue Calling SP
      END
      ELSE
      BEGIN
         SET @b_Success = 1
      END

      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      SET @n_WarningNo = 0
   END
   
   WHILE @@TRANCOUNT < @n_StartTCnt             --(Wan03) - START
   BEGIN 
      BEGIN TRAN
   END                                          --(Wan03) - END
   
   REVERT      
END  

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_TMCCRelease_Wrapper                                 */
/* Creation Date: 2021-04-14                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-16623 - [CN] Nike Phoenix Add New Count Type in         */
/*          Release-Cycle-Count                                         */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2021-04-14  Wan      1.0   Created                                   */
/* 2022-02-24  Wan01    1.1   LFWM-3287 - CN NIKECN Release Cycle Count */
/* 2022-02-24  Wan01    1.1   DevOps Combine Script                     */
/************************************************************************/
CREATE PROC [dbo].[isp_TMCCRelease_Wrapper] 
           @c_TaskWIPBatchNo     NVARCHAR(10) = '' 
         , @c_Facility           NVARCHAR(5)  = ''
         , @c_Storerkey          NVARCHAR(15)= ''            
         , @c_Counttype_Code     NVARCHAR(30) = '' 
         , @n_MaxCount           INT = 0
         , @n_MaxAisleCount      INT = 0   
         , @c_GroupKeyTableField NVARCHAR(50) = ''    
         , @c_ReleaseFilterCode  NVARCHAR(30) = ''   
         , @n_ttltaskcnt         INT = 0           OUTPUT
         , @n_distinctskucnt     INT = 0           OUTPUT
         , @n_distinctloccnt     INT = 0           OUTPUT                     
         , @b_Success            INT          = 1  OUTPUT   --0: fail, 1= Success, 2: Continue PB Logic to generate TMCC
         , @n_Err                INT          = 0  OUTPUT
         , @c_ErrMsg             NVARCHAR(255)= '' OUTPUT  
         , @b_ForceAdvanceTMCC   INT = 0                    --0: Check Storerconfig to SkipAdvanceCCRelase, Exceed call SP and use default value = 0
                                
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt                INT = @@TRANCOUNT
         , @n_Continue                 INT = 1
         
         , @c_GroupKeySQL              NVARCHAR(2000) = ''
         , @c_GroupKeyParms            NVARCHAR(2000) = ''
         , @c_SQL                      NVARCHAR(2000) = ''
         , @c_SQLParms                 NVARCHAR(2000) = ''
         
         , @n_RowID                    BIGINT         = 0     
             
         , @n_dot                      INT         = 0
         , @c_TableName                NVARCHAR(50)= ''
         , @c_ColName                  NVARCHAR(50)= '' 
                 
         , @n_BatchLastRowID           BIGINT      = 0
         --, @c_Storerkey                NVARCHAR(15)= '' 
         , @c_Sku                      NVARCHAR(20)= '' 
         , @c_Loc                      NVARCHAR(10)= ''          
         , @c_Counttype                NVARCHAR(60)= ''
         , @c_TaskType                 NVARCHAR(60)= 'CC'
         , @c_Sourcekey                NVARCHAR(10)= ''
         , @c_GroupKey                 NVARCHAR(10)= ''

         , @n_Cnt_CC                   INT         = 0
         , @n_Cnt_Aisle                INT         = 0
         
         , @c_TMCCRelease_SP           NVARCHAR(30) = ''
         , @c_SkipAdvanceCCRelease     NVARCHAR(30) = '0'

         , @CUR_RLSE                   CURSOR
      
   SET @c_Storerkey  = ISNULL(@c_Storerkey,'')   
   SET @c_Sku        = ISNULL(@c_Sku,'')     
   SET @c_GroupKeyTableField = ISNULL(@c_GroupKeyTableField,'')  
   SET @c_ReleaseFilterCode  = ISNULL(@c_ReleaseFilterCode,'')  


   IF EXISTS  ( SELECT 1 FROM CodeList with (NOLOCK) WHERE LISTNAME = 'TraceInfo' And ListGroup = '1' ) -- Turn on Traceinfo    
   AND EXISTS ( SELECT 1 FROM CodeLKUP with (NOLOCK) WHERE LISTNAME = 'TraceInfo' And Code = 'TMCCRLSE'     
                  AND Short = '1')    
   BEGIN    
      INSERT INTO TraceInfo (TraceName, TimeIn, TimeOut, TotalTime, Step1, Step2, Step3, Step4, Step5, Col1, Col2, Col3, Col4, Col5) 
      SELECT 'TMCCRLSE',GETDATE(), GETDATE()
         , 0 
         , tdw.TaskWIPBatchNo
         , tdw.Storerkey
         , tdw.Sku
         , tdw.FromLoc
         , @c_Counttype_Code
         , CONVERT(NVARCHAR(10), @n_MaxCount)
         , CONVERT(NVARCHAR(10), @n_MaxAisleCount)            
         , @c_GroupKeyTableField
         , @c_ReleaseFilterCode
         ,''
      FROM dbo.TaskDetail_WIP AS tdw WITH (NOLOCK)
      WHERE tdw.TaskWIPBatchNo = @c_TaskWIPBatchNo     
                   
      SET @n_err = @@ERROR
  
      IF @n_err <> 0        
      BEGIN        
        SET @n_continue = 3  
        GOTO QUIT_SP       
      END        
   END    
   
   --(Wan01) START
   IF @b_ForceAdvanceTMCC = 0 
   BEGIN
      SELECT @c_SkipAdvanceCCRelease = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'SkipAdvanceCCRelease')
   
      IF @c_SkipAdvanceCCRelease = '1' 
      BEGIN
         SET @b_Success = 2
         GOTO QUIT_SP
      END
   END 
   --(Wan01) END
   
   SELECT @c_Counttype = ISNULL(CL.UDF01,'')
         ,@c_TaskType  = ISNULL(CL.UDF02,'')
         ,@c_TMCCRelease_SP = ISNULL(CL.Long,'')
   FROM CODELKUP CL WITH (NOLOCK)
   WHERE CL.LISTNAME = 'PIType'
   AND CL.Code = @c_Counttype_Code

   IF @c_TaskType = '' SET @c_TaskType = 'CC'
      
   IF @c_Counttype = 'SKU'
   BEGIN
      ; WITH tdw_d (RowID) AS 
      (
         SELECT tdw.RowID
         FROM dbo.TaskDetail_WIP AS tdw WITH (NOLOCK)
         JOIN dbo.TaskDetail AS td WITH (NOLOCK) ON  td.Storerkey = tdw.Storerkey
                                                   AND td.Sku = tdw.Sku
         WHERE tdw.TaskWIPBatchNo = @c_TaskWIPBatchNo
         AND td.TaskType = @c_TaskType
         AND td.[Status] = '0'  
         AND td.SourceType = 'TMCCRLSE' 
      )
      DELETE tdw
      FROM tdw_d 
      JOIN dbo.TaskDetail_WIP AS tdw ON tdw.RowID = tdw_d.RowID
   END
   ELSE
   BEGIN
      ; WITH tdw_d (RowID) AS 
      (
         SELECT tdw.RowID
         FROM dbo.TaskDetail_WIP AS tdw WITH (NOLOCK)
         JOIN dbo.TaskDetail AS td WITH (NOLOCK) ON  td.Storerkey = tdw.Storerkey
                                                   --AND td.Sku = tdw.Sku           --2021-06-08 fixed
                                                   AND td.FromLoc = tdw.FromLoc                                                   
         WHERE tdw.TaskWIPBatchNo = @c_TaskWIPBatchNo
         AND td.TaskType = @c_TaskType
         AND td.[Status] = '0'  
         AND td.SourceType = 'TMCCRLSE' 
      )
      DELETE tdw
      FROM tdw_d 
      JOIN dbo.TaskDetail_WIP AS tdw ON tdw.RowID = tdw_d.RowID
   END
 
   IF @c_ReleaseFilterCode <> ''
   BEGIN 
      IF NOT EXISTS (SELECT 1 FROM Sys.Objects (NOLOCK) WHERE object_id = object_id(@c_ReleaseFilterCode) AND [Type] = 'P')
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 61010
         SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Invalid Release Filter SP Not Found. (isp_TMCCRelease_Wrapper)'
         GOTO QUIT_SP
      END
 
      SET @n_RowID = 0
      WHILE 1=1
      BEGIN
         SELECT TOP 1 
                  @n_RowID    = tdw.RowID 
               ,  @c_Storerkey= tdw.Storerkey
               ,  @c_Sku      = tdw.Sku 
               ,  @c_Loc      = tdw.FromLoc
         FROM dbo.TaskDetail_WIP AS tdw (NOLOCK) 
         WHERE tdw.TaskWIPBatchNo = @c_TaskWIPBatchNo
         AND tdw.RowID > @n_RowID                      --Fixed 2021-10-12
         ORDER BY tdw.RowID ASC
         
         IF @@ROWCOUNT = 0 OR @n_RowID = 0
         BEGIN
            BREAK
         END
         
         SET @c_SQL = N'EXEC ' + @c_ReleaseFilterCode 
                     + ' @c_CountType= @c_CountType'
                     + ',@c_Storerkey= @c_Storerkey' 
                     + ',@c_Sku= @c_Sku' 
                     + ',@c_Loc= @c_Loc'   
                     + ',@b_Success= @b_Success OUTPUT'                                 

         SET @c_SQLParms= N'@c_CountType  NVARCHAR(10)' 
                        + ',@c_Storerkey  NVARCHAR(15)' 
                        + ',@c_Sku        NVARCHAR(20)' 
                        + ',@c_Loc        NVARCHAR(10)'   
                        + ',@b_Success    INT  OUTPUT' 
                        
         EXEC sp_ExecuteSQL @c_SQL
                           ,@c_SQLParms 
                           ,@c_CountType
                           ,@c_Storerkey
                           ,@c_Sku
                           ,@c_Loc   
                           ,@b_Success    OUTPUT 
                              
         IF @b_Success = 0 
         BEGIN
            DELETE dbo.TaskDetail_WIP 
            WHERE RowID = @n_RowID
            
            ; WITH tdw_d (RowID) AS 
            (
               SELECT tdw.RowID
               FROM dbo.TaskDetail_WIP AS tdw WITH (NOLOCK)                                                 
               WHERE tdw.TaskWIPBatchNo = @c_TaskWIPBatchNo
               AND tdw.Storerkey = @c_Storerkey 
               AND tdw.Sku = @c_Sku
               AND tdw.FromLoc = @c_Loc
            )
            
            DELETE tdw
            FROM tdw_d 
            JOIN dbo.TaskDetail_WIP AS tdw ON tdw.RowID = tdw_d.RowID
         END
      END
   END

   SET @b_Success = 1
      
   ------------------------------------------
   -- Call Custom SP to generate TMCC - START
   ------------------------------------------
   IF @c_TMCCRelease_SP NOT IN ('0','1','')
   BEGIN
      IF NOT EXISTS (SELECT 1 FROM Sys.Objects (NOLOCK) WHERE object_id = object_id(@c_TMCCRelease_SP) AND [Type] = 'P')
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 61020
         SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Invalid Custom SP: ' + @c_TMCCRelease_SP + '. (isp_TMCCRelease_Wrapper)'       
         GOTO QUIT_SP
      END
                            
      SET @c_SQL = N'EXEC ' + @c_TMCCRelease_SP
                 + ' @c_TaskWIPBatchNo       = @c_TaskWIPBatchNo' 
                 + ',@c_Counttype_Code       = @c_Counttype_Code'    
                 + ',@n_MaxCount             = @n_MaxCount'          
                 + ',@n_MaxAisleCount        = @n_MaxAisleCount'     
                 + ',@c_GroupKeyTableField   = @c_GroupKeyTableField'
                 + ',@c_ReleaseFilterCode    = @c_ReleaseFilterCode'
                 + ',@n_ttltaskcnt           = @n_ttltaskcnt      OUTPUT'
                 + ',@n_distinctskucnt       = @n_distinctskucnt  OUTPUT'
                 + ',@n_distinctloccnt       = @n_distinctloccnt  OUTPUT'                  
                 + ',@b_Success              = @b_Success         OUTPUT'           
                 + ',@n_Err                  = @n_Err             OUTPUT'         
                 + ',@c_ErrMsg               = @c_ErrMsg          OUTPUT'          

      SET @c_SQLParms= N'@c_TaskWIPBatchNo      NVARCHAR(10)' 
                     + ',@c_Counttype_Code      NVARCHAR(30)' 
                     + ',@n_MaxCount            INT'
                     + ',@n_MaxAisleCount       INT'   
                     + ',@c_GroupKeyTableField  NVARCHAR(30)'    
                     + ',@c_ReleaseFilterCode   NVARCHAR(30)'  
                     + ',@n_ttltaskcnt          INT = 0       OUTPUT'
                     + ',@n_distinctskucnt      INT = 0       OUTPUT'
                     + ',@n_distinctloccnt      INT = 0       OUTPUT'                           
                     + ',@b_Success             INT           OUTPUT'
                     + ',@n_Err                 INT           OUTPUT'
                     + ',@c_ErrMsg              NVARCHAR(255) OUTPUT'  

      EXEC sp_ExecuteSQL  @c_SQL
                        , @c_SQLParms
                        , @c_TaskWIPBatchNo
                        , @c_Counttype_Code     
                        , @n_MaxCount           
                        , @n_MaxAisleCount      
                        , @c_GroupKeyTableField 
                        , @c_ReleaseFilterCode 
                        , @n_ttltaskcnt      OUTPUT
                        , @n_distinctskucnt  OUTPUT
                        , @n_distinctloccnt  OUTPUT
                        , @b_Success         OUTPUT             
                        , @n_Err             OUTPUT           
                        , @c_ErrMsg          OUTPUT           

      IF @b_Success = 0 
      BEGIN
         SET @n_Continue = 3
      END
      GOTO QUIT_SP
   END
   ------------------------------------------
   -- Call Custom SP to generate TMCC - END
   ------------------------------------------
  
   ------------------------------------------
   --  General Logic to generate TMCC - START
   ------------------------------------------

   SET @n_dot = CHARINDEX ('.', @c_GroupKeyTableField,1) 
   IF @n_dot > 0 
   BEGIN
      SET @c_TableName = SUBSTRING(@c_GroupKeyTableField,1,@n_dot-1)
      SET @c_ColName   = SUBSTRING(@c_GroupKeyTableField,@n_dot+1, LEN(@c_GroupKeyTableField) - @n_dot)

      IF @c_TableName NOT IN (@c_CountType, 'LOC') OR
         NOT EXISTS (SELECT 1                                                                                                                             
                     FROM   INFORMATION_SCHEMA.COLUMNS WITH (NOLOCK)                                                                                                                       
                     WHERE  TABLE_NAME = @c_TableName                                                                                                                     
                     AND    COLUMN_NAME = @c_ColName
      )
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 61030
         SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Invalid table column setup for task group. (isp_TMCCRelease_Wrapper)'
         GOTO QUIT_SP
      END
      
      SET @c_GroupKeySQL = N'SELECT @c_groupkey = ' + @c_GroupKeyTableField + ' FROM ' + @c_TableName + ' WITH (NOLOCK)'
                         + ' WHERE ' + @c_TableName + '.' + @c_TableName + '='
                         +  CASE WHEN @c_TableName = 'LOC' THEN '@c_Loc' 
                                 WHEN @c_TableName = 'SKU' THEN '@c_Sku AND ' + @c_TableName + '.Storerkey = @c_Storerkey'
                                 END 
      SET @c_GroupKeyParms= N'@c_GroupKey    NVARCHAR(10) OUTPUT'
                           + ',@c_Storerkey  NVARCHAR(15)' 
                           + ',@c_Sku        NVARCHAR(20)'  
                           + ',@c_Loc        NVARCHAR(10)'                                                                                       
   END
      
   SET @c_SQL  = N'SELECT tdw.Storerkey'
               + ',' + CASE WHEN @c_CountType = 'SKU' THEN ' tdw.Sku' ELSE '''''' END 
               + ', tdw.FromLoc' 
               + ', tdw.Sourcekey' 
               + ' FROM dbo.TaskDetail_WIP AS tdw WITH (NOLOCK)'  
               --+ ' LEFT OUTER JOIN dbo.TaskDetail AS td WITH (NOLOCK) ON td.TaskType = @c_TaskType'
               --+                                        ' AND td.[Status] = ''0'''  
               --+                                        ' AND td.SourceType = ''TMCCRLSE''' 
               + ' WHERE tdw.TaskWIPBatchNo = @c_TaskWIPBatchNo' 
               --+ ' AND td.TaskDetailKey IS NULL'                 
               --+  CASE WHEN @c_CountType = 'SKU' THEN ' AND tdw.Storerkey = td.Storerkey AND tdw.Sku = td.Sku' 
               --                                  ELSE ' AND tdw.Fromloc = td.FromLoc'  
               --                                  END
               + ' GROUP BY tdw.Storerkey'
               +            CASE WHEN @c_CountType = 'SKU' THEN ',tdw.Sku' ELSE '' END 
               +         ', tdw.FromLoc'                 
               +         ', tdw.Sourcekey' 
               + ' ORDER BY ' + CASE WHEN @c_CountType = 'SKU' THEN 'tdw.' + @c_CountType + ',' ELSE '' END
               +            ' tdw.FromLoc'
            
   SET @c_SQLParms= N'@c_TaskWIPBatchNo   NVARCHAR(10)'
                  + ',@c_TaskType         NVARCHAR(10)' 
   
   IF OBJECT_ID('tempdb..#TMCC_WIP','u') IS NOT NULL
   BEGIN
      DROP TABLE #TMCC_WIP;
   END
   
   CREATE TABLE #TMCC_WIP
   (  RowRef      INT            NOT NULL IDENTITY(1,1) PRIMARY KEY
   ,  Storerkey   NVARCHAR(15)   NOT NULL DEFAULT('')   
   ,  Sku         NVARCHAR(20)   NOT NULL DEFAULT('')
   ,  Loc         NVARCHAR(10)   NOT NULL DEFAULT('')
   ,  Sourcekey   NVARCHAR(10)   NOT NULL DEFAULT('')
   ,  GenCC       INT            NOT NULL DEFAULT(1)
   )
 
   INSERT INTO #TMCC_WIP (Storerkey, Sku, Loc, Sourcekey) 
   EXEC sp_ExecuteSQL  @c_SQL
                     , @c_SQLParms
                     , @c_TaskWIPBatchNo 
                     , @c_TaskType   
            
   SET @n_BatchLastRowID = 0                  
   SELECT TOP 1 @n_BatchLastRowID = tdw.RowID
   FROM dbo.TaskDetail_WIP AS tdw WITH (NOLOCK) 
   WHERE tdw.TaskWIPBatchNo = @c_TaskWIPBatchNo 
   ORDER BY tdw.RowID DESC
   
   IF EXISTS (SELECT 1 FROM #TMCC_WIP AS tw)
   BEGIN
       EXECUTE nspg_getkey          
        'CCkey'          
      , 10          
      , @c_Sourcekey OUTPUT          
      , @b_success   OUTPUT          
      , @n_err       OUTPUT    
      , @c_errmsg    OUTPUT   
   END
       
   SET @n_Cnt_CC = 1  
   SET @n_Cnt_Aisle = 1                
   SET @CUR_RLSE = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT Storerkey
         ,Sku
         ,Loc
         --,Sourcekey
   FROM #TMCC_WIP  
   
   OPEN @CUR_RLSE
   
   FETCH NEXT FROM @CUR_RLSE INTO @c_Storerkey, @c_Sku, @c_Loc--, @c_Sourcekey
   WHILE @@FETCH_STATUS <> -1 --AND @n_Cnt_CC <= @n_MaxCount 
   BEGIN  

      IF @n_MaxAisleCount > 0  
      BEGIN
         IF @n_Cnt_Aisle > @n_MaxAisleCount 
         BEGIN
            BREAK
         END
         
         IF @n_Cnt_Aisle = @n_MaxAisleCount AND
            EXISTS ( SELECT 1
                     FROM 
                        (
                           SELECT l2.LocAisle
                           FROM dbo.TaskDetail_WIP AS tdw WITH (NOLOCK)
                           JOIN dbo.LOC AS l2 WITH (NOLOCK) ON tdw.FromLoc = l2.Loc
                           WHERE tdw.TaskWIPBatchNo = @c_TaskWIPBatchNo 
                           AND tdw.RowID > @n_BatchLastRowID
                           UNION
                           SELECT l.LocAisle
                           FROM dbo.LOC AS l WITH (NOLOCK) 
                           WHERE l.loc = @c_Loc
                        ) t
                        HAVING COUNT(t.LocAisle) > @n_MaxAisleCount
                     )          
         BEGIN
            BREAK
         END
      END
      
      IF @n_Cnt_CC = @n_MaxCount 
      BEGIN
         IF @c_Counttype = 'LOC'
         BEGIN
            BREAK
         END
         
         IF @c_Counttype = 'SKU' AND
            NOT EXISTS (SELECT 1  
                        FROM dbo.TaskDetail_WIP AS tdw WITH (NOLOCK)
                        WHERE tdw.TaskWIPBatchNo = @c_TaskWIPBatchNo 
                        AND tdw.RowID > @n_BatchLastRowID
                        AND tdw.Storerkey = @c_Storerkey
                        AND tdw.Sku = @c_Sku 
                       )               
         BEGIN
            BREAK
         END 
      END

      SET @c_GroupKey = ''
      IF @c_GroupKeySQL <> ''
      BEGIN
         EXEC sp_ExecuteSQL @c_GroupKeySQL
                           ,@c_GroupKeyParms 
                           ,@c_GroupKey   OUTPUT
                           ,@c_Storerkey
                           ,@c_Sku
                           ,@c_Loc
                                    
      END  
         
      INSERT INTO TaskDetail_WIP (TaskWIPBatchNo, TaskType, Storerkey, Sku, FromLoc, Sourcekey, SourceType, [priority],PickMethod, ListKey, GroupKey)
      VALUES( @c_TaskWIPBatchNo, @c_TaskType, @c_Storerkey, @c_Sku, @c_Loc, @c_Sourcekey,'TMCCRLSE', '5', @c_CountType, CONVERT(NVARCHAR(10), @n_MaxCount), @c_GroupKey)
   
      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 61040
         SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Generate TaskDetail Work In Progress record fail. (isp_TMCCRelease_Wrapper) '
         GOTO QUIT_SP
      END
      
      SELECT @n_Cnt_CC = CASE WHEN @c_Counttype = 'SKU' THEN COUNT(DISTINCT tdw.Sku) ELSE COUNT(DISTINCT tdw.FromLoc) END
           , @n_Cnt_Aisle = COUNT(DISTINCT l2.LocAisle)
      FROM dbo.TaskDetail_WIP AS tdw WITH (NOLOCK)
      JOIN dbo.LOC AS l2 WITH (NOLOCK) ON tdw.FromLoc = l2.Loc
      WHERE tdw.TaskWIPBatchNo = @c_TaskWIPBatchNo 
      AND tdw.RowID > @n_BatchLastRowID

      NEXT_RLSE:
      FETCH NEXT FROM @CUR_RLSE INTO @c_Storerkey, @c_Sku, @c_Loc--, @c_Sourcekey
   END
   CLOSE @CUR_RLSE
   DEALLOCATE @CUR_RLSE
   
   ;WITH tdw ( RowID ) AS ( SELECT tdw.RowID FROM dbo.TaskDetail_WIP AS tdw WITH (NOLOCK) WHERE tdw.TaskWIPBatchNo = @c_TaskWIPBatchNo
                            AND tdw.RowID <= @n_BatchLastRowID )
            
   DELETE tdw_d FROM TaskDetail_WIP tdw_d
   JOIN tdw ON  tdw.RowID = tdw_d.RowID
   
   IF @@ERROR <> 0
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 61050
      SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Delete TaskDetail_WIP record fail. (isp_TMCCRelease_Wrapper) '
      GOTO QUIT_SP
   END
   
   SELECT @n_ttltaskcnt = COUNT(1)
      , @n_distinctskucnt = CASE WHEN @c_CountType = 'SKU' THEN COUNT(DISTINCT tdw.Sku) ELSE 0 END
      , @n_distinctloccnt = COUNT(DISTINCT tdw.Fromloc)      
   FROM dbo.TaskDetail_WIP AS tdw WITH (NOLOCK)
   WHERE tdw.TaskWIPBatchNo = @c_TaskWIPBatchNo 
   ------------------------------------------
   --  General Logic to generate TMCC - END
   ------------------------------------------
  
   SET @b_Success = 1
QUIT_SP:
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_TMCCRelease_Wrapper'
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO
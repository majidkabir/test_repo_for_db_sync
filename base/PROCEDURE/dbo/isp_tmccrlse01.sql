SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_TMCCRLSE01                                          */
/* Creation Date: 2021-04-16                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-16623 - [CN] Nike Phoenix Add New Count Type in         */
/*          Release-Cycle-Count                                         */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2021-04-16  Wan      1.0   Created                                   */
/************************************************************************/
CREATE PROC [dbo].[isp_TMCCRLSE01]
           @c_TaskWIPBatchNo     NVARCHAR(10) = '' 
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
         
         , @n_dot                      INT         = 0
         , @c_TableName                NVARCHAR(50)= ''
         , @c_ColName                  NVARCHAR(50)= '' 
                 
         , @n_BatchLastRowID           BIGINT      = 0
         , @c_Storerkey                NVARCHAR(15)= '' 
         , @c_Sku                      NVARCHAR(20)= '' 
         , @c_Loc                      NVARCHAR(10)= ''          
         , @c_Counttype                NVARCHAR(60)= ''
         , @c_TaskType                 NVARCHAR(60)= 'CC'
         , @c_Sourcekey                NVARCHAR(10)= ''
         , @c_GroupKey                 NVARCHAR(10)= ''
         
         , @c_LocAisle                 NVARCHAR(10)= ''

         , @n_RowRef                   INT         = 0
         , @n_Cnt_Aisle                INT         = 0
         
         , @n_MaxCount_Remain          INT         = 0
         , @n_Cnt_NeedPerAisle         INT         = 0
         
         , @n_Status                   INT         = 0
         , @b_Nextloc                  INT         = 1
         
         , @CUR_SL                     CURSOR
         , @CUR_AISLE                  CURSOR
         
   DECLARE @t_LocAisle TABLE
         ( RowRef    INT            NOT NULL IDENTITY(1,1)
         , LocAisle  NVARCHAR(10)   NOT NULL DEFAULT('')
         )


   SET @c_GroupKeyTableField = ISNULL(@c_GroupKeyTableField,'')  
   SET @c_ReleaseFilterCode  = ISNULL(@c_ReleaseFilterCode,'')  
           
   IF @n_MaxAisleCount <= 0 
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 71010
      SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Invalid MaxAisleCount to generate Random CC By MaxAisleCount. (isp_TMCCRLSE01)'
      GOTO QUIT_SP
   END    
   
   SELECT @c_Counttype = ISNULL(CL.UDF01,'')
         ,@c_TaskType  = ISNULL(CL.UDF02,'')
   FROM CODELKUP CL WITH (NOLOCK)
   WHERE CL.LISTNAME = 'PIType'
   AND CL.Code = @c_Counttype_Code

   IF @c_TaskType = '' SET @c_TaskType = 'CC'
     
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
         SET @n_Err = 71020
         SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Invalid table column setup for task group. (isp_TMCCRLSE01)'
         GOTO QUIT_SP
      END
      
      SET @c_GroupKeySQL = N'SELECT @c_groupkey = ' + @c_GroupKeyTableField + ' FROM ' + @c_TableName + ' WITH (NOLOCK)'
                         + ' WHERE ' + @c_TableName + '.' + @c_TableName + '='
                         +  CASE WHEN @c_TableName = 'LOC' THEN '@c_Loc' 
                                 WHEN @c_TableName = 'SKU' THEN '@c_Sku AND ' + @c_TableName + '.Storerkey = @c_Storerkey'
                                 END 
      SET @c_GroupKeyParms= N'@c_GroupKey    NVARCHAR(10) OUTPUT'
                          + ',@c_Storerkey   NVARCHAR(15)' 
                          + ',@c_Sku         NVARCHAR(20)'  
                          + ',@c_Loc         NVARCHAR(10)'  
   END
      
   SET @c_SQL  = N'SELECT tdw.Storerkey'
               + ', Sku =' + CASE WHEN @c_CountType = 'SKU' THEN ' tdw.Sku' ELSE '''''' END 
               + ', tdw.FromLoc' 
               + ' FROM dbo.TaskDetail_WIP AS tdw WITH (NOLOCK)'  
               + ' WHERE tdw.TaskWIPBatchNo = @c_TaskWIPBatchNo' 
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
   ,  LocAisle    NVARCHAR(10)   NOT NULL DEFAULT('')
   ,  GroupKey    NVARCHAR(10)   NOT NULL DEFAULT('')
   ,  [Status]    INT            NOT NULL DEFAULT(0)
   )

   IF OBJECT_ID('tempdb..#RecPerAisle','u') IS NOT NULL
   BEGIN
      DROP TABLE #RecPerAisle;
   END
   
   CREATE TABLE #RecPerAisle
   (  RowRef      INT            NOT NULL IDENTITY(1,1) PRIMARY KEY
   ,  Storerkey   NVARCHAR(15)   NOT NULL DEFAULT('')   
   ,  Sku         NVARCHAR(20)   NOT NULL DEFAULT('')
   ,  Loc         NVARCHAR(10)   NOT NULL DEFAULT('')
   ,  LocAisle    NVARCHAR(10)   NOT NULL DEFAULT('')
   ,  CntPerAisle INT            NOT NULL DEFAULT(0)
   ,  [Status]    INT            NOT NULL DEFAULT(0)
   )


   INSERT INTO #TMCC_WIP (Storerkey, Sku, Loc) 
   EXEC sp_ExecuteSQL  @c_SQL
                     , @c_SQLParms
                     , @c_TaskWIPBatchNo 
                     , @c_TaskType   
         

   IF NOT EXISTS (SELECT 1 FROM #TMCC_WIP)
   BEGIN
      SET @b_Success = 1
      GOTO QUIT_SP
   END
   
   ------------------------------------------------------
   --Get Valid SxL Record for release (START)
   ------------------------------------------------------
   SET @CUR_SL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT RowRef
         ,Storerkey
         ,Sku
         ,Loc
   FROM #TMCC_WIP 
   ORDER BY RowRef 
   
   OPEN @CUR_SL
   
   FETCH NEXT FROM @CUR_SL INTO @n_RowRef, @c_Storerkey, @c_Sku, @c_Loc
   WHILE @@FETCH_STATUS <> -1
   BEGIN 
      SET @n_Status = 1 
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
      
      UPDATE tw
         SET [Status] = @n_Status
            ,GroupKey = @c_GroupKey
      FROM #TMCC_WIP tw
      WHERE tw.RowRef = @n_RowRef
       
      FETCH NEXT FROM @CUR_SL INTO @n_RowRef, @c_Storerkey, @c_Sku, @c_Loc 
   END
   CLOSE @CUR_SL
   DEALLOCATE @CUR_SL
   
  
   ------------------------------------------------------
   --Get Valid SxL Record for release (END)
   ------------------------------------------------------
   UPDATE tw
      SET LocAisle = l.LocAisle
   FROM #TMCC_WIP tw
   JOIN  dbo.LOC AS l WITH (NOLOCK) ON tw.Loc = l.Loc

   IF @c_Counttype = 'LOC'
   BEGIN
      INSERT INTO #RecPerAisle
            ( 
             Storerkey  
            ,Sku  
            ,LOC
            ,LocAisle
            )
      SELECT Storerkey = ''
            ,Sku = ''
            ,tw.LOC
            ,tw.LocAisle
      FROM #TMCC_WIP tw
      WHERE tw.[Status] = 1   
      GROUP BY tw.Loc
            ,  tw.LocAisle
   END
   ELSE
   BEGIN
      INSERT INTO #RecPerAisle
            ( 
             Storerkey  
            ,Sku  
            ,Loc
            ,LocAisle
            )
      SELECT tw.Storerkey  
            ,tw.Sku  
            ,''  
            ,tw.LocAisle
      FROM #TMCC_WIP tw
      WHERE tw.[Status] = 1
      GROUP BY tw.Storerkey
            ,  tw.Sku
            ,  tw.LocAisle
   END

   ;WITH upd (LocAisle, CntPerAisle) AS (SELECT r.LocAisle
                                             ,  COUNT( DISTINCT CASE WHEN @c_Counttype = 'LOC' THEN r.Loc ELSE r.Storerkey + r.Sku END )
                                         FROM #RecPerAisle r 
                                         GROUP BY r.LocAisle
                                         )
   UPDATE r1
   SET CntPerAisle = upd.CntPerAisle
   FROM #RecPerAisle r1
   JOIN upd ON upd.LocAisle = r1.LocAisle

   ------------------------------------------------------
   --Get Distinct Loc Aisle to Meet MaxAisleCount - START
   ------------------------------------------------------
   INSERT INTO @t_LocAisle
   (
      LocAisle
   )
   SELECT TOP (@n_MaxAisleCount)
         r.LocAisle
   FROM #RecPerAisle AS r
   WHERE r.[Status] = 0
   AND   r.CntPerAisle >= @n_Cnt_NeedPerAisle
   GROUP BY r.LocAisle
   ORDER BY MAX(r.CntPerAisle) DESC, NEWID()
      
   SELECT TOP 1 @n_Cnt_Aisle = tla.RowRef FROM @t_LocAisle AS tla ORDER BY tla.RowRef DESC
   
   IF @n_Cnt_Aisle < @n_MaxAisleCount
   BEGIN
      INSERT INTO @t_LocAisle
      (
         LocAisle
      )
      SELECT TOP (@n_MaxAisleCount - @n_Cnt_Aisle)
            r.LocAisle
      FROM #RecPerAisle AS r
      WHERE r.[Status] = 0
      AND   r.CntPerAisle < @n_Cnt_NeedPerAisle
      GROUP BY r.LocAisle
      ORDER BY MAX(r.CntPerAisle) DESC, NEWID()
   END
   ------------------------------------------------------
   --Get Distinct Loc Aisle to Meet MaxAisleCount - END
   ------------------------------------------------------
   
   ----------------------------------------------------------
   --Get Unique Sku/Loc Per Aisle Until Meet MaxCount - START
   ----------------------------------------------------------
   SET @n_MaxCount_Remain = @n_MaxCount
   GET_AISLEREC:
   SET @n_Cnt_NeedPerAisle = CASE WHEN @n_MaxCount_Remain > @n_MaxAisleCount THEN @n_MaxCount_Remain / @n_MaxAisleCount ELSE 1 END
       
   SET @CUR_AISLE = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT tla.LocAisle
   FROM @t_LocAisle AS tla
   ORDER BY NEWID()
   
   OPEN @CUR_AISLE
   
   FETCH NEXT FROM @CUR_AISLE INTO @c_LocAisle
   
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      ;WITH CN (RowRef) AS (  SELECT TOP (@n_Cnt_NeedPerAisle)
                                 r1.RowRef
                              FROM #RecPerAisle r1
                              WHERE r1.LocAisle = @c_LocAisle
                              AND r1.[Status] = 0
                              AND NOT EXISTS (  SELECT 1 
                                                FROM #RecPerAisle r2
                                                WHERE r2.[Status] = 1
                                                AND r2.Storerkey = r1.Storerkey
                                                AND r2.Sku = r1.Sku
                                                AND r2.Loc = r1.Loc
                                             )
                              ORDER BY NEWID ())
      UPDATE r
         SET r.[Status] = 1
      FROM #RecPerAisle r
      JOIN CN ON  r.RowRef = CN.RowRef
      WHERE r.[Status] = 0
      
      IF @@ROWCOUNT = 0
      BEGIN
         ;WITH CN (RowRef) AS (  SELECT TOP (@n_Cnt_NeedPerAisle)
                                 r1.RowRef
                              FROM #RecPerAisle r1
                              WHERE r1.LocAisle = @c_LocAisle
                              AND r1.[Status] = 0
                              ORDER BY NEWID ())
         UPDATE r
            SET r.[Status] = 1
         FROM #RecPerAisle r
         JOIN CN ON  r.RowRef = CN.RowRef
         WHERE r.[Status] = 0
      END 
      
      SELECT @n_MaxCount_Remain = @n_MaxCount - COUNT(1)
      FROM #RecPerAisle r
      WHERE r.[Status] = 1
 
      IF @n_MaxCount_Remain <= 0 
      BEGIN
         BREAK
      END
   
      FETCH NEXT FROM @CUR_AISLE INTO @c_LocAisle
   END
   CLOSE @CUR_AISLE
   DEALLOCATE @CUR_AISLE

   IF @n_MaxCount_Remain > 0 AND EXISTS (SELECT 1 FROM #RecPerAisle r WHERE r.[Status] = 0)
   BEGIN
      GOTO GET_AISLEREC
   END
   ----------------------------------------------------------
   --Get Unique Sku/Loc Per Aisle Until Meet MaxCount - END
   ----------------------------------------------------------
   
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

   IF @c_Counttype = 'LOC'
   BEGIN
      INSERT INTO TaskDetail_WIP (TaskWIPBatchNo, TaskType, Storerkey, Sku, FromLoc, Sourcekey, SourceType, [priority], PickMethod, ListKey, GroupKey)
      SELECT @c_TaskWIPBatchNo, @c_TaskType, tw.Storerkey, tw.Sku, tw.Loc, @c_Sourcekey,'TMCCRLSE', '5', @c_CountType, CONVERT(NVARCHAR(10), @n_MaxCount), tw.GroupKey
      FROM #RecPerAisle r
      JOIN #TMCC_WIP tw ON  r.Loc = tw.Loc
                        AND r.LocAisle = tw.LocAisle
      WHERE r.[Status] = 1
      ORDER BY tw.Loc
   END 
   ELSE
   BEGIN
      INSERT INTO TaskDetail_WIP (TaskWIPBatchNo, TaskType, Storerkey, Sku, FromLoc, Sourcekey, SourceType, [priority], PickMethod, ListKey, GroupKey)
      SELECT @c_TaskWIPBatchNo, @c_TaskType, tw.Storerkey, tw.Sku, tw.Loc, @c_Sourcekey,'TMCCRLSE', '5', @c_CountType, CONVERT(NVARCHAR(10), @n_MaxCount), tw.GroupKey
      FROM #RecPerAisle r
      JOIN #TMCC_WIP tw ON  r.Storerkey = tw.Storerkey
                        AND r.Sku = tw.Sku
                        AND r.LocAisle = tw.LocAisle
      WHERE r.[Status] = 1 
      AND  tw.[Status] = 1 
      ORDER BY tw.Storerkey
            ,  tw.Sku      
   END  
      
   IF @@ERROR <> 0
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 71040
      SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Generate TaskDetail Work In Progress record fail. (isp_TMCCRLSE01) '
      GOTO QUIT_SP
   END
   
   DELETE tdw
   FROM dbo.TaskDetail_WIP AS tdw 
   WHERE tdw.TaskWIPBatchNo = @c_TaskWIPBatchNo 
   AND tdw.RowID <= @n_BatchLastRowID
   
   IF @@ERROR <> 0
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 71050
      SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Delete TaskDetail_WIP record fail. (isp_TMCCRLSE01) '
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_TMCCRLSE01'
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
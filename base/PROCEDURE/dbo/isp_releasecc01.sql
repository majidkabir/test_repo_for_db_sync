SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_ReleaseCC01                                         */
/* Creation Date: 18-APR-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-1617 - CN&SG Logitech RDT TM Cycle count with ABC       */
/*        :                                                             */
/* Called By: isp_ReleaseCCTask_Wrapper                                 */
/*          :                                                           */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 27-Nov-2017 Wan01    1.1   fix infinite loop initialize              */
/************************************************************************/
CREATE PROC [dbo].[isp_ReleaseCC01]
           @c_Storerkey          NVARCHAR(30)
         , @b_Success            INT            OUTPUT
         , @n_Err                INT            OUTPUT
         , @c_ErrMsg             NVARCHAR(255)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT
         
         , @c_Facility        NVARCHAR(5)
         , @c_Facility_Prev   NVARCHAR(5)
         , @c_ABC             NVARCHAR(5)
         , @c_TaskDetailKey   NVARCHAR(10)
         , @c_CCKey           NVARCHAR(10)
         , @c_Sku             NVARCHAR(20)
         , @c_Sku_Prev        NVARCHAR(20)
         , @c_Loc             NVARCHAR(10)
         , @c_Id              NVARCHAR(20)
         , @c_LogicalFromLoc  NVARCHAR(10)
         , @c_Priority        NVARCHAR(10)
         , @dt_TaskDate       DATETIME
         , @n_SystemQty       INT

         , @n_NoOfSku         INT 
         , @n_SkuCnt          INT
         , @n_RecCnt          INT
         , @n_CCBreak1        INT
         , @n_CCBreak1_Prev   INT

         , @b_SendEmailAlert  INT  
         , @c_Recipients      NVARCHAR(MAX)
         , @c_Subject         NVARCHAR(MAX)
         , @c_Body            NVARCHAR(MAX) 

         , @b_NextFacility    INT


   CREATE TABLE #TMP_TASKALERT  
   (  TASKDETAILKEY      NVARCHAR(10)   
   ,  TASKTYPE           NVARCHAR(10)   
   ,  STORERKEY          NVARCHAR(15)  
   ,  SKU                NVARCHAR(20)  
   ,  QTY                INT  
   ,  FROMLOC            NVARCHAR(10)  
   ,  PRIORITY           NVARCHAR(10)  
   ,  TASKDATE           DATETIME
   )   

   CREATE TABLE #TMP_TASK  
   (  TASKDETAILKEY      NVARCHAR(10) NOT NULL PRIMARY KEY  
   ,  Facility           NVARCHAR(5)   
   ,  Storerkey          NVARCHAR(10)  
   ,  SKU                NVARCHAR(20)  
   ,  ABC                NVARCHAR(5)  
   )   

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''
   SET @b_SendEmailAlert = 0
   SET @b_NextFacility = 0
   SET @c_Facility_Prev= ''

   WHILE @@TRANCOUNT > 0 
   BEGIN
      COMMIT TRAN
   END
   
   IF NOT EXISTS (   SELECT 1
                     FROM STORER WITH (NOLOCK)
                     WHERE Storerkey = @c_Storerkey
                     AND ABCLogic = 'LOGITECH'
                 )
   BEGIN
      GOTO QUIT_SP
   END

   SET @c_Recipients = ''
   SELECT TOP 1 
            @c_Recipients = CASE WHEN ISNULL(UDF01,'') <> '' THEN RTRIM(UDF01) + ';' ELSE '' END 
                        + CASE WHEN ISNULL(UDF02,'') <> '' THEN RTRIM(UDF02) + ';' ELSE '' END  
                        + CASE WHEN ISNULL(UDF03,'') <> '' THEN RTRIM(UDF03) + ';' ELSE '' END  
                        + CASE WHEN ISNULL(UDF04,'') <> '' THEN RTRIM(UDF04) + ';' ELSE '' END 
                        + CASE WHEN ISNULL(UDF05,'') <> '' THEN RTRIM(UDF05) + ';' ELSE '' END 
   FROM CODELKUP WITH (NOLOCK)
   WHERE ListName = 'EmailAlert'
   AND   Code = 'isp_ReleaseCC01'
   AND   ( StorerKey = @c_Storerkey OR Storerkey = '' )
   ORDER BY StorerKey DESC

   IF ISNULL(@c_Recipients, '') <> ''
   BEGIN
      SET @b_SendEmailAlert = 1
   END

   SET @n_CCBreak1_Prev = 0
   SET @c_Facility_Prev = ''

   DECLARE CUR_TASK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT   LOC.Facility 
         ,  SKU.ABC
         ,  SKU.Sku
         ,  LOC.Loc
         ,  LLI.Id
         ,  LOC.LogicalLocation
         ,  SystemQty = SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked)
         --,  CCBreak1 = DENSE_RANK() OVER (ORDER BY 
         --                                  LOC.Facility
         --                                 ,SKU.ABC
         --                                 ) 
   FROM SKU        SKU WITH (NOLOCK)  
   JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (SKU.Storerkey = LLI.Storerkey)
                                     AND(SKU.Sku = LLI.Sku)
   JOIN LOC        LOC WITH (NOLOCK) ON (LLI.Loc = LOC.Loc)
   JOIN LOT        LOT WITH (NOLOCK) ON (LLI.Lot = LOT.LOT)
   JOIN ID         ID  WITH (NOLOCK) ON (LLI.ID  = ID.ID) 
   WHERE SKU.Storerkey = @c_Storerkey
   AND   SKU.CycleCountFrequency <= DATEDIFF(d, SKU.LastCycleCount, GETDATE())
   AND   LOC.Status = 'OK'
   AND   LOC.LocationFlag NOT IN ('HOLD', 'DAMAGE')
   AND   LOT.Status = 'OK'
   AND   ID.Status = 'OK'
   AND   LLI.Qty > 0 
   AND   LLI.QtyPicked = 0
   GROUP BY LOC.Facility 
         ,  SKU.ABC
         ,  SKU.Sku
         ,  LOC.Loc
         ,  LLI.Id
         ,  LOC.LogicalLocation
         ,  LOC.CCLogicalLoc
   ORDER BY LOC.Facility 
         ,  LOC.CCLogicalLoc
         ,  SKU.ABC
         ,  SKU.Sku
         ,  LOC.Loc
   
   OPEN CUR_TASK
   
   FETCH NEXT FROM CUR_TASK INTO @c_Facility
                              ,  @c_ABC
                              ,  @c_Sku
                              ,  @c_Loc
                              ,  @c_Id
                              ,  @c_LogicalFromLoc
                              ,  @n_SystemQty
                              --,  @n_CCBreak1

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @b_NextFacility = 0
      IF @c_Facility_Prev <> @c_Facility
      BEGIN
         --SET @b_NextFacility = 1        --(Wan01)

         IF @c_Facility_Prev <> ''
         BEGIN
            SET @b_NextFacility = 1       --(Wan01)
            GOTO GEN_CCKey

            RETURN_GEN_CCKey:
         END

         TRUNCATE TABLE #TMP_TASK

         WHILE @@TRANCOUNT > 0 
         BEGIN
            COMMIT TRAN
         END

         SET @n_NoOfSku = 0
         SET @n_RecCnt  = 0
         SELECT   @n_RecCnt = 1
               ,  @n_NoOfSku = CASE WHEN ISNULL(RTRIM(FACILITY.UserDefine05),'') = '' 
                                    THEN '0' 
                                    ELSE FACILITY.UserDefine05 END
         FROM FACILITY WITH (NOLOCK)
         WHERE Facility = @c_Facility
         AND ISNUMERIC(FACILITY.UserDefine05) = 1

         IF @n_RecCnt = 0
         BEGIN
            SET @n_Continue = 3  
            SET @n_err=80010
            SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_err) + ': No Of Sku is setup as non numeric. (isp_ReleaseCC01).'  
            GOTO QUIT_SP         
         END

         IF @n_NoOfSku = 0 
         BEGIN
            SET @n_Continue = 3  
            SET @n_err=80020
            SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_err) + ': No Of Sku Per CC not setup. (isp_ReleaseCC01).'  
            GOTO QUIT_SP         
         END

         IF @n_NoOfSku > 10 
         BEGIN
            SET @n_Continue = 3  
            SET @n_err=80030
            SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_err) + ': No Of Sku Per CC > 10. (isp_ReleaseCC01).'  
            GOTO QUIT_SP         
         END
      END

      SET @n_RecCnt = 0
      SET @c_TaskDetailKey = ''
      SET @c_Priority = '9'
      SET @dt_TaskDate= GETDATE()
      
      SELECT TOP 1 
             @n_RecCnt = 1
            ,@c_TaskDetailKey = TaskDetailKey
            ,@c_Priority = Priority
      FROM TASKDETAIL WITH (NOLOCK)
      WHERE TaskType   = 'CC'
      AND   SourceType = 'isp_ReleaseCC01'
      AND   Storerkey  = @c_Storerkey
      AND   Sku        = @c_Sku
      AND   FromLoc    = @c_Loc
      AND   FromID     = @c_Id
      AND   Status IN ('0', '3')

      IF @n_RecCnt = 1
      BEGIN
         IF @c_Priority <= 1
         BEGIN
            GOTO NEXT_REC
         END

         SET @c_Priority =  CONVERT(NVARCHAR(10), CONVERT(INT, @c_Priority) - 1)
         UPDATE TASKDETAIL WITH (ROWLOCK)
         SET  Priority = @c_Priority
            , EditWho  = SUSER_NAME()
            , EditDate = @dt_TaskDate
         WHERE TaskDetailKey = @c_TaskDetailKey

         IF @@ERROR <> 0
         BEGIN  
            SET @n_Continue = 3  
            SET @n_err=80050 
            SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_err) + ': Update TASKDETAIL Table Fail. (isp_ReleaseCC01).'  
            GOTO QUIT_SP
         END  
      END 
      ELSE
      BEGIN      
         SET @b_Success = 1  
     
         EXECUTE nspg_getkey  
         'TaskDetailKey'  
         , 10  
         , @c_TaskDetailKey   OUTPUT  
         , @b_Success         OUTPUT  
         , @n_Err             OUTPUT  
         , @c_ErrMsg          OUTPUT  
     
         IF @b_Success <> 1  
         BEGIN  
            SET @n_Continue = 3  
            SET @n_err=80060 
            SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_err) + ': Get CCDetail Key Fail. (isp_ReleaseCC01).'  
            GOTO QUIT_SP
         END  

         INSERT INTO TASKDETAIL
         (  TaskDetailKey
         ,  TaskType
         ,  Storerkey
         ,  Sku
         ,  FromLoc
         ,  FromID
         ,  LogicalFromLoc
         ,  Lot
         ,  ToLoc
         ,  LogicalToLoc
         ,  ToID
         ,  UOM  
         ,  UOMQty
         ,  Qty 
         ,  SystemQty
         ,  SourceKey
         ,  SourceType
         ,  PickMethod
         ,  Priority
         ,  Status
         ,  StartTime
         ,  EndTime
         ,  AddDate
         )
         VALUES
         (  @c_TaskDetailKey
         ,  'CC'
         ,  @c_Storerkey
         ,  @c_Sku
         ,  @c_Loc
         ,  @c_Id -- FromID
         ,  @c_LogicalFromLoc
         ,  '' -- Lot
         ,  '' -- ToLoc
         ,  '' -- LogicalToLoc
         ,  '' -- ToID
         ,  '' -- UOM  
         ,  0  -- UOMQty  
         ,  0  -- Qty
         ,  0
         ,  '' -- @c_CCKey
         , 'isp_ReleaseCC01'
         , 'SKU'
         , @c_Priority
         , '0' -- Status
         , @dt_TaskDate
         , @dt_TaskDate
         , @dt_TaskDate
         )

         IF @@ERROR <> 0
         BEGIN  
            SET @n_Continue = 3  
            SET @n_err=80070 
            SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_err) + ': Insert Into TASKDETAIL Table Fail. (isp_ReleaseCC01).'  
            GOTO QUIT_SP
         END 

         INSERT INTO #TMP_TASK
         (  TaskDetailKey
         ,  Facility
         ,  Storerkey
         ,  Sku
         ,  ABC
         )
         VALUES
         (  @c_TaskDetailKey
         ,  @c_Facility
         ,  @c_Storerkey
         ,  @c_Sku
         ,  @c_ABC
         )
      END

      IF @b_SendEmailAlert = 1
      BEGIN
         INSERT INTO #TMP_TASKALERT  
            (  TaskDetailKey
            ,  TaskType
            ,  Storerkey
            ,  Sku
            ,  Qty
            ,  FromLoc
            ,  Priority
            ,  TaskDate)
         VALUES 
            (  @c_TaskDetailKey
            ,  'CC'
            ,  @c_Storerkey
            ,  @c_Sku
            ,  @n_SystemQty
            ,  @c_Loc
            ,  @c_Priority
            ,  @dt_TaskDate)

         IF @@ERROR <> 0
         BEGIN  
            SET @n_Continue = 3  
            SET @n_err=80080 
            SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_err) + ': Insert Into TASKDETAIL Table Fail. (isp_ReleaseCC01).'  
            GOTO QUIT_SP
         END            
      END

      NEXT_REC:

      SET @c_Facility_Prev = @c_Facility

      FETCH NEXT FROM CUR_TASK INTO @c_Facility
                                 ,  @c_ABC
                                 ,  @c_Sku
                                 ,  @c_Loc
                                 ,  @c_Id
                                 ,  @c_LogicalFromLoc
                                 ,  @n_SystemQty
                                 --,  @n_CCBreak1
   END
   CLOSE CUR_TASK
   DEALLOCATE CUR_TASK 

   GEN_CCKey:

   SET @n_SkuCnt = 0
   SET @n_CCBreak1_Prev = 0
   SET @c_Sku_Prev = ''

   DECLARE @cur_TT CURSOR
   SET @cur_TT = CURSOR FAST_FORWARD READ_ONLY FOR     
   SELECT   TMP.TaskDetailKey 
         ,  TMP.Sku
         ,  CCBreak1 = DENSE_RANK() OVER (ORDER BY TMP.Facility
                                                  ,TMP.ABC
                                          ) 
   FROM #TMP_TASK TMP
   ORDER BY TMP.Facility
         ,  TMP.ABC
         ,  TMP.Sku
      
   OPEN @cur_TT
   FETCH NEXT FROM @cur_TT INTO @c_TaskDetailKey
                              , @c_Sku
                              , @n_CCBreak1 
   WHILE @@FETCH_STATUS = 0
   BEGIN
      IF (@n_CCBreak1_Prev <> @n_CCBreak1) OR 
         (@n_SkuCnt = @n_NoOfSku)
      BEGIN
         BEGIN TRAN
         SET @c_CCKey   = ''
         SET @b_Success = 1  
         EXECUTE nspg_getkey  
            'CCKey'  
            , 10  
            , @c_CCKey           OUTPUT  
            , @b_Success         OUTPUT  
            , @n_Err             OUTPUT  
            , @c_ErrMsg          OUTPUT  
        
         IF @b_Success <> 1  
         BEGIN  
            SET @n_Continue = 3  
            SET @n_err=80040 
            SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_err) + ': Get CCDetail Key Fail. (isp_ReleaseCC01).'  
            GOTO QUIT_SP
         END 
         SET @n_SkuCnt = 0
      END 

      UPDATE TASKDETAIL WITH (ROWLOCK)
         SET TASKDETAIL.SourceKey = @c_CCKey
            ,TASKDETAIL.TrafficCop = NULL
      WHERE TASKDETAIL.TaskDetailKey = @c_TaskDetailKey

      IF @c_Sku_Prev <> '' AND @c_Sku_Prev <> @c_Sku
      BEGIN
         SET @n_SkuCnt = @n_SkuCnt + 1  
      END

      SET @c_Sku_Prev = @c_Sku
      SET @n_CCBreak1_Prev = @n_CCBreak1

      FETCH NEXT FROM @cur_TT INTO @c_TaskDetailKey
                                 , @c_Sku
                                 , @n_CCBreak1

   END

   IF @b_NextFacility = 1
   BEGIN
      SET @b_NextFacility = 0       --(Wan01)
      GOTO RETURN_GEN_CCKey
   END

   WHILE @@TRANCOUNT > 0 
   BEGIN
      COMMIT TRAN
   END

   IF @b_SendEmailAlert = 1 
   BEGIN
      IF NOT EXISTS (SELECT 1
                     FROM #TMP_TASKALERT) 
      BEGIN
         GOTO QUIT_SP
      END

      SET @c_Body = '<table border="1" cellspacing="0" cellpadding="5">'   
            + '<tr bgcolor=silver><th>TASKDETAILKEY</th>'
            +                    '<th>TASK TYPE</th>'
            +                    '<th>STORER</th>'  
            +                    '<th>SKU</th>'
            +                    '<th>LOCATION</th>'
            +                    '<th>QTY</th>'
            +                    '<th>PRIORITY</th>'
            +                    '<th>TASK PROCESS DATE</th></tr>'+ CHAR(13)  
            + CAST ( ( SELECT  td = ISNULL(RTRIM(TaskdetailKey),'')
                           , ''  
                           , td = ISNULL(RTRIM(TaskType),'')
                           , ''    
                           , td = ISNULL(RTRIM(Storerkey),'')
                           , ''   
                           , td = ISNULL(RTRIM(SKU) ,'')
                           , ''   
                           , td = ISNULL(RTRIM(FromLoc) ,'')
                           , '' 
                           , td = CAST(QTY AS NVARCHAR(5))
                           , ''                               
                           , td = ISNULL(RTRIM(Priority),'')
                           , ''   
                           , td = ISNULL(CONVERT(VARCHAR(30), TaskDate, 120),'')  
                     FROM #TMP_TASKALERT 
                     FOR XML PATH('tr'), TYPE     
            ) AS NVARCHAR(MAX) ) + '</table>' ; 

      EXEC msdb.dbo.sp_send_dbmail
         @recipients       = @c_Recipients 
         ,  @copy_recipients = NULL 
         ,  @subject         = @c_Subject 
         ,  @body            = @c_Body 
         ,  @body_format     = 'HTML' ;

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue=3
         SET @n_err = 80090
         SET @c_Errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+ ':Error executing sp_send_dbmail. (isp_ReleaseCC01)'
                        + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
         GOTO QUIT_SP
      END
   END
QUIT_SP:

   IF CURSOR_STATUS( 'LOCAL', 'CUR_TASK') in (0 , 1)  
   BEGIN
      CLOSE CUR_TASK
      DEALLOCATE CUR_TASK
   END

   IF OBJECT_ID('tempdb..##TMP_TASKALERT','u') IS NOT NULL
   BEGIN
      DROP TABLE #TMP_TASKALERT;
   END

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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_ReleaseCC01'
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END

   WHILE @@TRANCOUNT < @n_StartTCnt 
   BEGIN
      BEGIN TRAN
   END
END -- procedure

GO
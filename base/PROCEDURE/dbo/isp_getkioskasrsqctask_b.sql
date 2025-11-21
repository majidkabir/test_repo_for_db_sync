SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_GetKIOSKASRSQCTask_b                           */
/* Creation Date: 2015-01-20                                            */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: SOS#315474 - Project Merlion - Exceed GTM Kiosk Module      */
/*                                                                      */
/* Called By: r_dw_kiosk_asrsqc_b_form                                  */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 12-JAN-2016  Wan02   1.1   Fixed. Pallet Qty = Qty - QtyPicked       */
/* 15-APR-2016  Leong   1.2   IN00020776 - include additional column.   */
/************************************************************************/

CREATE PROC [dbo].[isp_GetKIOSKASRSQCTask_b]
         (  @c_JobKey         NVARCHAR(10)
         ,  @c_TaskdetailKey  NVARCHAR(10)
         ,  @c_ID             NVARCHAR(18)= ''
         )
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF


   DECLARE @n_DefaultQty    INT
         , @n_ShowUOMEA     INT

         , @c_JobStatus     NVARCHAR(10)
         , @c_Storerkey     NVARCHAR(15)

   CREATE TABLE #TMP_QC
         (  RowNo          INT      IDENTITY(1,1)
         ,  JobKey         NVARCHAR(10)   NULL  DEFAULT(' ')
         ,  Taskdetailkey  NVARCHAR(10)   NULL  DEFAULT(' ')
         ,  Storerkey      NVARCHAR(15)   NULL  DEFAULT(' ')
         ,  SKu            NVARCHAR(20)   NULL  DEFAULT(' ')
         ,  Descr          NVARCHAR(60)   NULL  DEFAULT(' ')
         ,  FromID         NVARCHAR(18)   NULL  DEFAULT(' ')
         ,  Instruction    NVARCHAR(255)  NULL  DEFAULT(' ')
         ,  StatusMsg      NVARCHAR(255)  NULL  DEFAULT(' ')
         ,  QtyInCS        INT            NULL  DEFAULT(0)
         ,  QtyInEA        INT            NULL  DEFAULT(0)
         ,  PackUOM1       NVARCHAR(10)   NULL  DEFAULT(' ')
         ,  PackUOM3       NVARCHAR(10)   NULL  DEFAULT(' ')
         ,  TaskStatus     NVARCHAR(10)   NULL  DEFAULT('0')
         ,  JobStatus      NVARCHAR(10)   NULL  DEFAULT('0')
         )

   SET @c_JobStatus = '3'
   SET @c_Storerkey = ''
   SELECT @c_JobStatus = Status
         ,@c_Storerkey = Storerkey
   FROM TASKDETAIL WITH (NOLOCK)
   WHERE TaskDetailkey = @c_JobKey
   AND   TaskType = 'GTMJOB'

   SET @n_DefaultQty = 0
   SET @n_ShowUOMEA  = 0
   SELECT @n_DefaultQty = ISNULL(MAX(CASE WHEN Code = 'DefaultQty'  THEN 1 ELSE 0 END),0)
         ,@n_ShowUOMEA  = ISNULL(MAX(CASE WHEN Code = 'ShowUOMEA'  THEN 1 ELSE 0 END),0)
   FROM CODELKUP WITH (NOLOCK)
   WHERE ListName = 'GTMCFG'
   AND   Code2    = 'ASRSQC'
   AND   Storerkey= @c_Storerkey
   AND   (Short = 'Y' OR Short IS NULL OR Short = '')


   IF EXISTS ( SELECT 1
               FROM LOTxLOCxID WITH (NOLOCK)
               WHERE ID = @c_ID
               AND   LOTxLOCxID.Qty > 0
             )
   BEGIN
         INSERT INTO #TMP_QC
         (  JobKey
         ,  Taskdetailkey
         ,  Storerkey
         ,  SKu
         ,  Descr
         ,  FromID
         ,  Instruction
         ,  StatusMsg
         ,  QtyInCS
         ,  QtyInEA
         ,  PackUOM1
         ,  PackUOM3
         ,  TaskStatus
         ,  JobStatus
         )
      SELECT @c_JobKey
            ,TASKDETAIL.Taskdetailkey
            ,TASKDETAIL.Storerkey
            ,SKU.Sku
            ,SKU.Descr
            ,TASKDETAIL.FromID
            ,Instruction = TASKDETAIL.ReasonKey + ' - ' + CODELKUP.Description
            ,TASKDETAIL.StatusMsg
            ,QtyInCS = ISNULL(SUM(CASE WHEN PACK.CaseCnt > 0 AND @n_ShowUOMEA = 0
                                       THEN FLOOR((LOTxLOCxID.Qty - LOTxLOCxID.QtyPicked) / PACK.CaseCnt)         --(Wan01)
                                       ELSE 0 END),0)
            ,QtyInEA = ISNULL(SUM(CASE WHEN PACK.CaseCnt > 0 AND @n_ShowUOMEA = 0
                                       THEN ((LOTxLOCxID.Qty - LOTxLOCxID.QtyPicked) % CONVERT(INT,PACK.CaseCnt)) --(Wan01)
                                       ELSE (LOTxLOCxID.Qty - LOTxLOCxID.QtyPicked) END),0)
            ,PACK.PackUOM1
            ,PACK.PackUOM3
            --,RowNo=Row_Number() OVER (PARTITION BY  TASKDETAIL.TaskDetailKey ORDER BY SKU.Sku)
            ,TASKDETAIL.Status
            ,@c_JobStatus
      FROM TASKDETAIL WITH (NOLOCK)
      JOIN LOTxLOCxID WITH (NOLOCK) ON (TASKDETAIL.Storerkey = LOTxLOCxID.Storerkey)
                                    AND(TASKDETAIL.FromID = LOTxLOCxID.ID)
      JOIN SKU        WITH (NOLOCK) ON (TASKDETAIL.Storerkey = SKU.Storerkey)
                                    AND(LOTxLOCxID.Sku = SKU.Sku)
      JOIN PACK       WITH (NOLOCK) ON (SKU.PackKey = PACK.PackKey)
      LEFT JOIN CODELKUP   WITH (NOLOCK) ON (CODELKUP.ListName = 'ASRSCOUTRS')
                                         AND(TASKDETAIL.Message01 = CODELKUP.Code)
      WHERE TASKDETAIL.TaskDetailKey = @c_TaskdetailKey
      AND   TASKDETAIL.TaskType = 'ASRSQC'
      AND   TASKDETAIL.FromID = @c_ID
      AND   LOTxLOCxID.Qty > 0
      GROUP BY TASKDETAIL.Taskdetailkey
            ,  TASKDETAIL.Storerkey
            ,  SKU.Sku
            ,  SKU.Descr
            ,  TASKDETAIL.FromID
            ,  TASKDETAIL.ReasonKey + ' - ' + CODELKUP.Description
            ,  TASKDETAIL.StatusMsg
            ,  PACK.PackUOM1
            ,  PACK.PackUOM3
            ,  TASKDETAIL.Status
      ORDER BY TASKDETAIL.TaskDetailKey
              ,SKU.Sku
   END
   ELSE
   BEGIN
      INSERT INTO #TMP_QC
      (  JobKey
      ,  Taskdetailkey
      ,  Storerkey
      ,  SKu
      ,  Descr
      ,  FromID
      ,  Instruction
      ,  StatusMsg
      ,  QtyInCS
      ,  QtyInEA
      ,  PackUOM1
      ,  PackUOM3
      ,  TaskStatus
      ,  JobStatus
      )
      SELECT TOP 1 @c_JobKey
            ,TASKDETAIL.Taskdetailkey
            ,TASKDETAIL.Storerkey
            ,Sku = ''
            ,Descr = ''
            ,TASKDETAIL.FromID
            ,Instruction = TASKDETAIL.ReasonKey + ' - ' + CODELKUP.Description
            ,TASKDETAIL.StatusMsg
            ,QtyInCS = 0
            ,QtyInEA = 0
            ,PackUOM1 = ''
            ,PackUOM2 = ''
--            ,RowNo=Row_Number() OVER (PARTITION BY  TASKDETAIL.TaskDetailKey ORDER BY SKU.Sku)
            ,TASKDETAIL.Status
            ,@c_JobStatus
      FROM TASKDETAIL WITH (NOLOCK)
      JOIN LOTxLOCxID WITH (NOLOCK) ON (TASKDETAIL.Storerkey = LOTxLOCxID.Storerkey)
                                    AND(TASKDETAIL.FromID = LOTxLOCxID.ID)
      JOIN SKU        WITH (NOLOCK) ON (TASKDETAIL.Storerkey = SKU.Storerkey)
                                    AND(LOTxLOCxID.Sku = SKU.Sku)
      JOIN PACK       WITH (NOLOCK) ON (SKU.PackKey = PACK.PackKey)
      LEFT JOIN CODELKUP   WITH (NOLOCK) ON (CODELKUP.ListName = 'ASRSCOUTRS')
                                         AND(TASKDETAIL.Message01 = CODELKUP.Code)
      WHERE TASKDETAIL.TaskDetailKey = @c_TaskdetailKey
      AND   TASKDETAIL.TaskType = 'ASRSQC'
      AND   TASKDETAIL.FromID = @c_ID
      AND   LOTxLOCxID.Qty = 0
      ORDER BY TASKDETAIL.TaskDetailKey
              ,SKU.Sku
   END

   SELECT JobKey
      ,  Taskdetailkey
      ,  Storerkey
      ,  SKu
      ,  Descr
      ,  FromID
      ,  Instruction
      ,  StatusMsg
      ,  QtyInCS
      ,  QtyInEA
      ,  PackUOM1
      ,  PackUOM3
      ,  RowNo = CONVERT(NVARCHAR(5), RowNo) + '/' + ( SELECT CONVERT(NVARCHAR(5),ISNULL(MAX(RowNo),0)) FROM  #TMP_QC )
      ,  TaskStatus
      ,  JobStatus
      ,  FromID -- IN00020776
   FROM #TMP_QC

   DROP TABLE #TMP_QC
END

GO
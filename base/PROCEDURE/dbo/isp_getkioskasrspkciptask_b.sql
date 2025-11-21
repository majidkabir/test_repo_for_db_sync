SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Stored Procedure: isp_GetKIOSKASRSPKCIPTask_b                        */  
/* Creation Date: 2015-01-21                                            */  
/* Copyright: IDS                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: SOS#315474 - Project Merlion - Exceed GTM Kiosk Module      */  
/*                                                                      */  
/* Called By: r_dw_kiosk_asrspk_cip_b_form                              */  
/*                                                                      */  
/* PVCS Version: 1.1                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Ver   Purposes                                  */ 
/* 03-JAN-2019 Wan01    1.1   WMS-7286 - PRHK-GTM Picking For COPACK Sku*/   
/************************************************************************/  
 
CREATE PROC [dbo].[isp_GetKIOSKASRSPKCIPTask_b]   
         (  @c_JobKey         NVARCHAR(10)
          , @c_TaskdetailKey  NVARCHAR(10)  -- GTMJOB's TASKDETAIl.TaskdetailKey
          , @c_FromID         NVARCHAR(18)= '' 
          , @c_ToID           NVARCHAR(18)= ''    
         )             
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_DEFAULTS OFF    
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @n_QtyToPick    INT

         , @c_TaskStatus   NVARCHAR(10)
         , @c_JobStatus    NVARCHAR(10)
         , @c_Storerkey    NVARCHAR(15)

         , @n_DefaultQty   INT
         , @n_ShowUOMEA    INT

   --(Wan01) - START            
   DECLARE @t_Pickdetail   TABLE
   (  Pickdetailkey        NVARCHAR(10)   NOT NULL PRIMARY KEY
   ,  Taskdetailkey        NVARCHAR(10)   NOT NULL 
   )
   --(Wan01) - END

   CREATE TABLE #Result (
     [ID]    [INT] IDENTITY(1,1) NOT NULL,  
     TaskdetailKey       NVARCHAR(10)   NULL,
     RefTaskKey          NVARCHAR(10)   NULL,
     FROMID              NVARCHAR(18)   NULL,
     TOID                NVARCHAR(18)   NULL,
     PALLETID            NVARCHAR(18)   NULL,
     OrderKey            NVARCHAR(10)   NULL,
     OrderStatus         NVARCHAR(10)   NULL DEFAULT ('0'),
     OrderLineNumber     NVARCHAR(5)    NULL,
     Storerkey           NVARCHAR(15)   NULL,  
     SKU                 NVARCHAR(20)   NULL,
     SKUDescr            NVARCHAR(120)  NULL,
     SUSR4               NVARCHAR(18)   NULL DEFAULT (''),
     Lot                 NVARCHAR(10)   NULL,
     Loc                 NVARCHAR(10)   NULL,
     LottableCode        NVARCHAR(3)    NULL,
     Lottable01Label     NVARCHAR(20)   NULL,
     Lottable02Label     NVARCHAR(20)   NULL,
     Lottable03Label     NVARCHAR(20)   NULL,
     Lottable04Label     NVARCHAR(20)   NULL,
     Lottable05Label     NVARCHAR(20)   NULL,
     Lottable06Label     NVARCHAR(20)   NULL,
     Lottable07Label     NVARCHAR(20)   NULL,
     Lottable08Label     NVARCHAR(20)   NULL,
     Lottable09Label     NVARCHAR(20)   NULL,
     Lottable10Label     NVARCHAR(20)   NULL,
     Lottable11Label     NVARCHAR(20)   NULL,
     Lottable12Label     NVARCHAR(20)   NULL,
     Lottable13Label     NVARCHAR(20)   NULL,
     Lottable14Label     NVARCHAR(20)   NULL,
     Lottable15Label     NVARCHAR(20)   NULL,
     Lottable01          NVARCHAR(18)   NULL,
     Lottable02          NVARCHAR(18)   NULL,
     Lottable03          NVARCHAR(18)   NULL,
     Lottable04          DATETIME       NULL,
     Lottable05          DATETIME       NULL,
     Lottable06          NVARCHAR(30)   NULL,
     Lottable07          NVARCHAR(30)   NULL,
     Lottable08          NVARCHAR(30)   NULL,
     Lottable09          NVARCHAR(30)   NULL,
     Lottable10          NVARCHAR(30)   NULL,
     Lottable11          NVARCHAR(30)   NULL,
     Lottable12          NVARCHAR(30)   NULL,
     Lottable13          DATETIME       NULL,
     Lottable14          DATETIME       NULL,
     Lottable15          DATETIME       NULL,
     Lottable01Code      NVARCHAR(3)    NULL,
     Lottable02Code      NVARCHAR(3)    NULL,
     Lottable03Code      NVARCHAR(3)    NULL,
     Lottable04Code      NVARCHAR(3)    NULL,
     Lottable05Code      NVARCHAR(3)    NULL,
     Lottable06Code      NVARCHAR(3)    NULL,
     Lottable07Code      NVARCHAR(3)    NULL,
     Lottable08Code      NVARCHAR(3)    NULL,
     Lottable09Code      NVARCHAR(3)    NULL,
     Lottable10Code      NVARCHAR(3)    NULL,
     Lottable11Code      NVARCHAR(3)    NULL,
     Lottable12Code      NVARCHAR(3)    NULL,
     Lottable13Code      NVARCHAR(3)    NULL,
     Lottable14Code      NVARCHAR(3)    NULL,
     Lottable15Code      NVARCHAR(3)    NULL,
     CaseCnt             FLOAT          NULL,
     PACKUOM1            NVARCHAR(10)   NULL,
     PACKUOM3            NVARCHAR(10)   NULL, 
     QtyToPickInCS       INT NULL,
     QtyToPickInEA       INT NULL,
     QtyInCS             INT NOT NULL  DEFAULT (0),
     QtyInEA             INT NOT NULL  DEFAULT (0),
     PackSize            NVARCHAR(30)  NULL,
     TaskStatus          NVARCHAR(10) NULL DEFAULT ('0'),
     JobStatus          NVARCHAR(10)  NULL DEFAULT ('0')
,    Remarks             NVARCHAR(80)  NOT NULL DEFAULT ('')      --(Wan01)
     )

   --(Wan01) - START            
   INSERT INTO @t_Pickdetail (Pickdetailkey, Taskdetailkey)   
   SELECT PD.Pickdetailkey, TD.TaskdetailKey
   FROM TASKDETAIL TD WITH (NOLOCK) 
   JOIN PICKDETAIL PD WITH (NOLOCK) ON (TD.RefTaskKey = PD.TaskDetailKey)
   WHERE TD.FromID = @c_FromID
   AND   TD.RefTaskKey = @c_TaskdetailKey
   AND   TD.Status < '9'  
   AND   PD.Qty > 0
   AND   PD.Sku <> TD.Message02
   --(Wan01) - END

   SET @c_JobStatus = '5'
   SET @c_Storerkey = ''
   SELECT @c_JobStatus = Status
         ,@c_Storerkey = Storerkey 
   FROM TASKDETAIL WITH (NOLOCK)
   WHERE TaskDetailKey = @c_JobKey
   AND   TaskType = 'GTMJOB'

   SET @c_TaskStatus = '9'
   SELECT @c_TaskStatus = ISNULL(MIN(TASKDETAIL.Status),'7')
   FROM TASKDETAIL WITH (NOLOCK)
   WHERE TASKDETAIL.TaskType   = 'ASRSPK'
   AND   TASKDETAIL.RefTaskKey = @c_TaskDetailKey 

   SET @n_DefaultQty = 0
   SET @n_ShowUOMEA  = 0
   SELECT @n_DefaultQty = ISNULL(MAX(CASE WHEN Code = 'DefaultQty'  THEN 1 ELSE 0 END),0)
         ,@n_ShowUOMEA  = ISNULL(MAX(CASE WHEN Code = 'ShowUOMEA'  THEN 1 ELSE 0 END),0)
   FROM CODELKUP WITH (NOLOCK)
   WHERE ListName = 'GTMCFG'
   AND   Code2    = 'ASRSPK'
   AND   Storerkey= @c_Storerkey
   AND   (Short = 'Y' OR Short IS NULL OR Short = '')

   INSERT INTO #Result (TaskdetailKey,RefTaskKey,FROMID,TOID,PalletID,OrderKey,OrderStatus,OrderLineNumber,Storerkey,SKU,SKUDescr,SUSR4
                        ,Lot,Loc,LottableCode
                        ,Lottable01label,Lottable02label,Lottable03label,Lottable04label,Lottable05label
                        ,Lottable06label,Lottable07label,Lottable08label,Lottable09label,Lottable10label
                        ,Lottable11label,Lottable12label,Lottable13label,Lottable14label,Lottable15label
                        ,Lottable01,Lottable02,Lottable03,Lottable04,Lottable05
                        ,Lottable06,Lottable07,Lottable08,Lottable09,Lottable10
                        ,Lottable11,Lottable12,Lottable13,Lottable14,Lottable15                           
                        ,Lottable01Code,Lottable02Code,Lottable03Code,Lottable04Code,Lottable05Code
                        ,Lottable06Code,Lottable07Code,Lottable08Code,Lottable09Code,Lottable10Code
                        ,Lottable11Code,Lottable12Code,Lottable13Code,Lottable14Code,Lottable15Code
                        ,CaseCnt,PackUOM1,PackUOM3,QtyToPickInCS,QtyToPickInEA,QtyInCS,QtyInEA,PackSize
                        ,TaskStatus,JobStatus,Remarks)                                              --(Wan01)
   SELECT TOP 1 TASKDETAIL.TaskdetailKey
      , TASKDETAIL.RefTaskKey
      , @c_FromID
      , @c_ToID
      , @c_ToID
      ,OrderKey        = ISNULL(PICKDETAIL.Orderkey,'')
      ,OrderStatus     = ISNULL(ORDERS.SOStatus,'CANC')
      ,OrderLineNumber = ISNULL(PICKDETAIL.OrderLineNumber,'')
      ,Storerkey       = ISNULL(PICKDETAIL.Storerkey,'')
      ,SKU             = ISNULL(PICKDETAIL.sku,'')
      ,SKUDescr        = ISNULL(SKU.descr,'')
      ,Susr4           = ISNULL(SKU.Susr4,'')
      ,Lot             = ISNULL(PICKDETAIL.Lot,'')
      ,Loc             = ISNULL(PICKDETAIL.Loc,'')
      ,Lottablecode    = ISNULL(SKU.Lottablecode,'')
      ,LOTCode.Lottable01Label--CASE WHEN ISNULL(RTRIM(SKU.Lottable01Label),'') = '' THEN 'Lottable01Label' ELSE SKU.Lottable01Label END
      ,LOTCode.Lottable02Label--CASE WHEN ISNULL(RTRIM(SKU.Lottable02Label),'') = '' THEN 'Lottable02Label' ELSE SKU.Lottable02Label END
      ,LOTCode.Lottable03Label--CASE WHEN ISNULL(RTRIM(SKU.Lottable03Label),'') = '' THEN 'Lottable03Label' ELSE SKU.Lottable03Label END
      ,LOTCode.Lottable04Label--CASE WHEN ISNULL(RTRIM(SKU.Lottable04Label),'') = '' THEN 'Lottable04Label' ELSE SKU.Lottable04Label END
      ,LOTCode.Lottable05Label--CASE WHEN ISNULL(RTRIM(SKU.Lottable05Label),'') = '' THEN 'Lottable05Label' ELSE SKU.Lottable05Label END
      ,LOTCode.Lottable06Label--CASE WHEN ISNULL(RTRIM(SKU.Lottable06Label),'') = '' THEN 'Lottable06Label' ELSE SKU.Lottable06Label END
      ,LOTCode.Lottable07Label--CASE WHEN ISNULL(RTRIM(SKU.Lottable07Label),'') = '' THEN 'Lottable07Label' ELSE SKU.Lottable07Label END
      ,LOTCode.Lottable08Label--CASE WHEN ISNULL(RTRIM(SKU.Lottable08Label),'') = '' THEN 'Lottable08Label' ELSE SKU.Lottable08Label END
      ,LOTCode.Lottable09Label--CASE WHEN ISNULL(RTRIM(SKU.Lottable09Label),'') = '' THEN 'Lottable09Label' ELSE SKU.Lottable09Label END
      ,LOTCode.Lottable10Label--CASE WHEN ISNULL(RTRIM(SKU.Lottable10Label),'') = '' THEN 'Lottable10Label' ELSE SKU.Lottable10Label END
      ,LOTCode.Lottable11Label--CASE WHEN ISNULL(RTRIM(SKU.Lottable11Label),'') = '' THEN 'Lottable11Label' ELSE SKU.Lottable11Label END
      ,LOTCode.Lottable12Label--CASE WHEN ISNULL(RTRIM(SKU.Lottable12Label),'') = '' THEN 'Lottable12Label' ELSE SKU.Lottable12Label END
      ,LOTCode.Lottable13Label--CASE WHEN ISNULL(RTRIM(SKU.Lottable13Label),'') = '' THEN 'Lottable13Label' ELSE SKU.Lottable13Label END
      ,LOTCode.Lottable14Label--CASE WHEN ISNULL(RTRIM(SKU.Lottable14Label),'') = '' THEN 'Lottable14Label' ELSE SKU.Lottable14Label END
      ,LOTCode.Lottable15Label--CASE WHEN ISNULL(RTRIM(SKU.Lottable15Label),'') = '' THEN 'Lottable15Label' ELSE SKU.Lottable15Label END
      ,Lottable01      = ISNULL(LOTATTRIBUTE.Lottable01,'')
      ,Lottable02      = ISNULL(LOTATTRIBUTE.Lottable02,'')
      ,Lottable03      = ISNULL(LOTATTRIBUTE.Lottable03,'')
      ,Lottable04      = ISNULL(LOTATTRIBUTE.Lottable04,'') 
      ,Lottable05      = ISNULL(LOTATTRIBUTE.Lottable05,'')
      ,Lottable06      = ISNULL(LOTATTRIBUTE.Lottable06,'')
      ,Lottable07      = ISNULL(LOTATTRIBUTE.Lottable07,'')
      ,Lottable08      = ISNULL(LOTATTRIBUTE.Lottable08,'')
      ,Lottable09      = ISNULL(LOTATTRIBUTE.Lottable09,'') 
      ,Lottable10      = ISNULL(LOTATTRIBUTE.Lottable10,'')
      ,Lottable11      = ISNULL(LOTATTRIBUTE.Lottable11,'')
      ,Lottable12      = ISNULL(LOTATTRIBUTE.Lottable12,'')
      ,Lottable13      = ISNULL(LOTATTRIBUTE.Lottable13,'')
      ,Lottable14      = ISNULL(LOTATTRIBUTE.Lottable14,'') 
      ,Lottable15      = ISNULL(LOTATTRIBUTE.Lottable15,'')
      ,lottable01Code  = LOTCode.Lottable01Code--CASE WHEN lottableno = '1' THEN (visible + Editable + Required) ELSE '' END
      ,lottable02Code  = LOTCode.Lottable02Code--CASE WHEN lottableno = '2' THEN (visible + Editable + Required) ELSE '' END
      ,lottable03Code  = LOTCode.Lottable03Code--CASE WHEN lottableno = '3' THEN (visible + Editable + Required) ELSE '' END
      ,lottable04Code  = LOTCode.Lottable04Code--CASE WHEN lottableno = '4' THEN (visible + Editable + Required) ELSE '' END
      ,lottable05Code  = LOTCode.Lottable05Code--CASE WHEN lottableno = '5' THEN (visible + Editable + Required) ELSE '' END
      ,lottable06Code  = LOTCode.Lottable06Code--CASE WHEN lottableno = '6' THEN (visible + Editable + Required) ELSE '' END 
      ,lottable07Code  = LOTCode.Lottable07Code--CASE WHEN lottableno = '7' THEN (visible + Editable + Required) ELSE '' END
      ,lottable08Code  = LOTCode.Lottable08Code--CASE WHEN lottableno = '8' THEN (visible + Editable + Required) ELSE '' END
      ,lottable09Code  = LOTCode.Lottable09Code--CASE WHEN lottableno = '9' THEN (visible + Editable + Required) ELSE '' END
      ,lottable10Code  = LOTCode.Lottable10Code--CASE WHEN lottableno = '10'THEN (visible + Editable + Required) ELSE '' END
      ,lottable11Code  = LOTCode.Lottable11Code--CASE WHEN lottableno = '11'THEN (visible + Editable + Required) ELSE '' END
      ,lottable12Code  = LOTCode.Lottable12Code--CASE WHEN lottableno = '12'THEN (visible + Editable + Required) ELSE '' END  
      ,lottable13Code  = LOTCode.Lottable13Code--CASE WHEN lottableno = '13'THEN (visible + Editable + Required) ELSE '' END
      ,lottable14Code  = LOTCode.Lottable14Code--CASE WHEN lottableno = '14'THEN (visible + Editable + Required) ELSE '' END
      ,lottable15Code  = LOTCode.Lottable15Code--CASE WHEN lottableno = '15'THEN (visible + Editable + Required) ELSE '' END 
      ,CaseCnt         = PACK.CaseCnt  
      ,PACKUOM1        = PACK.PackUOM1  
      ,PACKUOM3        = PACK.PackUOM3   
      ,QtyToPickInCS   = 0 --CASE WHEN PACK.CaseCnt > 0 THEN FLOOR(PICKDETAIL.Qty / PACK.CaseCnt) ELSE 0 END 
      ,QtyToPickInEA   = 0 --CASE WHEN PACK.CaseCnt > 0 THEN PICKDETAIL.Qty % CONVERT(INT,PACK.CaseCnt) ELSE 0 END
      ,QtyInCS         = 0
      ,QtyInEA         = 0
      ,PackSize        = '1' + ' ' + RTRIM(PACK.PackUOM1) + ' ' + '=' + ' ' 
                       + convert(nvarchar(5),PACK.CaseCnt) + ' '+  RTRIM(PACK.PackUOM3)
      ,TaskStatus      = @c_TaskStatus 
      ,JobStatus       = @c_JobStatus
      ,Remarks = CASE WHEN TASKDETAIL.Message02 = '' THEN ''                                       --(Wan01)
                      ELSE 'COPACK ITEM WITH ' +  RTRIM(TASKDETAIL.Message02) END                  --(Wan01)
   FROM @t_Pickdetail t                                                                            --(Wan01)
   JOIN TASKDETAIL   WITH (NOLOCK) ON (t.TaskDetailKey = TASKDETAIL.TaskDetailKey)                 --(Wan01)
   LEFT JOIN PICKDETAIL   WITH (NOLOCK) ON (t.PickDetailKey = PICKDETAIL.PickDetailKey)            --(Wan01)
   LEFT JOIN ORDERS       WITH (NOLOCK) ON (PICKDETAIL.Orderkey = ORDERS.Orderkey)
   LEFT JOIN LOTATTRIBUTE WITH (NOLOCK) ON (PICKDETAIL.Lot = LOTATTRIBUTE.Lot)
   LEFT JOIN SKU          WITH (NOLOCK) ON (PICKDETAIL.Storerkey = SKU.Storerkey)  
                                        AND(PICKDETAIL.Sku = SKU.Sku) 
   LEFT JOIN PACK         WITH (NOLOCK) ON (SKU.PackKey = PACK.PackKey)
   OUTER APPLY fnc_GetLottableCodes (SKU.Storerkey, SKU.Sku) LOTCode   
   WHERE TASKDETAIL.TaskType   = 'ASRSPK'
   AND   TASKDETAIL.RefTaskKey = @c_TaskdetailKey  
   AND   ISNULL(TASKDETAIL.FromID,'') = @c_FromID 
   AND   PICKDETAIL.Status <= '5' 
   AND   PICKDETAIL.Status <> '4' 
   ORDER BY CASE WHEN PICKDETAIL.Status = '5' AND @c_JobStatus < '5' THEN 5 ELSE 0 END
         ,  CASE WHEN PICKDETAIL.Orderkey IS NULL OR ORDERS.SOStatus = 'CANC' THEN 9 ELSE 0 END
         ,  CONVERT(INT, PICKDETAIL.PickdetailKey ) 
            * CASE WHEN PICKDETAIL.Status = '5' THEN 1 ELSE -1 END DESC

   SET @n_QtyToPick = 0
   SELECT @n_QtyToPick = ISNULL(SUM(PICKDETAIL.Qty),0)
   FROM #RESULT
   JOIN PICKDETAIL WITH (NOLOCK) ON (#RESULT.Orderkey = PICKDETAIL.Orderkey)
                                 AND(#RESULT.Lot      = PICKDETAIL.Lot)
                                 AND(#RESULT.FromID   = PICKDETAIL.ID)
                                 AND(#RESULT.RefTaskKey = PICKDETAIL.Taskdetailkey) 
   WHERE PICKDETAIL.Status < '5'

   UPDATE #RESULT
   SET QtyToPickInCS = CASE WHEN CaseCnt > 0 AND @n_ShowUOMEA = 0 THEN FLOOR(@n_QtyToPick / CaseCnt) ELSE 0 END 
      ,QtyToPickInEA = CASE WHEN CaseCnt > 0 AND @n_ShowUOMEA = 0 THEN (@n_QtyToPick % CONVERT(INT,CaseCnt)) ELSE @n_QtyToPick END

   IF @n_DefaultQty = 1 
   BEGIN   
      UPDATE #RESULT
      SET   QtyInCS = QtyToPickInCS
         ,  QtyInEA = QtyToPickInEA
   END

   SELECT @c_JobKey,TaskdetailKey,FROMID,TOID,PalletID,OrderKey,OrderStatus,OrderLineNumber,Storerkey,SKU,SKUDescr,SUSR4
         ,Lot,LottableCode         
         ,Lottable01label,Lottable02label,Lottable03label,Lottable04label,Lottable05label 
         ,Lottable06label,Lottable07label,Lottable08label,Lottable09label,Lottable10label 
         ,Lottable11label,Lottable12label,Lottable13label,Lottable14label,Lottable15label
         ,Lottable01,Lottable02,Lottable03,Lottable04,Lottable05
         ,Lottable06,Lottable07,Lottable08,Lottable09,Lottable10
         ,Lottable11,Lottable12,Lottable13,Lottable14,Lottable15
         ,Lottable01Code,Lottable02Code,Lottable03Code,Lottable04Code,Lottable05Code
         ,Lottable06Code,Lottable07Code,Lottable08Code,Lottable09Code,Lottable10Code
         ,Lottable11Code,Lottable12Code,Lottable13Code,Lottable14Code,Lottable15Code
         ,CaseCnt,PackUOM1,PackUOM3,QtyToPickInCS,QtyToPickInEA,QtyInCS,QtyInEA,PackSize
         ,TaskStatus,JobStatus
         ,Remarks                                                                               --(Wan01)
   FROM #Result 
END   

GO
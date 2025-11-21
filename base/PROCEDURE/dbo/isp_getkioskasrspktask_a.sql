SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: isp_GetKIOSKASRSPKTask_a                           */  
/* Creation Date: 2015-01-21                                            */  
/* Copyright: IDS                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: SOS#315474 - Project Merlion - Exceed GTM Kiosk Module      */  
/*                                                                      */  
/* Called By: r_dw_kiosk_asrspk_a_form                                  */  
/*                                                                      */  
/* PVCS Version: 1.3                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Ver   Purposes                                  */ 
/* 28-DEC-2015 WAN01    1.1   Project Merlion - GTM Kiosk Enhancement   */  
/* 12-JAN-2016 Wan02    1.2   Fixed. Pallet Qty = Qty - QtyPicked       */ 
/* 03-JAN-2019 Wan03    1.3   WMS-7286 - PRHK-GTM Picking For COPACK Sku*/ 
/************************************************************************/  
CREATE PROC [dbo].[isp_GetKIOSKASRSPKTask_a]  
         (  @c_JobKey         NVARCHAR(10)  
          , @c_TaskdetailKey  NVARCHAR(10) 
          , @c_FromID         NVARCHAR(18)= '' 
          , @c_ToID           NVARCHAR(18)= ''   
         )             
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_DEFAULTS OFF    
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  


   DECLARE @n_CntOrder       INT
         , @n_Qty            INT 
         , @n_QtyPicked      INT
         , @n_QtyToPick      INT

         , @c_JobStatus      NVARCHAR(10)
         , @c_Storerkey      NVARCHAR(15)
         , @c_PickMethod     NVARCHAR(10)    --(Wan01)
         , @n_NoOfSku        INT 
         
         , @n_DefaultQty     INT
         , @n_ShowUOMEA      INT

   --(Wan03) - START            
   DECLARE @t_Pickdetail   TABLE
   (  Pickdetailkey        NVARCHAR(10)   NOT NULL PRIMARY KEY
   ,  Taskdetailkey        NVARCHAR(10)   NOT NULL 
   )
   --(Wan03) - END
         
   CREATE TABLE #Result (
   [ID]    [INT] IDENTITY(1,1) NOT NULL, 
   TASKDETAILKEY       NVARCHAR(10)   NULL,
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
   PalletQtyInCS       INT NULL,
   PalletQtyInEA       INT NULL,
   QtyToPickInCS       INT NULL,
   QtyToPickInEA       INT NULL,
   RemainingQtyInCS    INT NULL,
   RemainingQtyInEA    INT NULL,
   OrderCnt            INT NULL,
   TaskStatus          NVARCHAR(10) NULL DEFAULT ('0'),
   JobStatus           NVARCHAR(10) NULL DEFAULT ('0'),
   PickMethod          NVARCHAR(10) NULL DEFAULT ('F')      --(Wan01)
,  Remarks             NVARCHAR(80)  NOT NULL DEFAULT ('')  --(Wan03)
       )

   --(Wan03) - START    
   INSERT INTO @t_Pickdetail (Pickdetailkey, Taskdetailkey)
   SELECT PD.Pickdetailkey, TD.TaskdetailKey
   FROM TASKDETAIL TD WITH (NOLOCK) 
   JOIN PICKDETAIL PD WITH (NOLOCK) ON (TD.TaskdetailKey = PD.TaskDetailKey)
   WHERE TD.TaskdetailKey = @c_TaskdetailKey
   AND   PD.Qty > 0
   AND   PD.Sku <> TD.Message02
   --(Wan03) - END

   SET @c_Storerkey = ''
   SET @c_JobStatus = '5'   
   SELECT @c_JobStatus = Status
         ,@c_Storerkey = Storerkey
   FROM TASKDETAIL WITH (NOLOCK)
   WHERE TaskDetailKey = @c_JobKey
   AND   TaskType = 'GTMJOB'

   SET @n_DefaultQty = 0
   SET @n_ShowUOMEA  = 0
   SELECT @n_DefaultQty = ISNULL(MAX(CASE WHEN Code = 'DefaultQty'  THEN 1 ELSE 0 END),0)
         ,@n_ShowUOMEA  = ISNULL(MAX(CASE WHEN Code = 'ShowUOMEA'  THEN 1 ELSE 0 END),0)
   FROM CODELKUP WITH (NOLOCK)
   WHERE ListName = 'GTMCFG'
   AND   Code2    = 'ASRSPK'
   AND   Storerkey= @c_Storerkey
   AND   (Short = 'Y' OR Short IS NULL OR Short = '')

   INSERT INTO #Result (Taskdetailkey,FROMID,TOID,PalletID,OrderKey,OrderStatus,OrderLineNumber,Storerkey,SKU,SKUDescr
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
               ,CaseCnt,PackUOM1,PackUOM3,PalletQtyInCS,PalletQtyInEA,QtyToPickInCS
               ,QtyToPickInEA,RemainingQtyInCS,RemainingQtyInEA
               ,OrderCnt,TaskStatus,JobStatus)
   SELECT TOP 1 TASKDETAIL.TASKDETAILKEY
   , @c_FromID
   , @c_ToID
   , @c_FromID
   ,ORDERS.Orderkey
   ,ORDERS.SOStatus
   ,OrderLineNumber = ISNULL(PICKDETAIL.OrderLineNumber,'')
   ,ISNULL(PICKDETAIL.Storerkey,'')
   ,ISNULL(PICKDETAIL.sku,'')
   ,ISNULL(SKU.descr,'')
   ,ISNULL(PICKDETAIL.Lot,'')
   ,ISNULL(PICKDETAIL.Loc,'')
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
   ,ISNULL(LOTATTRIBUTE.Lottable01,'')
   ,ISNULL(LOTATTRIBUTE.Lottable02,'')
   ,ISNULL(LOTATTRIBUTE.Lottable03,'')
   ,ISNULL(LOTATTRIBUTE.Lottable04,'') 
   ,ISNULL(LOTATTRIBUTE.Lottable05,'')
   ,ISNULL(LOTATTRIBUTE.Lottable06,'')
   ,ISNULL(LOTATTRIBUTE.Lottable07,'')
   ,ISNULL(LOTATTRIBUTE.Lottable08,'')
   ,ISNULL(LOTATTRIBUTE.Lottable09,'') 
   ,ISNULL(LOTATTRIBUTE.Lottable10,'')
   ,ISNULL(LOTATTRIBUTE.Lottable11,'')
   ,ISNULL(LOTATTRIBUTE.Lottable12,'')
   ,ISNULL(LOTATTRIBUTE.Lottable13,'')
   ,ISNULL(LOTATTRIBUTE.Lottable14,'') 
   ,ISNULL(LOTATTRIBUTE.Lottable15,'')
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
   ,PACK.Casecnt 
   ,PACK.PackUOM1  
   ,PACK.PackUOM3   
   ,0--CASE WHEN PACK.CaseCnt > 0 AND @n_ShowUOMEA = 0 THEN FLOOR(@n_Qty / PACK.CaseCnt) ELSE 0 END 
   ,0--CASE WHEN PACK.CaseCnt > 0 AND @n_ShowUOMEA = 0 THEN (@n_Qty % CONVERT(INT,PACK.CaseCnt)) ELSE @n_Qty END
   ,0
   ,0
   ,0--CASE WHEN PACK.CaseCnt > 0 AND @n_ShowUOMEA = 0 THEN FLOOR((@n_Qty - @n_QtyPicked)/ PACK.CaseCnt) ELSE 0 END 
   ,0--CASE WHEN PACK.CaseCnt > 0 AND @n_ShowUOMEA = 0 THEN ((@n_Qty - @n_QtyPicked) % CONVERT(INT,PACK.CaseCnt)) ELSE (@n_Qty - @n_QtyPicked) END
   ,0--@n_CntOrder
   ,TASKDETAIL.Status 
   ,@c_JobStatus
   FROM @t_Pickdetail t                                                                            --(Wan03)
   JOIN TASKDETAIL   WITH (NOLOCK) ON (t.TaskDetailKey = TASKDETAIL.TaskDetailKey)                 --(Wan03)
   JOIN ORDERS            WITH (NOLOCK) ON (TASKDETAIL.Orderkey = ORDERS.Orderkey)
   LEFT JOIN PICKDETAIL   WITH (NOLOCK) ON (t.PickDetailKey = PICKDETAIL.PickDetailKey)            --(Wan03)
   LEFT JOIN LOTATTRIBUTE WITH (NOLOCK) ON (PICKDETAIL.Lot = LOTATTRIBUTE.Lot)
   LEFT JOIN SKU          WITH (NOLOCK) ON (PICKDETAIL.Storerkey = SKU.Storerkey)  
                                        AND(PICKDETAIL.Sku = SKU.Sku) 
   LEFT JOIN PACK         WITH (NOLOCK) ON (SKU.PackKey = PACK.PackKey)
   OUTER APPLY fnc_GetLottableCodes (SKU.Storerkey, SKU.Sku) LOTCode 
   WHERE TASKDETAIL.TaskDetailKey = @c_TaskdetailKey  
   AND   ISNULL(TASKDETAIL.FromID,'') = @c_FromID 
   AND   PICKDETAIL.Status <= '5' 
   AND   PICKDETAIL.Status <> '4' 
   ORDER BY CASE WHEN PICKDETAIL.Status = '5' AND @c_JobStatus < '5' THEN 5 ELSE 0 END
         ,  CASE WHEN PICKDETAIL.Orderkey IS NULL OR ORDERS.SOStatus = 'CANC' THEN 9 ELSE 0 END 
         ,  CONVERT(INT, PICKDETAIL.PickDetailKey ) 
            * CASE WHEN PICKDETAIL.Status = '5' THEN 1 ELSE -1 END DESC

   SET @n_Qty       = 0
   SET @n_QtyPicked = 0
   SELECT @n_Qty       = ISNULL(SUM(LOTxLOCxID.Qty - LOTxLOCxID.QtyPicked),0) --(Wan02)
         ,@n_QtyPicked = ISNULL(SUM(LOTxLOCxID.QtyPicked),0)
   FROM #RESULT 
   JOIN LOTxLOCxID WITH (NOLOCK) ON (#RESULT.Storerkey = LOTxLOCxID.Storerkey)
                                 AND(#RESULT.Sku = LOTxLOCxID.Sku)
                                 AND(#RESULT.FromID = LOTxLOCxID.ID)

   SET @n_QtyToPick = 0
   SELECT @n_QtyToPick = ISNULL(SUM(PICKDETAIL.Qty),0)
   FROM #RESULT
   JOIN PICKDETAIL WITH (NOLOCK) ON (#RESULT.Orderkey = PICKDETAIL.Orderkey)
                                 AND(#RESULT.Lot      = PICKDETAIL.Lot)
                                 AND(#RESULT.FromID   = PICKDETAIL.ID)
                                 AND(#RESULT.Taskdetailkey = PICKDETAIL.Taskdetailkey) 
   WHERE PICKDETAIL.Status < '5'

   SET @n_CntOrder = 0
   SELECT @n_CntOrder = COUNT(DISTINCT PICKDETAIL.Orderkey)
   FROM #RESULT
   JOIN PICKDETAIL WITH (NOLOCK) ON (#RESULT.FromID = PICKDETAIL.ID)
   WHERE Status < '5'

   --(Wan01) - START
   SET @c_PickMethod = 'F'

   SET @n_NoOfSku = 0
   SELECT @n_NoOfSku = COUNT(1)
   FROM LOTxLOCxID WITH (NOLOCK)
   WHERE Id = @c_FromId
   AND Qty > 0
   GROUP BY LOC
         ,  ID

   IF @n_NoOfSku = 1 AND @n_CntOrder = 1 AND @n_Qty > 0
   BEGIN
      IF EXISTS ( SELECT 1 
                  FROM #RESULT WITH (NOLOCK)
                  JOIN SKU WITH (NOLOCK) ON (#RESULT.Storerkey = SKU.Storerkey)
                                         AND(#RESULT.Sku = SKU.Sku)
                  WHERE ISNULL(SKU.SUSR4,'') <> 'SSCC'
                )
      BEGIN
         IF ((@n_QtyToPick / @n_Qty) * 100.00) > 50  AND @n_Qty >= @n_QtyToPick -- Include 100% picking
         BEGIN
            SET @c_PickMethod = 'R'    -- Reverse
         END 
      END
   END
   --(Wan01) - END

   UPDATE #RESULT
   SET PalletQtyInCS    = CASE WHEN CaseCnt > 0 AND @n_ShowUOMEA = 0 THEN FLOOR(@n_Qty / CaseCnt) ELSE 0 END 
      ,PalletQtyInEA    = CASE WHEN CaseCnt > 0 AND @n_ShowUOMEA = 0 THEN (@n_Qty % CONVERT(INT,CaseCnt)) ELSE @n_Qty END
      ,RemainingQtyInCS = CASE WHEN CaseCnt > 0 AND @n_ShowUOMEA = 0 THEN FLOOR((@n_Qty - @n_QtyToPick) / CaseCnt) ELSE 0 END 
      ,RemainingQtyInEA = CASE WHEN CaseCnt > 0 AND @n_ShowUOMEA = 0 THEN (@n_Qty - @n_QtyToPick) % CONVERT(INT, CaseCnt) ELSE (@n_Qty - @n_QtyToPick) END
      ,QtyToPickInCS    = CASE WHEN CaseCnt > 0 AND @n_ShowUOMEA = 0 THEN FLOOR(@n_QtyToPick / CaseCnt) ELSE 0 END 
      ,QtyToPickInEA    = CASE WHEN CaseCnt > 0 AND @n_ShowUOMEA = 0 THEN (@n_QtyToPick % CONVERT(INT,CaseCnt)) ELSE @n_QtyToPick END
      ,OrderCnt         = @n_CntOrder
      ,PickMethod       = @c_PickMethod         --(Wan01)

   SELECT @c_JobKey, Taskdetailkey,FROMID,TOID,PalletID,OrderKey,OrderStatus,OrderLineNumber,Storerkey,SKU,SKUDescr,SUSR4
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
         ,PackUOM1,PackUOM3,PalletQtyInCS,PalletQtyInEA,QtyToPickInCS,QtyToPickInEA,RemainingQtyInCS,RemainingQtyInEA
         ,OrderCnt,TaskStatus,JobStatus
         ,PickMethod          --(Wan01) 
         ,Remarks             --(Wan03)
   FROM #Result 
END        

GO
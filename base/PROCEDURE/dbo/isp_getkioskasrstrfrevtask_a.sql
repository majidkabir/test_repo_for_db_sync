SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Stored Procedure: isp_GetKIOSKASRSTRFRevTask_a                       */  
/* Creation Date: 2015-01-21                                            */  
/* Copyright: IDS                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: SOS#315474 - Project Merlion - Exceed GTM Kiosk Module      */  
/*                                                                      */  
/* Called By: r_dw_kiosk_asrstrf_rev_a_form                             */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author  Ver   Purposes                                  */  
/************************************************************************/  
  
CREATE PROC [dbo].[isp_GetKIOSKASRSTRFRevTask_a]   
         (  @c_JobKey         NVARCHAR(10) 
         ,  @c_TaskdetailKey  NVARCHAR(10)   
         ,  @c_FromID         NVARCHAR(18)= '' 
         ,  @c_ToID           NVARCHAR(18)= '' 
        
         )             
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_DEFAULTS OFF    
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  


   DECLARE @n_Qty              INT
         
         , @n_DefaultQty       INT
         , @n_ShowUOMEA        INT

         , @c_JobStatus        NVARCHAR(10)
         , @c_Storerkey        NVARCHAR(15)

   CREATE TABLE #Result ( 
   [ID]    [INT] IDENTITY(1,1) NOT NULL,  
   TASKDETAILKEY       NVARCHAR(10)   NULL,
   FROMID              NVARCHAR(18)   NULL,
   TOID                NVARCHAR(18)   NULL,
   PalletID            NVARCHAR(18)   NULL,
   TransferKey         NVARCHAR(10)   NULL,
   Transferlinenumber  NVARCHAR(5)    NULL,
   FromStorerkey       NVARCHAR(15)   NULL, 
   FromSKU             NVARCHAR(20)   NULL,   
   Storerkey           NVARCHAR(15)   NULL, 
   SKU                 NVARCHAR(20)   NULL,
   SKUDescr            NVARCHAR(120)  NULL,
   TransferReason      NVARCHAR(120)  NULL,
   Lottablecode        NVARCHAR(30)   NULL,
   Lottable01Label     NVARCHAR(20)   NULL,
   Lottable02Label     NVARCHAR(20)   NULL,
   Lottable03Label     NVARCHAR(20)  NULL,
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
   PACKUOM1            NVARCHAR(10)   NULL,
   PACKUOM3            NVARCHAR(10)   NULL, 
   CASECNT             INT NULL,
   PalletQtyInCS       INT NULL,
   PalletQtyInEA       INT NULL,
   QtyToTrfInCS        INT NULL,
   QtyToTrfInEA        INT NULL,
   taskStatus          NVARCHAR(10),
   JobStatus           NVARCHAR(10) 
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
   AND   Code2    = 'ASRSTRF'
   AND   Storerkey= @c_Storerkey
   AND   (Short = 'Y' OR Short IS NULL OR Short = '')   

   INSERT INTO #Result (TaskDetailKey,FROMID,TOID,PalletID,TransferKey,Transferlinenumber,FromStorerkey,FromSKU,Storerkey,SKU,SKUDescr,TransferReason
                     ,LottableCode
                     ,Lottable01label,Lottable02label,Lottable03label,Lottable04label,Lottable05label
                     ,Lottable06label,Lottable07label,Lottable08label,Lottable09label,Lottable10label
                     ,Lottable11label,Lottable12label,Lottable13label,Lottable14label,Lottable15label
                     ,Lottable01,Lottable02,Lottable03,Lottable04,Lottable05
                     ,Lottable06,Lottable07,Lottable08,Lottable09,Lottable10
                     ,Lottable11,Lottable12,Lottable13,Lottable14,Lottable15
                     ,Lottable01Code,Lottable02Code,Lottable03Code,Lottable04Code,Lottable05Code
                     ,Lottable06Code,Lottable07Code,Lottable08Code,Lottable09Code,Lottable10Code
                     ,Lottable11Code,Lottable12Code,Lottable13Code,Lottable14Code,Lottable15Code
                     ,PackUOM1,PackUOM3,CASECNT,PalletQtyInCS,PalletQtyInEA,QtyToTrfInCS,QtyToTrfInEA
                     ,TaskStatus,JobStatus)
   SELECT TOP 1 TASKDETAIL.TASKDETAILKEY
   , @c_FromID
   , @c_ToID
   , @c_FromID
   ,TransferDetail.TransferKey
   ,TransferDetail.Transferlinenumber
   ,TransferDetail.FromStorerkey  
   ,TransferDetail.FromSku  
   ,TransferDetail.ToStorerkey  
   ,TransferDetail.ToSku  
   ,Sku.Descr 
   ,Transfer.ReasonCode + ' - ' + CODELKUP.Description   
   ,SKU.Lottablecode
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
   ,ISNULL(TransferDetail.ToLottable01,'')
   ,ISNULL(TransferDetail.ToLottable02,'')
   ,ISNULL(TransferDetail.ToLottable03,'')
   ,ISNULL(TransferDetail.ToLottable04,'') 
   ,ISNULL(TransferDetail.ToLottable05,'')
   ,ISNULL(TransferDetail.ToLottable06,'')
   ,ISNULL(TransferDetail.ToLottable07,'')
   ,ISNULL(TransferDetail.ToLottable08,'')
   ,ISNULL(TransferDetail.ToLottable09,'') 
   ,ISNULL(TransferDetail.ToLottable10,'')
   ,ISNULL(TransferDetail.ToLottable11,'')
   ,ISNULL(TransferDetail.ToLottable12,'')
   ,ISNULL(TransferDetail.ToLottable13,'')
   ,ISNULL(TransferDetail.ToLottable14,'') 
   ,ISNULL(TransferDetail.ToLottable15,'')
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
   ,PACK.PackUOM1  
   ,PACK.PackUOM3   
   ,CONVERT(INT,PACK.CASECNT)
   ,0--CASE WHEN PACK.CaseCnt > 0 AND @n_ShowUOMEA = 0 THEN CONVERT(INT,FLOOR(@n_Qty / PACK.CaseCnt)) ELSE 0 END  
   ,0--CASE WHEN PACK.CaseCnt > 0 AND @n_ShowUOMEA = 0 THEN CONVERT(INT,(@n_Qty % CONVERT(INT,PACK.CaseCnt))) ELSE @n_Qty END 
   ,TRANSFERDETAIL.FromQty  
   ,TRANSFERDETAIL.FromQty   
   ,TASKDETAIL.Status
   ,@c_JobStatus
   FROM TASKDETAIL WITH (NOLOCK) 
   JOIN TRANSFERDETAIL WITH (NOLOCK) ON (TRANSFERDETAIL.Transferkey=TASKDETAIL.Sourcekey)
                                     AND(TRANSFERDETAIL.Fromid=TASKDETAIL.Fromid)
   JOIN SKU            WITH (NOLOCK) ON (TRANSFERDETAIL.ToStorerkey = SKU.Storerkey)  
                                     AND(TRANSFERDETAIL.ToSku = SKU.Sku)    
   JOIN PACK           WITH (NOLOCK) ON (SKU.PackKey = PACK.PackKey)  
   JOIN TRANSFER       WITH (NOLOCK) ON (TRANSFER.Transferkey = TRANSFERDETAIL.TransferKey) 
   LEFT JOIN CODELKUP  WITH (NOLOCK) ON (CODELKUP.ListName = 'TRNREASON')  
                                     AND(TRANSFER.ReasonCode = CODELKUP.Code)
   OUTER APPLY fnc_GetLottableCodes (SKU.Storerkey, SKU.Sku) LOTCode 
   WHERE TASKDETAIL.TaskDetailKey = @c_TaskdetailKey 
   AND   TRANSFERDETAIL.FromID = @c_FromID
   ORDER BY CASE WHEN TRANSFERDETAIL.Status = '9' AND @c_JobStatus < '5' THEN 9 ELSE 1 END
         ,  CONVERT(INT, TransferDetail.Transferlinenumber ) 
            * CASE WHEN TRANSFERDETAIL.Status = '9' THEN 1 ELSE -1 END DESC

   -- TOTAL PAllet Qty is per sku
   SET @n_Qty = 0
   SELECT @n_Qty = ISNULL(SUM(LOTxLOCxID.Qty),0)
   FROM #RESULT WITH (NOLOCK)
   JOIN LOTxLOCxID WITH (NOLOCK) ON (#RESULT.FromStorerkey = LOTxLOCxID.Storerkey)
                                 AND(#RESULT.FromSku = LOTxLOCxID.Sku)
                                 AND(#RESULT.FromID = LOTxLOCxID.ID)

   UPDATE #RESULT
   SET PalletQtyInCS = CASE WHEN CaseCnt > 0 AND @n_ShowUOMEA = 0 THEN CONVERT(INT,FLOOR(@n_Qty / CaseCnt)) ELSE 0 END 
      ,PalletQtyInEA = CASE WHEN CaseCnt > 0 AND @n_ShowUOMEA = 0 THEN CONVERT(INT,(@n_Qty % CONVERT(INT,CaseCnt))) ELSE @n_Qty END  
      ,QtyToTrfInCS  = CASE WHEN CaseCnt > 0 AND @n_ShowUOMEA = 0 THEN CONVERT(INT,FLOOR(QtyToTrfInCS / CaseCnt)) ELSE 0 END 
      ,QtyToTrfInEA  = CASE WHEN CaseCnt > 0 AND @n_ShowUOMEA = 0 THEN CONVERT(INT,(QtyToTrfInEA % CONVERT(INT,CaseCnt))) ELSE QtyToTrfInEA END    

          
   SELECT @c_JobKey,Taskdetailkey,FROMID,TOID,PalletID,TransferKey,Transferlinenumber,Storerkey,SKU,SKUDescr,TransferReason
         ,Lottable01label,Lottable02label,Lottable03label,Lottable04label,Lottable05label,
          Lottable06label,Lottable07label,Lottable08label,Lottable09label,Lottable10label,Lottable11label, 
          Lottable12label,Lottable13label,Lottable14label,Lottable15label,Lottable01,Lottable02,
          Lottable03,Lottable04,Lottable05,Lottable06,Lottable07,Lottable08,Lottable09,Lottable10,Lottable11,
          Lottable12,Lottable13,Lottable14,Lottable15,Lottable01Code,Lottable02Code,Lottable03Code,Lottable04Code,
          Lottable05Code,Lottable06Code,Lottable07Code,Lottable08Code,Lottable09Code,Lottable10Code,Lottable11Code,
          Lottable12Code,Lottable13Code,Lottable14Code,Lottable15Code,
          PackUOM1,PackUOM3,CASECNT,PalletQtyInCS,PalletQtyInEA,QtyToTrfInCS,QtyToTrfInEA,TaskStatus,JobStatus
   FROM #Result 
END       

GO
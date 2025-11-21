SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_GetKIOSKASRSCCTask_b                           */
/* Creation Date: 2015-01-21                                            */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: SOS#315474 - Project Merlion - Exceed GTM Kiosk Module      */
/*                                                                      */
/* Called By: r_dw_kiosk_asrscc_form                                    */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 15-APR-2016  Leong   1.1   IN00020776 - include additional column.   */
/************************************************************************/

CREATE PROC [dbo].[isp_GetKIOSKASRSCCTask_b]
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

   DECLARE @c_CCKey                 NVARCHAR(10)
         , @c_CCDetailKey           NVARCHAR(10)
         , @c_CCSheetNo             NVARCHAR(10)
         , @n_CCSheetTTLCnt         INT
         , @n_CCSheetRemainingCnt   INT
         , @n_PalletTTLCntLine      INT
         , @n_PalletCntLine         INT
         , @c_FinalPallet           NVARCHAR(1)
         , @n_CountNo               INT
         , @c_WithQuantity          NVARCHAR(1)
         , @c_packuom1              NVARCHAR(10)
         , @c_packuom3              NVARCHAR(10)
         , @n_casecnt               INT
         , @n_Pqty                  INT
         , @n_ttlqtyineaincs        INT
         , @n_ttlqtyinea            INT
         , @c_lottablecode          NVARCHAR(30)
         , @c_lottable01code        NVARCHAR(3)
         , @c_lottable02code        NVARCHAR(3)
         , @c_lottable03code        NVARCHAR(3)
         , @c_lottable04code        NVARCHAR(3)
         , @c_lottable05code        NVARCHAR(3)
         , @c_lottable06code        NVARCHAR(3)
         , @c_lottable07code        NVARCHAR(3)
         , @c_lottable08code        NVARCHAR(3)
         , @c_lottable09code        NVARCHAR(3)
         , @c_lottable10code        NVARCHAR(3)
         , @c_lottable11code        NVARCHAR(3)
         , @c_lottable12code        NVARCHAR(3)
         , @c_lottable13code        NVARCHAR(3)
         , @c_lottable14code        NVARCHAR(3)
         , @c_lottable15code        NVARCHAR(3)
         , @c_Storerkey             NVARCHAR(15)
         , @c_Sku                   NVARCHAR(20)
         , @c_JobStatus             NVARCHAR(10)
         , @n_DefaultQty            INT
         , @n_ShowUOMEA             INT

   SET @c_CCKey              = ''
   SET @c_CCDetailKey        = ''
   SET @c_CCSheetNo          = ''
   SET @n_CCSheetRemainingCnt= 0
   SET @n_PalletTTLCntLine   = 0
   SET @n_PalletCntLine      = 0
   SET @c_FinalPallet        = 'N'
   SET @n_CountNo            = 0
   SET @c_WithQuantity       = 'Y'
   SET @n_ttlqtyineaincs     = 0
   SET @n_ttlqtyinea         = 0
   SET @c_lottable01code     = ''
   SET @c_lottable02code     =''
   SET @c_lottable03code     =''
   SET @c_lottable04code     =''
   SET @c_lottable05code     =''
   SET @c_lottable06code     =''
   SET @c_lottable07code     =''
   SET @c_lottable08code     =''
   SET @c_lottable09code     =''
   SET @c_lottable10code     =''
   SET @c_lottable11code     =''
   SET @c_lottable12code     =''
   SET @c_lottable13code     =''
   SET @c_lottable14code     =''
   SET @c_lottable15code     =''

   CREATE TABLE #CCDETAIL (
         [No]        [INT] IDENTITY(1,1) NOT NULL
      ,  CCKEY       NVARCHAR(10)   NULL
      ,  CCDETAILKEY NVARCHAR(10)   NULL
      ,  CCSHEETNO   NVARCHAR(10)   NULL
      ,  CCSTATUS    NVARCHAR(10)   NULL
      ,  CCSystemQty INT            NULL
      ,  CCQty       INT            NULL
      ,  CCQTY_CNT2  INT            NULL
      ,  CCQty_CNT3  INT            NULL
      )

   CREATE TABLE #Result (
         [ID]                 [INT] IDENTITY(1,1) NOT NULL
      ,  TASKDETAILKEY        NVARCHAR(10)   NULL
      ,  TaskStatus           NVARCHAR(10)   NULL  DEFAULT ('0')
      ,  PALLETID             NVARCHAR(18)   NULL
      ,  CCKEY                NVARCHAR(10)   NULL
      ,  CCDetailKey          NVARCHAR(10)   NULL
      ,  CCSheetNo            NVARCHAR(10)   NULL
      ,  CountNo              INT            NULL
      ,  CCSheetTTLCnt        INT            NULL
      ,  CCSheetRemainingCnt  INT            NULL
      ,  PalletTTLCntLine     INT            NULL
      ,  PalletCntLine        INT            NULL
      ,  WithQuantity         NVARCHAR(1)    NULL DEFAULT ('Y')
      ,  Storerkey            NVARCHAR(10)   NULL
      ,  SKU                  NVARCHAR(20)   NULL
      ,  SKUDescr             NVARCHAR(120)  NULL
      ,  Lottablecode         NVARCHAR(30)   NULL
      ,  Lottable01Label      NVARCHAR(20)   NULL
      ,  Lottable02Label      NVARCHAR(20)   NULL
      ,  Lottable03Label      NVARCHAR(20)   NULL
      ,  Lottable04Label      NVARCHAR(20)   NULL
      ,  Lottable05Label      NVARCHAR(20)   NULL
      ,  Lottable06Label      NVARCHAR(20)   NULL
      ,  Lottable07Label      NVARCHAR(20)   NULL
      ,  Lottable08Label      NVARCHAR(20)   NULL
      ,  Lottable09Label      NVARCHAR(20)   NULL
      ,  Lottable10Label      NVARCHAR(20)   NULL
      ,  Lottable11Label      NVARCHAR(20)   NULL
      ,  Lottable12Label      NVARCHAR(20)   NULL
      ,  Lottable13Label      NVARCHAR(20)   NULL
      ,  Lottable14Label      NVARCHAR(20)   NULL
      ,  Lottable15Label      NVARCHAR(20)   NULL
      ,  Lottable01           NVARCHAR(18)   NULL
      ,  Lottable02           NVARCHAR(18)   NULL
      ,  Lottable03           NVARCHAR(18)   NULL
      ,  Lottable04           DATETIME       NULL
      ,  Lottable05           DATETIME       NULL
      ,  Lottable06           NVARCHAR(30)   NULL
      ,  Lottable07           NVARCHAR(30)   NULL
      ,  Lottable08           NVARCHAR(30)   NULL
      ,  Lottable09           NVARCHAR(30)   NULL
      ,  Lottable10           NVARCHAR(30)   NULL
      ,  Lottable11           NVARCHAR(30)   NULL
      ,  Lottable12           NVARCHAR(30)   NULL
      ,  Lottable13           DATETIME       NULL
      ,  Lottable14           DATETIME       NULL
      ,  Lottable15           DATETIME       NULL
      ,  Lottable01Code       NVARCHAR(3)    NULL
      ,  Lottable02Code       NVARCHAR(3)    NULL
      ,  Lottable03Code       NVARCHAR(3)    NULL
      ,  Lottable04Code       NVARCHAR(3)    NULL
      ,  Lottable05Code       NVARCHAR(3)    NULL
      ,  Lottable06Code       NVARCHAR(3)    NULL
      ,  Lottable07Code       NVARCHAR(3)    NULL
      ,  Lottable08Code       NVARCHAR(3)    NULL
      ,  Lottable09Code       NVARCHAR(3)    NULL
      ,  Lottable10Code       NVARCHAR(3)    NULL
      ,  Lottable11Code       NVARCHAR(3)    NULL
      ,  Lottable12Code       NVARCHAR(3)    NULL
      ,  Lottable13Code       NVARCHAR(3)    NULL
      ,  Lottable14Code       NVARCHAR(3)    NULL
      ,  Lottable15Code       NVARCHAR(3)    NULL
      ,  PACKUOM1             NVARCHAR(10)   NULL
      ,  PACKUOM3             NVARCHAR(10)   NULL
      ,  CASECNT              INT            NULL
      ,  PQty                 INT            NULL
      ,  TTLQtyInCS           INT            NULL
      ,  TTLQtyInEA           INT            NULL
      ,  CountedQtyInCS       INT            NULL  DEFAULT (0)
      ,  CountedQtyInEA       INT            NULL  DEFAULT (0)
      ,  FinalCtnFlag         CHAR(1)
      ,  JobStatus            NVARCHAR(10)
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
   AND   Code2    = 'ASRSCC'
   AND   Storerkey= @c_Storerkey
   AND   (Short = 'Y' OR Short IS NULL OR Short = '')

   INSERT INTO #Result (TaskDetailKey,TaskStatus,PalletID,CCKey,CCDetailKey,CCSheetNo,CountNo,WithQuantity
                     ,Storerkey,SKU,SKUDescr
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
                     ,PackUOM1,PackUOM3,CASECNT,PQty
                     ,CountedQtyInCS,CountedQtyInEA,FinalCtnFlag,JobStatus)
   SELECT TOP 1 TASKDETAIL.TASKDETAILKEY
   ,TASKDETAIL.Status
   ,CCDETAIL.ID
   ,CCDETAIL.CCKEY
   ,CCDETAIL.CCDetailKey
   ,CCDETAIL.CCSHEETNO
   ,(STSP.FINALIZESTAGE + 1) AS COUNTNO
   , STSP.WithQuantity
   ,CCDETAIL.Storerkey
   ,CCDETAIL.Sku
   ,SKU.Descr
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
   ,ISNULL(CCDETAIL.Lottable01,'')
   ,ISNULL(CCDETAIL.Lottable02,'')
   ,ISNULL(CCDETAIL.Lottable03,'')
   ,ISNULL(CCDETAIL.Lottable04,'')
   ,ISNULL(CCDETAIL.Lottable05,'')
   ,ISNULL(CCDETAIL.Lottable06,'')
   ,ISNULL(CCDETAIL.Lottable07,'')
   ,ISNULL(CCDETAIL.Lottable08,'')
   ,ISNULL(CCDETAIL.Lottable09,'')
   ,ISNULL(CCDETAIL.Lottable10,'')
   ,ISNULL(CCDETAIL.Lottable11,'')
   ,ISNULL(CCDETAIL.Lottable12,'')
   ,ISNULL(CCDETAIL.Lottable13,'')
   ,ISNULL(CCDETAIL.Lottable14,'')
   ,ISNULL(CCDETAIL.Lottable15,'')
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
   ,PACK.CASECNT
   ,PACK.Qty
   ,0
   ,0
   ,'N'
   ,@c_JobStatus
   FROM TASKDETAIL WITH (NOLOCK)
   JOIN CCDetail   WITH (NOLOCK) ON (CCDETAIL.ID = TASKDETAIL.Fromid)
                                 AND(CCDetail.CCkey = TASKDETAIL.dropid)
   JOIN SKU        WITH (NOLOCK) ON (CCDETAIL.Storerkey = SKU.Storerkey)
                                 AND(CCDETAIL.Sku = SKU.Sku)
   JOIN PACK       WITH (NOLOCK) ON (SKU.PackKey = PACK.PackKey)
   JOIN StockTakeSheetParameters STSP WITH (NOLOCK) ON (STSP.stocktakekey =CCDETAIL.cckey)
   OUTER APPLY fnc_GetLottableCodes (SKU.Storerkey, SKU.Sku) LOTCode
   WHERE TASKDETAIL.TaskDetailKey = @c_TaskdetailKey
   AND   ISNULL(FromID,'') = @c_ID
   AND   CCDETAIL.Counted_Cnt1 >= CASE STSP.FinalizeStage WHEN 0 THEN '0' ELSE CCDETAIL.Counted_Cnt1 END
   AND   CCDETAIL.Counted_Cnt2 >= CASE STSP.FinalizeStage WHEN 1 THEN '0' ELSE CCDETAIL.Counted_Cnt2 END
   AND   CCDETAIL.Counted_Cnt3 >= CASE STSP.FinalizeStage WHEN 2 THEN '0' ELSE CCDETAIL.Counted_Cnt3 END
   AND   CCDETAIL.Status < '9'
   AND   CCDETAIL.SystemQty <> CASE STSP.FinalizeStage WHEN 0 THEN -99999
                                                       WHEN 1 THEN CCDETAIL.Qty
                                                       WHEN 2 THEN CCDETAIL.Qty_Cnt2
                                                       END
   ORDER BY CASE WHEN FinalizeStage = 0 AND CCDETAIL.Counted_Cnt1 = '1' AND @c_JobStatus < '5' THEN 5
                 WHEN FinalizeStage = 1 AND CCDETAIL.Counted_Cnt2 = '1' AND @c_JobStatus < '5' THEN 5
                 WHEN FinalizeStage = 2 AND CCDETAIL.Counted_Cnt3 = '1' AND @c_JobStatus < '5' THEN 5
                 ELSE 0
                 END
         ,  CONVERT(INT, CCDETAIL.CCDetailkey) *
            CASE WHEN FinalizeStage = 0 AND CCDETAIL.Counted_Cnt1 = 1 THEN 1
                 WHEN FinalizeStage = 1 AND CCDETAIL.Counted_Cnt2 = 1 THEN 1
                 WHEN FinalizeStage = 2 AND CCDETAIL.Counted_Cnt3 = 1 THEN 1
                 ELSE -1
                 END DESC

   SELECT  @c_CCKey=cckey
         , @c_CCDetailKey=CCDetailKey
         , @c_CCSheetNo=CCSheetNo
         , @n_CountNo = CountNo
         , @c_WithQuantity = WithQuantity
         , @n_Casecnt = convert(int,casecnt)
         , @n_pqty   = convert(int,pqty)
         , @c_lottableCode = Lottablecode
         , @c_Storerkey = Storerkey
         , @c_Sku       = Sku
   FROM #result WITH (NOLOCK)

   INSERT INTO #CCDETAIL(CCKEY,CCDETAILKEY,CCSHEETNO,CCSTATUS,CCSystemQty,CCQty,CCQty_CNT2, CCQty_CNT3)
   SELECT  CCDETAIL.CCKEY,CCDETAIL.CCDETAILKEY,CCDETAIL.CCSHEETNO,CCDETAIL.Status,CCDETAIL.Systemqty,CCDETAIL.Qty,CCDETAIL.Qty_Cnt2,CCDETAIL.Qty_Cnt3
   FROM CCDetail WITH (NOLOCK)
   WHERE CCKey=@c_CCKey
   AND   CCDetailKey = @c_CCDetailKey
   AND   ID = @c_ID

   SELECT @n_CCSheetTTLCnt = COUNT(1)
   FROM CCDETAIL WITH (NOLOCK)
   WHERE CCKEY   = @c_CCKey
   AND CCSheetNo = @c_CCSheetNo
   AND Status < '9'
   AND   CCDETAIL.SystemQty <> CASE @n_CountNo WHEN 1 THEN -99999
                                               WHEN 2 THEN CCDETAIL.Qty
                                               WHEN 3 THEN CCDETAIL.Qty_Cnt2
                                               END

   SELECT @n_CCSheetRemainingCnt = COUNT(1)
   FROM CCDETAIL WITH (NOLOCK)
   WHERE CCKEY = @c_CCKey
   AND CCSheetNo = @c_CCSheetNo
   AND   Counted_Cnt1 = CASE @n_CountNo WHEN 1 THEN '0' ELSE Counted_Cnt1 END
   AND   Counted_Cnt2 = CASE @n_CountNo WHEN 2 THEN '0' ELSE Counted_Cnt2 END
   AND   Counted_Cnt3 = CASE @n_CountNo WHEN 3 THEN '0' ELSE Counted_Cnt3 END
   AND   Status < '9'
   AND   CCDETAIL.SystemQty <> CASE @n_CountNo WHEN 1 THEN -99999
                                               WHEN 2 THEN CCDETAIL.Qty
                                               WHEN 3 THEN CCDETAIL.Qty_Cnt2
                                               END

   SELECT @n_PalletTTLCntLine = COUNT(1)
   FROM CCDETAIL WITH (NOLOCK)
   WHERE CCKEY = @c_CCKey
   AND CCSheetNo = @c_CCSheetNo
   AND ID = @c_ID
   AND Status < '9'
   AND   CCDETAIL.SystemQty <> CASE @n_CountNo WHEN 1 THEN -99999
                                               WHEN 2 THEN CCDETAIL.Qty
                                               WHEN 3 THEN CCDETAIL.Qty_Cnt2
                                               END

   SELECT @n_PalletCntLine = COUNT(1)
   FROM CCDETAIL WITH (NOLOCK)
   WHERE CCKEY = @c_CCKey
   AND CCSheetNo = @c_CCSheetNo
   AND ID = @c_ID
   AND   Counted_Cnt1 = CASE @n_CountNo WHEN 1 THEN '1' ELSE Counted_Cnt1 END
   AND   Counted_Cnt2 = CASE @n_CountNo WHEN 2 THEN '1' ELSE Counted_Cnt2 END
   AND   Counted_Cnt3 = CASE @n_CountNo WHEN 3 THEN '1' ELSE Counted_Cnt3 END
   AND   Status < '9'
   AND   CCDETAIL.SystemQty <> CASE @n_CountNo WHEN 1 THEN -99999
                                               WHEN 2 THEN CCDETAIL.Qty
        WHEN 3 THEN CCDETAIL.Qty_Cnt2
                                               END

   SET @n_CCSheetRemainingCnt = CASE WHEN @n_CCSheetRemainingCnt > 0 THEN @n_CCSheetRemainingCnt - 1 ELSE 0 END
   SET @n_PalletCntLine = @n_PalletCntLine + CASE @n_PalletCntLine WHEN @n_PalletTTLCntLine THEN 0 ELSE 1 END

   SET @n_ttlqtyineaincs = 0
   SET @n_ttlqtyinea     = 0

   IF @c_WithQuantity = 'Y'
   BEGIN
      SELECT @n_ttlqtyineaincs = CASE WHEN @n_CountNo = 1 AND @n_ShowUOMEA = 0 AND @n_casecnt > 0 THEN FLOOR(CCSystemQty / @n_casecnt)
                                      WHEN @n_CountNo = 2 AND @n_ShowUOMEA = 0 AND @n_casecnt > 0 THEN FLOOR(CCQty / @n_casecnt)
                                      WHEN @n_CountNo = 3 AND @n_ShowUOMEA = 0 AND @n_casecnt > 0 THEN FLOOR(CCQty_Cnt2 / @n_casecnt) END
           , @n_ttlqtyinea     = CASE WHEN @n_CountNo = 1 AND @n_ShowUOMEA = 0 AND @n_casecnt > 0 THEN (CCSystemQty % @n_casecnt)
                                      WHEN @n_CountNo = 2 AND @n_ShowUOMEA = 0 AND @n_casecnt > 0 THEN (CCQty % @n_casecnt)
                                      WHEN @n_CountNo = 3 AND @n_ShowUOMEA = 0 AND @n_casecnt > 0 THEN (CCQty_Cnt2 % @n_casecnt)
                                      WHEN @n_CountNo = 1 AND (@n_ShowUOMEA = 1 OR @n_casecnt = 0) THEN CCSystemQty
                                      WHEN @n_CountNo = 2 AND (@n_ShowUOMEA = 1 OR @n_casecnt = 0) THEN CCQty
                                      WHEN @n_CountNo = 3 AND (@n_ShowUOMEA = 1 OR @n_casecnt = 0) THEN CCQty_Cnt2
                                      END
      FROM #CCDETAIL WITH (NOLOCK)
   END

   UPDATE #RESULT
   SET CCSheetTTLCnt       = @n_CCSheetTTLCnt
     , CCSheetRemainingCnt = @n_CCSheetRemainingCnt
     , PalletTTLCntLine    = @n_PalletTTLCntLine
     , PalletCntLine       = @n_PalletCntLine
     , FinalCtnflag        = @c_FinalPallet
     , TTLQtyInCS          = ISNULL(@n_ttlqtyineaincs,0)
     , TTLQtyInEA          = ISNULL(@n_ttlqtyinea,0)
     , CountedQtyInCS      = CASE WHEN @n_DefaultQty = 0 THEN 0 ELSE @n_ttlqtyineaincs END
     , CountedQtyInEA      = CASE WHEN @n_DefaultQty = 0 THEN 0 ELSE @n_ttlqtyinea END

   SELECT @c_JobKey
         ,Taskdetailkey,TaskStatus,PalletID,CCkey,CCDetailkey,CCSheetNo,CountNo,CCSheetRemainingCnt
         ,CCSheetTTLCnt,PalletTTLCntLine,PalletCntLine
         ,Storerkey,SKU,SKUDescr
         ,Lottable01label,Lottable02label,Lottable03label,Lottable04label,Lottable05label
         ,Lottable06label,Lottable07label,Lottable08label,Lottable09label,Lottable10label
         ,Lottable11label,Lottable12label,Lottable13label,Lottable14label,Lottable15label
         ,Lottable01,Lottable02,Lottable03,Lottable04,Lottable05
         ,Lottable06,Lottable07,Lottable08,Lottable09,Lottable10
         ,Lottable11,Lottable12,Lottable13,Lottable14,Lottable15
         ,Lottable01Code,Lottable02Code,Lottable03Code,Lottable04Code,Lottable05Code
         ,Lottable06Code,Lottable07Code,Lottable08Code,Lottable09Code,Lottable10Code
         ,Lottable11Code,Lottable12Code,Lottable13Code,Lottable14Code,Lottable15Code
         ,PackUOM1,PackUOM3,casecnt,pqty,TTLQtyInCS,TTLQtyInEA,CountedQtyInCS,CountedQtyInEA
         ,FinalCtnFlag,JobStatus
         ,PalletID -- IN00020776
   FROM #Result
END

GO
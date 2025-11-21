SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc : isp_CCPostingByAdjustment_UCC                          */
/* Copyright: IDS                                                       */
/*                                                                      */
/* Purpose: Stock Take (Cycle Count) Posting by Adjustment at UCC level */
/*          Note: This SP is for general use but excluding TBL.         */
/*                TBL is calling isp_AdjustStock_TBL.                   */
/*                                                                      */
/* Called from: 3                                                       */
/*    1. From PowerBuilder                                              */
/*    2. From scheduler                                                 */
/*    3. From others stored procedures or triggers                      */
/*    4. From interface program. DX, DTS                                */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 01-Aug-2006 1.0  MaryVong    Created                                 */
/* 03-Feb-2012 1.1  Ung         SOS235498 support edit UCC.QTY          */
/* 01-Mar-2012 1.2  Shong       Passing PackKey and PackUOM3 to ItrnAdd */
/* 21-Jun-2012 1.3  Ung         SOS227151 - TM RDT CC                   */
/* 27-Aug-2012 1.4  Ung         Fix Adjustment.DocType = 'U'            */
/* 19-Oct-2012 1.5  Ung         SOS254691 Fix UCC.Status                */
/* 17-Dec-2012 1.6  James       Set UCC status (james01)                */
/*                              Get UCCNo from UCCNo column             */
/*                              instead of userdefine01                 */
/* 24-Sep-2013  YTWan     1.2 SOS#290122-Add Sku to UCC Checking.       */
/*                            (for Multisku)(Wan01)                     */
/* 21-Oct-2013 1.8  James       Bug fix (james02)                       */
/* 07-May-2014 1.9  TKLIM       Added Lottables 06-15                   */
/* 12-Oct-2015 2.0  Leong       SOS# 354719 - Bug fix.                  */
/* 07-Feb-2018 2.1  SWT02       Adding Paramater Variable to Calling SP */
/* 22-Nov-2023 2.2  NJOW01      WMS-23053 Move adj qty to other loc     */
/*                              before adj                              */
/* 22-Nov-2023 2.2  NJOW01      DEVOPS Combine Script                   */
/* 22-JAN-2024 2.3  NJOW02      WMS-24558 Add post CC adjustment call   */
/*                              custom sp                               */
/************************************************************************/

CREATE   PROCEDURE [dbo].[isp_CCPostingByAdjustment_UCC]
   @c_CCKey    NVARCHAR(10),
   @b_success  INT  OUTPUT,
   @c_TaskDetailKey NVARCHAR(10) = ''   -- From RDT
AS
BEGIN -- main
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE
      @n_starttCnt      INT,
      @n_continue       INT,
      @n_err            INT,
      @c_errmsg         NVARCHAR(250),
      @b_debug          INT

   DECLARE
      @c_CCDetailKey    NVARCHAR(10),
      @c_PrevStorerKey  NVARCHAR(18),
      @c_PrevFacility   NVARCHAR(5),
      @c_StorerKey      NVARCHAR(18),
      @c_Facility       NVARCHAR(5),
      @c_AdjustmentKey  NVARCHAR(10),
      @c_UCCAdjustmentKey NVARCHAR(10),
      @n_FinalizeStage  INT,
      @c_Status         NVARCHAR(10),
      @c_UCC            NVARCHAR(20),
      @c_SKU            NVARCHAR(20),
      @n_SystemQty      INT,
      @c_LOT            NVARCHAR(10),
      @c_LOC            NVARCHAR(10),
      @c_ID             NVARCHAR(18),
      @n_CntQty         INT,
      @c_Lottable01     NVARCHAR(18),
      @c_Lottable02     NVARCHAR(18),
      @c_Lottable03     NVARCHAR(18),
      @d_Lottable04     DATETIME,
      @d_Lottable05     DATETIME,
      @c_Lottable06     NVARCHAR(30),
      @c_Lottable07     NVARCHAR(30),
      @c_Lottable08     NVARCHAR(30),
      @c_Lottable09     NVARCHAR(30),
      @c_Lottable10     NVARCHAR(30),
      @c_Lottable11     NVARCHAR(30),
      @c_Lottable12     NVARCHAR(30),
      @d_Lottable13     DATETIME,
      @d_Lottable14     DATETIME,
      @d_Lottable15     DATETIME,
      @d_Today          DATETIME,
      @c_SourceKey      NVARCHAR(20),
      @c_OldSKU         NVARCHAR(20),
      @n_OldQty         INT,
      @c_OldLOT         NVARCHAR(10),
      @c_OldLOC         NVARCHAR(10),
      @c_OldID          NVARCHAR(18),
      @c_OldStorer      NVARCHAR(18),
      @c_AdjType        NVARCHAR(3),
      @c_AdjReasonCode  NVARCHAR(10),
      @c_Remarks        NVARCHAR(30),
      @c_PackKey        NVARCHAR(10),
      @c_PackUOM3       NVARCHAR(10),
      @cUserDefine01    NVARCHAR(20),
      @cUserDefine02    NVARCHAR(20),
      @cUserDefine03    NVARCHAR(20),
      @c_CCMoveAdjQtyToLoc  NVARCHAR(10)='', --NJOW01
      @c_Hostwhcode_UDF01   NVARCHAR(10)='', --NJOW01
      @n_MoveQty            INT, --NJOW01
      @n_AdjQty             INT, --NJOW01
      @c_FinalAdjustmentKey NVARCHAR(10), --NJOW01
      @c_AdjLoc             NVARCHAR(10) --NJOW01
      
   SET @b_success = 1 -- 1=Success
   SELECT @n_starttCnt = @@TRANCOUNT

   DECLARE @tAdjustment TABLE (AdjustmentKey NVARCHAR(10))

   SET @c_Remarks = 'Stock Take Posting by Adjustment (UCC level)'

   -- Clean up tracking table
   DELETE CCDetail_B4Post WHERE CCKey = @c_CCKey
   DELETE LotxLocxid_B4Post WHERE CCKey = @c_CCKey

   -- Backup records before posting
   INSERT INTO CCDetail_B4Post -- SOS# 354719
      ( CCKey
      , CCDetailKey
      , CCSheetNo
      , TagNo
      , Storerkey
      , Sku
      , Lot
      , Loc
      , Id
      , SystemQty
      , Qty
      , Lottable01
      , Lottable02
      , Lottable03
      , Lottable04
      , Lottable05
      , FinalizeFlag
      , Qty_Cnt2
      , Lottable01_Cnt2
      , Lottable02_Cnt2
      , Lottable03_Cnt2
      , Lottable04_Cnt2
      , Lottable05_Cnt2
      , FinalizeFlag_Cnt2
      , Qty_Cnt3
      , Lottable01_Cnt3
      , Lottable02_Cnt3
      , Lottable03_Cnt3
      , Lottable04_Cnt3
      , Lottable05_Cnt3
      , FinalizeFlag_Cnt3
      , Status
      , StatusMsg
      , AddDate
      , AddWho
      , EditDate
      , EditWho
      , TrafficCop
      , ArchiveCop
      , Timestamp
      , RefNo
      , EditDate_Cnt1
      , EditWho_Cnt1
      , EditDate_Cnt2
      , EditWho_Cnt2
      , EditDate_Cnt3
      , EditWho_Cnt3
      , Counted_Cnt1
      , Counted_Cnt2
      , Counted_Cnt3
      , Lottable06
      , Lottable07
      , Lottable08
      , Lottable09
      , Lottable10
      , Lottable11
      , Lottable12
      , Lottable13
      , Lottable14
      , Lottable15
      , Lottable06_Cnt2
      , Lottable07_Cnt2
      , Lottable08_Cnt2
      , Lottable09_Cnt2
      , Lottable10_Cnt2
      , Lottable11_Cnt2
      , Lottable12_Cnt2
      , Lottable13_Cnt2
      , Lottable14_Cnt2
      , Lottable15_Cnt2
      , Lottable06_Cnt3
      , Lottable07_Cnt3
      , Lottable08_Cnt3
      , Lottable09_Cnt3
      , Lottable10_Cnt3
      , Lottable11_Cnt3
      , Lottable12_Cnt3
      , Lottable13_Cnt3
      , Lottable14_Cnt3
      , Lottable15_Cnt3
      )
    SELECT CCKey
         , CCDetailKey
         , CCSheetNo
         , TagNo
         , Storerkey
         , Sku
         , Lot
         , Loc
         , Id
         , SystemQty
         , Qty
         , Lottable01
         , Lottable02
         , Lottable03
         , Lottable04
         , Lottable05
         , FinalizeFlag
         , Qty_Cnt2
         , Lottable01_Cnt2
         , Lottable02_Cnt2
         , Lottable03_Cnt2
         , Lottable04_Cnt2
         , Lottable05_Cnt2
         , FinalizeFlag_Cnt2
         , Qty_Cnt3
         , Lottable01_Cnt3
         , Lottable02_Cnt3
         , Lottable03_Cnt3
         , Lottable04_Cnt3
         , Lottable05_Cnt3
         , FinalizeFlag_Cnt3
         , Status
         , StatusMsg
         , AddDate
         , AddWho
         , EditDate
         , EditWho
         , TrafficCop
         , ArchiveCop
         , Timestamp
         , RefNo
         , EditDate_Cnt1
         , EditWho_Cnt1
         , EditDate_Cnt2
         , EditWho_Cnt2
         , EditDate_Cnt3
         , EditWho_Cnt3
         , Counted_Cnt1
         , Counted_Cnt2
         , Counted_Cnt3
         , Lottable06
         , Lottable07
         , Lottable08
         , Lottable09
         , Lottable10
         , Lottable11
         , Lottable12
         , Lottable13
         , Lottable14
         , Lottable15
         , Lottable06_Cnt2
         , Lottable07_Cnt2
         , Lottable08_Cnt2
         , Lottable09_Cnt2
         , Lottable10_Cnt2
         , Lottable11_Cnt2
         , Lottable12_Cnt2
         , Lottable13_Cnt2
         , Lottable14_Cnt2
         , Lottable15_Cnt2
         , Lottable06_Cnt3
         , Lottable07_Cnt3
         , Lottable08_Cnt3
         , Lottable09_Cnt3
         , Lottable10_Cnt3
         , Lottable11_Cnt3
         , Lottable12_Cnt3
         , Lottable13_Cnt3
         , Lottable14_Cnt3
         , Lottable15_Cnt3
   FROM CCDetail WITH (NOLOCK) WHERE CCKey = @c_CCKey

   INSERT INTO LOTxLOCxID_B4Post -- SOS# 354719
      ( CCKey
      , Lot
      , Loc
      , Id
      , StorerKey
      , Sku
      , Qty
      , QtyAllocated
      , QtyPicked
      , QtyExpected
      , QtyPickInProcess
      , PendingMoveIN
      , ArchiveQty
      , ArchiveDate
      , TrafficCop
      , ArchiveCop
      , QtyReplen
      , EditWho
      , EditDate )
   SELECT
        @c_CCKey
      , Lot
      , Loc
      , Id
      , StorerKey
      , Sku
      , Qty
      , QtyAllocated
      , QtyPicked
      , QtyExpected
      , QtyPickInProcess
      , PendingMoveIN
      , ArchiveQty
      , ArchiveDate
      , TrafficCop
      , ArchiveCop
      , QtyReplen
      , EditWho
      , EditDate
   FROM LOTxLOCxID WITH (NOLOCK)
   WHERE EXISTS (SELECT TOP 1 1 FROM CCDetail WITH (NOLOCK) WHERE CCKey = @c_CCKey AND CCDetail.LOC = LOTxLOCxID.LOC)
   
   --NJOW01
   SELECT TOP 1 @c_CCMoveAdjQtyToLoc = LOC.Loc,
                @c_Hostwhcode_UDF01 = CL.UDF01
   FROM STOCKTAKESHEETPARAMETERS SP (NOLOCK)
   JOIN CODELKUP CL (NOLOCK) ON SP.StorerKey = CL.Storerkey   --not support stock take with multiple storer  
   JOIN LOC (NOLOCK) ON CL.Code = LOC.Loc
   WHERE SP.StockTakeKey = @c_CCKey
   AND CL.ListName = 'CCADJMVLOC'
   
   DECLARE @n_IsRDT Int
   EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT
--set @n_IsRDT = 1
   IF @n_IsRDT = 1
      SELECT
         @n_FinalizeStage = 1
   ELSE
   BEGIN
      -- Get FinalizeStage, AdjustmentType and ReasonCode
      SELECT
         @n_FinalizeStage = FinalizeStage,
         @c_AdjType       = AdjType,
         @c_AdjReasonCode = AdjReasonCode
      FROM StockTakeSheetParameters WITH (NOLOCK)
      WHERE StockTakeKey = @c_CCKey

      -- Clean up error report
      DELETE dbo.StockTakeErrorReport WITH (ROWLOCK) WHERE StockTakeKey = @c_CCKey

      -- Check duplicte UCC
      DECLARE @cTitlePrinted NVARCHAR(1)
      DECLARE @cDupUCCNo NVARCHAR( 20)
      DECLARE @curDupUCC CURSOR
      SET @cTitlePrinted = 'N'
      SET @curDupUCC = CURSOR FOR
         SELECT RefNo
         FROM dbo.CCDetail WITH (NOLOCK)
         WHERE CCKey = @c_CCKey
            AND RefNo <> ''
            AND Status IN ('2', '4')
         GROUP BY RefNo
         HAVING COUNT( DISTINCT Status) > 1
      OPEN @curDupUCC
      FETCH NEXT FROM @curDupUCC INTO @cDupUCCNo
      WHILE @@FETCH_STATUS = 0
      BEGIN
         IF @cTitlePrinted = 'N'
            --(Wan03) - START
            AND EXISTS (SELECT 1
                        FROM dbo.CCDetail DUP WITH (NOLOCK)
                        WHERE DUP.CCKey = @c_CCKey
                        AND DUP.RefNo = @cDupUCCNo
                        GROUP BY DUP.Storerkey
                              ,  DUP.Sku
                        HAVING COUNT(DISTINCT DUP.Status) > 1)
            --(Wan03) - END
         BEGIN
            INSERT INTO dbo.StockTakeErrorReport (StockTakeKey, ErrorNo, Type, LineText) VALUES (@c_CCKey, '', 'ERROR', REPLICATE( '-', 80))
            INSERT INTO dbo.StockTakeErrorReport (StockTakeKey, ErrorNo, Type, LineText) VALUES (@c_CCKey, '', 'ERROR', 'DUPLICATE UCC: ' + @cDupUCCNo)
            INSERT INTO dbo.StockTakeErrorReport (StockTakeKey, ErrorNo, Type, LineText) VALUES (@c_CCKey, '', 'ERROR', 'CCDETAILKEY  LOC         SKU')
            INSERT INTO dbo.StockTakeErrorReport (StockTakeKey, ErrorNo, Type, LineText) VALUES (@c_CCKey, '', 'ERROR', '-----------  ----------  --------------------')
            SET @cTitlePrinted = 'Y'
         END

         INSERT INTO dbo.StockTakeErrorReport (StockTakeKey, ErrorNo, Type, LineText)
         SELECT @c_CCKey, '', 'ERROR', CCDetailKey + '  ' + LOC + '  ' + SKU
         FROM dbo.CCDetail WITH (NOLOCK)
         WHERE CCKey = @c_CCKey
            AND RefNo = @cDupUCCNo
            --(Wan01) - START
            AND EXISTS (SELECT 1
                        FROM dbo.CCDetail DUP WITH (NOLOCK)
                        WHERE DUP.CCKey = CCDetail.CCKey
             AND DUP.RefNo = CCDetail.RefNo
                        AND DUP.Sku   = CCDetail.Sku
                        GROUP BY DUP.Storerkey
                              ,  DUP.Sku
                        HAVING COUNT(DISTINCT DUP.Status) > 1)
            --(Wan01) - END
         FETCH NEXT FROM @curDupUCC INTO @cDupUCCNo
      END

      -- Check any error in report
      IF EXISTS( SELECT TOP 1 1 FROM dbo.StockTakeErrorReport WITH (NOLOCK) WHERE StockTakeKey = @c_CCKey)
         RETURN
   END


   SELECT @c_CCDetailKey = ''
   SELECT @c_PrevStorerKey = ''
   SELECT @c_PrevFacility = ''

   DECLARE CCDET_CUR CURSOR READ_ONLY FAST_FORWARD FOR
      SELECT
         CCDetailKey,
         StorerKey,
         SKU,
         RefNo,   -- UCCNo
         LOT,
         C.LOC,
         ID,
         Facility,
         C.Status,
         CASE WHEN C.Status = '4' THEN 0
--              WHEN C.RefNo <> '' THEN
--               (SELECT QTY FROM dbo.UCC WITH (NOLOCK) WHERE C.RefNo = UCCNo AND C.StorerKey = StorerKey)
              WHEN C.SystemQTY = 0 THEN
              /*
                  1. blank count sheet, systemqty = 0
                  2. count sheet
                   if include empty loc, systemqty = 0 (for all locations)
                   if not include empty loc, systemqty = lotxlocxid
                  3. ucc count sheet
                   regardless include empty loc, systemqty = ucc.qty / lotxlocxid
                  4. RDT TM CC, systemqty = ucc.qty / lotxlocxid
               */
               (SELECT ISNULL( SUM( QTY-QTYAllocated-QTYPicked), 0) FROM dbo.LotxLocxID WITH (NOLOCK) WHERE LOT = C.LOT AND LOC = C.LOC AND ID = C.ID)
              ELSE
               C.SystemQTY
         END, --SystemQty
         ISNULL(CASE @n_FinalizeStage
            WHEN 1 THEN ISNULL(Qty,0)
            WHEN 2 THEN ISNULL(Qty_Cnt2,0)
            WHEN 3 THEN ISNULL(Qty_Cnt3,0)
         END,0) -- CntQty
      FROM  CCDETAIL C WITH (NOLOCK)
      INNER JOIN LOC L WITH (NOLOCK) ON (C.LOC = L.LOC)
      WHERE C.CCKey = @c_CCKey
      AND   C.Status < '9'
      AND   C.CCSheetNo = CASE WHEN @c_TaskDetailKey = '' THEN C.CCSheetNo ELSE @c_TaskDetailKey END
      ORDER BY StorerKey, CCDetailKey


   OPEN CCDET_CUR

   FETCH NEXT FROM CCDET_CUR INTO @c_CCDetailKey, @c_StorerKey, @c_SKU, @c_UCC, @c_LOT, @c_LOC, @c_ID,
                                  @c_Facility, @c_Status,  @n_SystemQty, @n_CntQty

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      BEGIN TRAN
      IF @c_PrevStorerKey <> @c_StorerKey
      BEGIN
         SET @c_AdjustmentKey = ''
         SET @c_UCCAdjustmentKey = ''

         -- Get AdjustmentKey
         IF EXISTS( SELECT 1
            FROM  CCDETAIL C WITH (NOLOCK)
            INNER JOIN LOC L WITH (NOLOCK) ON (C.LOC = L.LOC)
            WHERE C.CCKey = @c_CCKey
            AND   C.Status < '9'
            AND   C.CCSheetNo = CASE WHEN @c_TaskDetailKey = '' THEN C.CCSheetNo ELSE @c_TaskDetailKey END
            AND   C.StorerKey = @c_StorerKey
            AND  (C.Status = '4'
            OR    C.Status = '0'
            OR   (C.Status = '2' AND
                  CASE @n_FinalizeStage --CountQTY
                     WHEN 1 THEN ISNULL(Qty,0)
                     WHEN 2 THEN ISNULL(Qty_Cnt2,0)
                     WHEN 3 THEN ISNULL(Qty_Cnt3,0)
                  END <>
                  CASE --SystemQTY
                     WHEN C.RefNo <> ''
                     THEN (SELECT QTY FROM dbo.UCC WITH (NOLOCK) WHERE C.RefNo = UCCNo AND C.StorerKey = StorerKey AND C.Sku = Sku)  --(Wan03)
                     ELSE (SELECT ISNULL( SUM( QTY-QTYAllocated-QTYPicked), 0) FROM dbo.LotxLocxID WITH (NOLOCK) WHERE LOT = C.LOT AND LOC = C.LOC AND ID = C.ID)
                  END)
                  )
            AND C.RefNo = '') -- No UCC
         BEGIN
            EXECUTE nspg_getkey
               'Adjustment'
               , 10
               , @c_AdjustmentKey OUTPUT
               , @b_success OUTPUT
               , @n_err OUTPUT
               , @c_errmsg OUTPUT

            IF @b_success <> 1
            BEGIN
               ROLLBACK TRAN
               BREAK
            END
         END

         -- Get UCC AdjustmentKey
         IF EXISTS( SELECT 1
            FROM  CCDETAIL C WITH (NOLOCK)
            INNER JOIN LOC L WITH (NOLOCK) ON (C.LOC = L.LOC)
            WHERE C.CCKey = @c_CCKey
            AND   C.Status < '9'
            AND   C.CCSheetNo = CASE WHEN @c_TaskDetailKey = '' THEN C.CCSheetNo ELSE @c_TaskDetailKey END
            AND   C.StorerKey = @c_StorerKey
            AND  (C.Status = '4'
            OR    C.Status = '0'
            OR   (C.Status = '2' AND -- CountQTY <> SystemQTY
                  CASE @n_FinalizeStage
                     WHEN 1 THEN ISNULL(Qty,0)
                     WHEN 2 THEN ISNULL(Qty_Cnt2,0)
                     WHEN 3 THEN ISNULL(Qty_Cnt3,0)
                  END <>
                  CASE -- SystemQTY
                     WHEN C.RefNo <> ''
                     THEN (SELECT QTY FROM dbo.UCC WITH (NOLOCK) WHERE C.RefNo = UCCNo AND C.StorerKey = StorerKey AND C.Sku = Sku) --(Wan03)
                     ELSE (SELECT ISNULL( SUM( QTY-QTYAllocated-QTYPicked), 0) FROM dbo.LotxLocxID WITH (NOLOCK) WHERE LOT = C.LOT AND LOC = C.LOC AND ID = C.ID)
                  END)
                  )
            AND C.RefNo <> '') -- Have UCC
         BEGIN
            EXECUTE nspg_getkey
               'Adjustment'
               , 10
               , @c_UCCAdjustmentKey OUTPUT
               , @b_success OUTPUT
               , @n_err OUTPUT
               , @c_errmsg OUTPUT

            IF @b_success <> 1
            BEGIN
               ROLLBACK TRAN
               BREAK
            END
         END

         IF @n_IsRDT = 1
         BEGIN
            -- Get adjustment type
            SET @c_AdjType = 'RDTCC'
            SELECT @c_AdjType = Short FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTCCADJ' AND Code = 'ADJTYPE' AND StorerKey = @c_StorerKey

            -- Get reason code
            SET @c_AdjReasonCode = 'CC'
            SELECT @c_AdjReasonCode = Short FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTCCADJ' AND Code = 'REASONCODE' AND StorerKey = @c_StorerKey

            SET @cUserDefine01 = @c_LOC
            SET @cUserDefine02 = @c_SKU
            SET @cUserDefine03 = @c_TaskDetailKey

            IF ISNULL(@c_UCCAdjustmentKey, '') <> ''  -- (james02)
               INSERT INTO @tAdjustment (AdjustmentKey) VALUES (@c_UCCAdjustmentKey)

            IF ISNULL(@c_AdjustmentKey, '') <> ''  -- (james02)
               INSERT INTO @tAdjustment (AdjustmentKey) VALUES (@c_AdjustmentKey)
         END
         ELSE
         BEGIN
            SET @cUserDefine01 = ''
            SET @cUserDefine02 = ''
            SET @cUserDefine03 = ''
         END

         -- Insert adjustment header
         IF @c_AdjustmentKey <> ''
         BEGIN
            INSERT ADJUSTMENT (AdjustmentKey, DocType, AdjustmentType, StorerKey, Facility, customerRefNo, remarks, UserDefine01, UserDefine02, UserDefine03)
            VALUES (@c_AdjustmentKey, 'A', @c_AdjType, @c_StorerKey, @c_Facility, @c_CCKey, @c_Remarks, @cUserDefine01, @cUserDefine02, @cUserDefine03)
            SELECT @n_err = @@error
            IF @n_err > 0
            BEGIN
               ROLLBACK TRAN
               BREAK
            END
         END

         -- Insert UCC adjustment header
         IF @c_UCCAdjustmentKey <> ''
         BEGIN
            INSERT ADJUSTMENT (AdjustmentKey, DocType, AdjustmentType, StorerKey, Facility, customerRefNo, remarks, UserDefine01, UserDefine02, UserDefine03)
            VALUES (@c_UCCAdjustmentKey, 'U', @c_AdjType, @c_StorerKey, @c_Facility, @c_CCKey, @c_Remarks, @cUserDefine01, @cUserDefine02, @cUserDefine03)
            SELECT @n_err = @@error
            IF @n_err > 0
            BEGIN
               ROLLBACK TRAN
               BREAK
            END
         END
      END
       
      --NJOW01 S 
      SELECT @c_FinalAdjustmentKey = CASE WHEN @c_UCC = '' THEN @c_AdjustmentKey ELSE @c_UCCAdjustmentKey END 
      SELECT @c_AdjLoc = @c_Loc
      
      SELECT @c_PackKey = p.PackKey,    
             @c_PackUOM3 = p.PackUOM3    --Move from below
      FROM SKU s WITH (NOLOCK)
      JOIN PACK p WITH (NOLOCK) ON p.PACKKey = s.PACKKey
      WHERE s.StorerKey = @c_StorerKey
      AND   s.Sku = @c_SKU      
      --NJOW01 E
      
      -- Not counted, need to adjust out
      IF @c_Status = '0'
      BEGIN
         --NJOW01 S
         SET @n_AdjQty = @n_SystemQty * -1
         
         IF ISNULL(@c_CCMoveAdjQtyToLoc,'') <> ''
         BEGIN
            IF EXISTS(SELECT 1
                      FROM LOC (NOLOCK)
                      WHERE LOC = @c_Loc
                      AND (HostWhCode = @c_Hostwhcode_UDF01
                        OR ISNULL(@c_Hostwhcode_UDF01,'') = '')
                      )
               AND @n_AdjQty < 0
            BEGIN
            	 SET @n_MoveQty = ABS(@n_AdjQty)
               EXEC nspItrnAddMove
                   @n_ItrnSysId =null,
                   @c_StorerKey = @c_StorerKey,
                   @c_Sku = @c_Sku,
                   @c_Lot = @c_Lot,
                   @c_FromLoc = @c_Loc,
                   @c_FromID = @c_ID,
                   @c_ToLoc = @c_CCMoveAdjQtyToLoc,
                   @c_ToID = @c_ID,
                   @c_Status ='0',
                   @c_lottable01 ='',
                   @c_lottable02 ='',
                   @c_lottable03 ='',
                   @d_lottable04 =null,
                   @d_lottable05 =null,
                   @c_lottable06 ='',
                   @c_lottable07 ='',
                   @c_lottable08 ='',
                   @c_lottable09 ='',
                   @c_lottable10 ='',
                   @c_lottable11 ='',
                   @c_lottable12 ='',
                   @d_lottable13 =null,
                   @d_lottable14 =null,
                   @d_lottable15 =null,
                   @n_casecnt =0,
                   @n_innerpack =0,
                   @n_qty = @n_MoveQty,
                   @n_pallet =0,
                   @f_cube =0,
                   @f_grosswgt =0,
                   @f_netwgt =0,
                   @f_otherunit1 =0,
                   @f_otherunit2 =0,
                   @c_SourceKey = @c_FinalAdjustmentKey,
                   @c_SourceType = 'isp_CCPostingByAdjustment_UCC',
                   @c_PackKey = @c_PackKey,
                   @c_UOM = @c_PackUOM3,
                   @b_UOMCalc =null, 
                   @d_EffectiveDate =null,
                   @c_itrnkey =null,
                   @b_Success = @b_Success OUTPUT,
                   @n_err = @n_Err OUTPUT,
                   @c_errmsg = @c_ErrMsg OUTPUT,
                   @c_MoveRefKey =null,
                   @c_Channel =null,
                   @n_Channel_ID =null
               
               IF @b_Success <> 1
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 67104
                  SELECT @c_errmsg = "NSQL" + CONVERT(Char(5), @n_err) + ": Failed to Move Adjustment Stock. (isp_CCPostingByAdjustment_UCC)" + " ( " + " SQLSvr MESSAGE=" + LTRIM(RTRIM(@c_errmsg)) + " ) "
                  ROLLBACK TRAN
                  BREAK               	  
               END                
               ELSE               
                  SET @c_AdjLoc = @c_CCMoveAdjQtyToLoc
            END            	 
         END
         --NJOW01 E               	
      	
         -- Adjust LotxLocxID
         INSERT AdjustmentDetail
            (AdjustmentKey,       AdjustmentLineNumber,          ReasonCode,
             StorerKey,           SKU,      PackKey,   UOM,      Qty,
             LOC,       LOT,      ID,       UserDefine01,        UserDefine02, UCCNo)
         SELECT
             CASE WHEN @c_UCC = '' THEN @c_AdjustmentKey ELSE @c_UCCAdjustmentKey END,       RIGHT(@c_CCDetailKey, 5),      @c_AdjReasonCode,
             @c_StorerKey,           @c_SKU,   S.PackKey,           PackUOM3,
             -@n_SystemQty,          @c_AdjLOC,   @c_LOT,              @c_ID,
             @c_UCC,                 @c_CCDetailKey,                @c_UCC
         FROM  SKU S WITH (NOLOCK)
            INNER JOIN PACK P WITH (NOLOCK) ON S.PackKey = P.PackKey
         WHERE S.StorerKey = @c_StorerKey
            AND S.SKU = @c_SKU
         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN
            BREAK
         END

         -- Adjust UCC
         IF EXISTS ( SELECT 1 FROM UCC WITH (NOLOCK) WHERE UCCNo = @c_UCC AND StorerKey = @c_StorerKey AND Sku = @c_Sku) --(Wan01)
         BEGIN
            UPDATE UCC WITH (ROWLOCK) SET
               Status = '6'
            WHERE UCCNo = @c_UCC
               AND StorerKey = @c_StorerKey
               AND Sku       = @c_Sku                                                                                    --(Wan01)
            IF @@ERROR <> 0
            BEGIN
               ROLLBACK TRAN
               BREAK
            END
         END
      END

      -- Existing inventory (QTY not tally. Loc, id, lottable is tally)
      IF @c_Status = '2' -- (james01)
      BEGIN
         IF (@n_CntQty - @n_SystemQty) <> 0  -- QTY has variance
         BEGIN
            --NJOW01 S
            SET @n_AdjQty = @n_CntQty - @n_SystemQty
            
            IF ISNULL(@c_CCMoveAdjQtyToLoc,'') <> ''
            BEGIN
               IF EXISTS(SELECT 1
                         FROM LOC (NOLOCK)
                         WHERE LOC = @c_Loc
                         AND (HostWhCode = @c_Hostwhcode_UDF01
                           OR ISNULL(@c_Hostwhcode_UDF01,'') = '')
                         )
                  AND @n_AdjQty < 0
               BEGIN
               	  SET @n_MoveQty = ABS(@n_AdjQty)
                  EXEC nspItrnAddMove
                      @n_ItrnSysId =null,
                      @c_StorerKey = @c_StorerKey,
                      @c_Sku = @c_Sku,
                      @c_Lot = @c_Lot,
                      @c_FromLoc = @c_Loc,
                      @c_FromID = @c_ID,
                      @c_ToLoc = @c_CCMoveAdjQtyToLoc,
                      @c_ToID = @c_ID,
                      @c_Status ='0',
                      @c_lottable01 ='',
                      @c_lottable02 ='',
                      @c_lottable03 ='',
                      @d_lottable04 =null,
                      @d_lottable05 =null,
                      @c_lottable06 ='',
                      @c_lottable07 ='',
                      @c_lottable08 ='',
                      @c_lottable09 ='',
                      @c_lottable10 ='',
                      @c_lottable11 ='',
                      @c_lottable12 ='',
                      @d_lottable13 =null,
                      @d_lottable14 =null,
                      @d_lottable15 =null,
                      @n_casecnt =0,
                      @n_innerpack =0,
                      @n_qty = @n_MoveQty,
                      @n_pallet =0,
                      @f_cube =0,
                      @f_grosswgt =0,
                      @f_netwgt =0,
                      @f_otherunit1 =0,
                      @f_otherunit2 =0,
                      @c_SourceKey = @c_FinalAdjustmentKey,
                      @c_SourceType = 'isp_CCPostingByAdjustment_UCC',
                      @c_PackKey = @c_PackKey,
                      @c_UOM = @c_PackUOM3,
                      @b_UOMCalc =null, 
                      @d_EffectiveDate =null,
                      @c_itrnkey =null,
                      @b_Success = @b_Success OUTPUT,
                      @n_err = @n_Err OUTPUT,
                      @c_errmsg = @c_ErrMsg OUTPUT,
                      @c_MoveRefKey =null,
                      @c_Channel =null,
                      @n_Channel_ID =null
                  
                  IF @b_Success <> 1
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_err = 67105
                     SELECT @c_errmsg = "NSQL" + CONVERT(Char(5), @n_err) + ": Failed to Move Adjustment Stock. (isp_CCPostingByAdjustment_UCC)" + " ( " + " SQLSvr MESSAGE=" + LTRIM(RTRIM(@c_errmsg)) + " ) "
                     ROLLBACK TRAN
                     BREAK               	  
                  END                
                  ELSE               
                     SET @c_AdjLoc = @c_CCMoveAdjQtyToLoc
               END            	 
            END
            --NJOW01 E               	
         	
            -- Adjust LotxLocxID
            INSERT AdjustmentDetail
               (AdjustmentKey,       AdjustmentLineNumber,          ReasonCode,
                StorerKey,           SKU,      PackKey,   UOM,      Qty,
                LOC,       LOT,      ID,       UserDefine01,        UserDefine02, UCCNo)
            SELECT
                CASE WHEN @c_UCC = '' THEN @c_AdjustmentKey ELSE @c_UCCAdjustmentKey END,       RIGHT(@c_CCDetailKey, 5),      @c_AdjReasonCode,
                @c_StorerKey,           @c_SKU,   S.PackKey,           PackUOM3,
                @n_CntQty-@n_SystemQty, @c_AdjLOC,   @c_LOT,              @c_ID,
                @c_UCC,                 @c_CCDetailKey,                @c_UCC
            FROM  SKU S WITH (NOLOCK)
               INNER JOIN PACK P WITH (NOLOCK) ON S.PackKey = P.PackKey
            WHERE S.StorerKey = @c_StorerKey
               AND S.SKU = @c_SKU
            IF @@ERROR > 0
            BEGIN
               ROLLBACK TRAN
               BREAK
            END

            -- Adjust UCC
            UPDATE UCC WITH (ROWLOCK) SET
               QTY = @n_CntQty,
               LOT = @c_LOT,
               LOC = @c_LOC,
               ID  = @c_ID
            WHERE UCCNo = @c_UCC
               AND StorerKey = @c_StorerKey
               AND Sku       = @c_Sku             --(Wan01)
            IF @@ERROR <> 0
            BEGIN
               ROLLBACK TRAN
               BREAK
            END
         END
         ELSE
         BEGIN
            -- (james01)
            -- If the UCC has no variance but status is not correct then reset back to 1
            UPDATE dbo.UCC WITH (ROWLOCK) SET
               [STATUS] = CASE WHEN [STATUS] = '1' THEN [STATUS] ELSE '1' END,
               EditWho = 'rdt.' + sUser_sName(),
               EditDate = GETDATE()
            WHERE UCCNo = @c_UCC
               AND StorerKey = @c_StorerKey
               AND Sku       = @c_Sku                                                                                    --(Wan01)
            IF @@ERROR <> 0
            BEGIN
               ROLLBACK TRAN
               BREAK
            END
         END
      END

      -- Newly inserted inventory
      IF @c_Status = '4' AND
         @n_CntQty > 0 -- User added ccdetail but overwrite as zero later
      BEGIN
         IF EXISTS (SELECT 1 FROM LOTxLOCxID WITH (NOLOCK)
                    WHERE StorerKey = @c_StorerKey
                    AND   SKU = @c_SKU
                    AND   LOT = @c_LOT
                    AND   LOC = @c_LOC
                    AND   ID  = @c_ID)
         BEGIN
            -- Insert AdjustmentDetail
            INSERT ADJUSTMENTDETAIL
               (AdjustmentKey,       AdjustmentLineNumber,          ReasonCode,
                StorerKey,           SKU,      PackKey,   UOM,      Qty,
                LOC,                 LOT,      ID,        UserDefine01,
                UserDefine02, UCCNo)
            SELECT
                CASE WHEN @c_UCC = '' THEN @c_AdjustmentKey ELSE @c_UCCAdjustmentKey END,    RIGHT(@c_CCDetailKey, 5),      @c_AdjReasonCode,
                @c_StorerKey,        @c_SKU,   S.PackKey, PackUOM3, @n_CntQty,
                @c_LOC,    @c_LOT,   @c_ID,    @c_UCC,    @c_CCDetailKey, @c_UCC
            FROM  SKU S WITH (NOLOCK)
            INNER JOIN PACK P WITH (NOLOCK) ON S.PackKey = P.PackKey
            WHERE S.StorerKey = @c_StorerKey
            AND   S.SKU = @c_SKU

            SELECT @n_err = @@error
            IF @n_err > 0
            BEGIN
               ROLLBACK TRAN
               BREAK
            END
         END
         ELSE -- No inventory record
         BEGIN -- Create inventory record for adjustment
            SELECT @c_Lottable01 = CASE @n_FinalizeStage
                                    WHEN 1 THEN ISNULL(Lottable01, '')
                                    WHEN 2 THEN ISNULL(Lottable01_Cnt2, '')
                                    WHEN 3 THEN ISNULL(Lottable01_Cnt3, '')
                                   END,

                  @c_Lottable02 = CASE @n_FinalizeStage
                                    WHEN 1 THEN ISNULL(Lottable02, '')
                                    WHEN 2 THEN ISNULL(Lottable02_Cnt2, '')
                                    WHEN 3 THEN ISNULL(Lottable02_Cnt3, '')
                                   END,
                  @c_Lottable03 = CASE @n_FinalizeStage
                                    WHEN 1 THEN ISNULL(Lottable03, '')
                                    WHEN 2 THEN ISNULL(Lottable03_Cnt2, '')
                                    WHEN 3 THEN ISNULL(Lottable03_Cnt3, '')
                                   END,
                  @d_Lottable04 = CASE @n_FinalizeStage
                                    WHEN 1 THEN Lottable04
                                    WHEN 2 THEN Lottable04_Cnt2
                                    WHEN 3 THEN Lottable04_Cnt3
                                   END,
                  @d_Lottable05 = CASE @n_FinalizeStage
                                    WHEN 1 THEN Lottable05
                                    WHEN 2 THEN Lottable05_Cnt2
                                    WHEN 3 THEN Lottable05_Cnt3
                                   END,
                  @c_Lottable06 = CASE @n_FinalizeStage
                                    WHEN 1 THEN ISNULL(Lottable06, '')
                                    WHEN 2 THEN ISNULL(Lottable06_cnt2, '')
                                    WHEN 3 THEN ISNULL(Lottable06_cnt3, '')
                                   END,
                  @c_Lottable07 = CASE @n_FinalizeStage
                                    WHEN 1 THEN ISNULL(Lottable07, '')
                                    WHEN 2 THEN ISNULL(Lottable07_cnt2, '')
                                    WHEN 3 THEN ISNULL(Lottable07_cnt3, '')
                                   END,
                  @c_Lottable08 = CASE @n_FinalizeStage
                                    WHEN 1 THEN ISNULL(Lottable08, '')
                                    WHEN 2 THEN ISNULL(Lottable08_cnt2, '')
                                    WHEN 3 THEN ISNULL(Lottable08_cnt3, '')
                                   END,
                  @c_Lottable09 = CASE @n_FinalizeStage
                                    WHEN 1 THEN ISNULL(Lottable09, '')
                                    WHEN 2 THEN ISNULL(Lottable09_cnt2, '')
                                    WHEN 3 THEN ISNULL(Lottable09_cnt3, '')
                                   END,
                  @c_Lottable10 = CASE @n_FinalizeStage
                                    WHEN 1 THEN ISNULL(Lottable10, '')
                                    WHEN 2 THEN ISNULL(Lottable10_cnt2, '')
                                    WHEN 3 THEN ISNULL(Lottable10_cnt3, '')
                                   END,
                  @c_Lottable11 = CASE @n_FinalizeStage
                                    WHEN 1 THEN ISNULL(Lottable11, '')
                                    WHEN 2 THEN ISNULL(Lottable11_cnt2, '')
                                    WHEN 3 THEN ISNULL(Lottable11_cnt3, '')
                                   END,
                  @c_Lottable12 = CASE @n_FinalizeStage
                                    WHEN 1 THEN ISNULL(Lottable12, '')
                                    WHEN 2 THEN ISNULL(Lottable12_cnt2, '')
                                    WHEN 3 THEN ISNULL(Lottable12_cnt3, '')
                                   END,
                  @d_Lottable13 = CASE @n_FinalizeStage
                                    WHEN 1 THEN Lottable13
                                    WHEN 2 THEN Lottable13_cnt2
                                    WHEN 3 THEN Lottable13_cnt3
                                   END,
                  @d_Lottable14 = CASE @n_FinalizeStage
                                    WHEN 1 THEN Lottable14
                                    WHEN 2 THEN Lottable14_cnt2
                                    WHEN 3 THEN Lottable14_cnt3
                                   END,
                  @d_Lottable15 = CASE @n_FinalizeStage
                                    WHEN 1 THEN Lottable15
                                    WHEN 2 THEN Lottable15_cnt2
                                    WHEN 3 THEN Lottable15_cnt3
                                   END,

                  @d_Today = GetDate()
            FROM  CCDETAIL WITH (NOLOCK)
            WHERE CCKey = @c_CCKey
            AND   CCDetailKey = @c_CCDetailKey

            /*
            SELECT @c_PackKey = p.PackKey
            FROM SKU s WITH (NOLOCK)
            JOIN PACK p WITH (NOLOCK) ON p.PACKKey = s.PACKKey
            WHERE s.StorerKey = @c_StorerKey
            AND   s.Sku = @c_SKU
            */

            -- Insert a dummy deposit to create inventory record
            SELECT @c_SourceKey = @c_CCKey + @c_CCDetailKey
            EXECUTE nspItrnAddDeposit
               @n_ItrnSysId    = NULL,
               @c_StorerKey    = @c_StorerKey,
               @c_Sku          = @c_SKU,
               @c_Lot          = '',
               @c_ToLoc        = @c_LOC,
               @c_ToID         = @c_ID,
               @c_Status       = 'OK',
               @c_lottable01   = @c_Lottable01,
               @c_lottable02   = @c_Lottable02,
               @c_lottable03   = @c_Lottable03,
               @d_lottable04   = @d_Lottable04,
               @d_lottable05   = @d_Lottable05,
               @c_lottable06   = @c_Lottable06,
               @c_lottable07   = @c_Lottable07,
               @c_lottable08   = @c_Lottable08,
               @c_lottable09   = @c_Lottable09,
               @c_lottable10   = @c_Lottable10,
               @c_lottable11   = @c_Lottable11,
               @c_lottable12   = @c_Lottable12,
               @d_lottable13   = @d_Lottable13,
               @d_lottable14   = @d_Lottable14,
               @d_lottable15   = @d_Lottable15,
               @n_casecnt      = 0,
               @n_innerpack    = 0,
               @n_qty          = 0, -- dummy Qty
               @n_pallet       = 0,
               @f_cube         = 0,
               @f_grosswgt     = 0,
               @f_netwgt       = 0,
               @f_otherunit1   = 0,
               @f_otherunit2   = 0,
               @c_SourceKey    = @c_SourceKey,
               @c_SourceType   = 'DUMMY',
               @c_PackKey      = @c_PackKey,
               @c_UOM          = @c_PackUOM3,
               @b_UOMCalc      = 0,
               @d_EffectiveDate= @d_Today,
               @c_itrnkey      = '',
               @b_Success      = @b_success OUTPUT,
               @n_err          = 0,
               @c_errmsg       = ''

            SELECT @n_err = @@error
            IF @b_success <> 1
            BEGIN
               IF @n_err > 0
               BEGIN
                  ROLLBACK TRAN
                  BREAK
               END
            END

            -- Retrieve newly created LOT
            SELECT @c_LOT = SPACE(10)
            SELECT @c_LOT = LOT
            FROM  ITRN WITH (NOLOCK)
            WHERE StorerKey = @c_StorerKey
            AND   SKU = @c_SKU
            AND   Sourcekey = @c_SourceKey

            -- Insert AdjustmentDetail
            INSERT INTO ADJUSTMENTDETAIL
               (AdjustmentKey,       AdjustmentLineNumber,          ReasonCode,
                StorerKey,           SKU,      PackKey,   UOM,      Qty,
                LOC,       LOT,      ID,       UserDefine01,        UserDefine02, UCCNo )
            SELECT
                CASE WHEN @c_UCC = '' THEN @c_AdjustmentKey ELSE @c_UCCAdjustmentKey END,    RIGHT(@c_CCDetailKey, 5),      @c_AdjReasonCode,
                @c_StorerKey,        @c_SKU,   S.PackKey, PackUOM3, @n_CntQty,
                @c_LOC,    @c_LOT,   @c_ID,    @c_UCC,    @c_CCDetailKey , @c_UCC       -- (james01)
            FROM  SKU S WITH (NOLOCK)
            INNER JOIN PACK P WITH (NOLOCK) ON S.PackKey = P.PackKey
            WHERE S.StorerKey = @c_StorerKey
            AND   S.SKU = @c_SKU

            SELECT @n_err = @@error
            IF @n_err > 0
            BEGIN
               ROLLBACK TRAN
               BREAK
            END
         END -- Create inventory record for adjustment
      END

      IF EXISTS ( SELECT 1 FROM UCC WITH (NOLOCK)
                  WHERE UCCNo = @c_UCC
                  AND   StorerKey = @c_StorerKey
                  AND   Sku       = @c_Sku)                                                                            --(Wan01)
                  AND   @c_UCC > ''
      BEGIN
         -- Negative adjust to existing UCC
         SELECT
            @c_OldLOC = LOC,
            @c_OldLOT = LOT,
            @c_OldID  = ID,
            @c_OldSKU = SKU,
            @n_OldQty = Qty,
            @c_OldStorer = StorerKey
         FROM  UCC WITH (NOLOCK)
         WHERE UCCNo = @c_UCC
         AND   StorerKey = @c_StorerKey
         AND   Sku       = @c_Sku                                                                                     --(Wan01)

         IF EXISTS(SELECT 1 FROM CCDETAIL WITH (NOLOCK)
                       WHERE  RefNo = @c_UCC
                       AND    StorerKey = @c_StorerKey
                       AND    Sku       = @c_Sku                                                                      --(Wan01)
                       AND    STATUS = '2'
                       AND    Qty = 0) --OR @c_Status = '0'
         BEGIN
            IF EXISTS ( SELECT 1 FROM LOTxLOCxID WITH (NOLOCK)
                        WHERE StorerKey = @c_OldStorer
                        AND   SKU = @c_OldSKU
                        AND   LOT = @c_OldLOT
                        AND   LOC = @c_OldLOC
                        AND   ID  = @c_OldID
                        AND   Qty > 0 )
            BEGIN            	
               --NJOW01 S
               SET @n_AdjQty = @n_OldQty * -1
               SET @c_AdjLoc = @c_OldLoc
               
               IF ISNULL(@c_CCMoveAdjQtyToLoc,'') <> ''
               BEGIN
                  IF EXISTS(SELECT 1
                            FROM LOC (NOLOCK)
                            WHERE LOC = @c_Loc
                            AND (HostWhCode = @c_Hostwhcode_UDF01
                              OR ISNULL(@c_Hostwhcode_UDF01,'') = '')
                            )
                     AND @n_AdjQty < 0
                  BEGIN
                  	 SET @n_MoveQty = ABS(@n_AdjQty)
                     EXEC nspItrnAddMove
                         @n_ItrnSysId =null,
                         @c_StorerKey = @c_StorerKey,
                         @c_Sku = @c_OldSku,
                         @c_Lot = @c_OldLot,
                         @c_FromLoc = @c_OldLoc,
                         @c_FromID = @c_OldID,
                         @c_ToLoc = @c_CCMoveAdjQtyToLoc,
                         @c_ToID = @c_OldID,
                         @c_Status ='0',
                         @c_lottable01 ='',
                         @c_lottable02 ='',
                         @c_lottable03 ='',
                         @d_lottable04 =null,
                         @d_lottable05 =null,
                         @c_lottable06 ='',
                         @c_lottable07 ='',
                         @c_lottable08 ='',
                         @c_lottable09 ='',
                         @c_lottable10 ='',
                         @c_lottable11 ='',
                         @c_lottable12 ='',
                         @d_lottable13 =null,
                         @d_lottable14 =null,
                         @d_lottable15 =null,
                         @n_casecnt =0,
                         @n_innerpack =0,
                         @n_qty = @n_MoveQty,
                         @n_pallet =0,
                         @f_cube =0,
                         @f_grosswgt =0,
                         @f_netwgt =0,
                         @f_otherunit1 =0,
                         @f_otherunit2 =0,
                         @c_SourceKey = @c_FinalAdjustmentKey,
                         @c_SourceType = 'isp_CCPostingByAdjustment_UCC',
                         @c_PackKey = @c_PackKey,
                         @c_UOM = @c_PackUOM3,
                         @b_UOMCalc =null, 
                         @d_EffectiveDate =null,
                         @c_itrnkey =null,
                         @b_Success = @b_Success OUTPUT,
                         @n_err = @n_Err OUTPUT,
                         @c_errmsg = @c_ErrMsg OUTPUT,
                         @c_MoveRefKey =null,
                         @c_Channel =null,
                         @n_Channel_ID =null
                     
                     IF @b_Success <> 1
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @n_err = 67106
                        SELECT @c_errmsg = "NSQL" + CONVERT(Char(5), @n_err) + ": Failed to Move Adjustment Stock. (isp_CCPostingByAdjustment_UCC)" + " ( " + " SQLSvr MESSAGE=" + LTRIM(RTRIM(@c_errmsg)) + " ) "
                        ROLLBACK TRAN
                        BREAK               	  
                     END                
                     ELSE               
                        SET @c_AdjLoc = @c_CCMoveAdjQtyToLoc
                  END            	 
               END
               --NJOW01 E         
                        	
               -- Insert AdjustmentDetail
               INSERT INTO ADJUSTMENTDETAIL
                  (AdjustmentKey,       AdjustmentLineNumber,           ReasonCode,
                   StorerKey,           SKU,       PackKey,   UOM,      Qty,
                   LOC,                 LOT,       ID,        UserDefine01,
                   UserDefine02, UCCNo )
               SELECT
                   CASE WHEN @c_UCC = '' THEN @c_AdjustmentKey ELSE @c_UCCAdjustmentKey END,    'D'+RIGHT(@c_CCDetailKey, 4),   @c_AdjReasonCode,
                   @c_StorerKey,        @c_OldSKU,   S.PackKey, PackUOM3, @n_OldQty * -1,
                   @c_AdjLOC,           @c_OldLOT,   @c_OldID,  @c_UCC,   @c_CCDetailKey , @c_UCC       -- (james01)
               FROM  SKU S WITH (NOLOCK)
               INNER JOIN PACK P WITH (NOLOCK) ON S.PackKey = P.PackKey
               WHERE S.StorerKey = @c_StorerKey
               AND   S.SKU = @c_OldSKU

               SELECT @n_err = @@error
               IF @n_err > 0
               BEGIN
                  ROLLBACK TRAN
                  BREAK
               END

               -- Delete UCC with old values
               DELETE UCC WITH (ROWLOCK) WHERE UCCNo = @c_UCC AND StorerKey = @c_StorerKey AND Sku = @c_Sku          --(Wan01)
               SELECT @n_err = @@error
               IF @n_err > 0
               BEGIN
                  ROLLBACK TRAN
                  BREAK
               END

               -- Insert UCC with latest values
               IF @c_UCC > ''
               BEGIN
                  INSERT INTO UCC
                     (UCCNo, StorerKey, SKU, LOT, LOC, ID, Qty, Status, ExternKey)
                  VALUES
                     (@c_UCC, @c_StorerKey, @c_SKU, @c_LOT, @c_LOC, @c_ID, @n_CntQty, '1', '')

                  SELECT @n_err = @@error
                  IF @n_err > 0
                  BEGIN
                     ROLLBACK TRAN
                     BREAK
                  END
               END
            END
         END
      END

      IF EXISTS(SELECT 1 FROM CCDETAIL CC WITH (NOLOCK)
                JOIN UCC UCC WITH (NOLOCK) ON (CC.REFNo = UCC.UCCNo AND CC.StorerKey = UCC.StorerKey AND CC.Sku = UCC.Sku)--(Wan01)
                WHERE  CC.RefNo = @c_UCC
                AND    CC.StorerKey = @c_StorerKey
                AND    CC.Sku       = @c_Sku                                                                         --(Wan01)
                AND    CC.STATUS = '4'  )
      BEGIN
         -- Delete UCC with old values
         DELETE UCC WITH (ROWLOCK) WHERE UCCNo = @c_UCC AND StorerKey = @c_StorerKey AND Sku = @c_Sku                --(Wan01)
         SELECT @n_err = @@error
         IF @n_err > 0
         BEGIN
            ROLLBACK TRAN
            BREAK
         END

         -- Insert UCC with latest values
         IF @c_UCC > ''
         BEGIN
            -- Recalc again the CntQty for status '4' (same ucc) as it might contain split line
            --SELECT @n_CntQty = ISNULL(SUM( Qty), 0)            
            SELECT SUM(CASE @n_FinalizeStage
                          WHEN 1 THEN ISNULL(Qty,0)
                          WHEN 2 THEN ISNULL(Qty_Cnt2,0)
                          WHEN 3 THEN ISNULL(Qty_Cnt3,0)
                       END)            --NJOW01
            FROM dbo.CCDetail WITH (NOLOCK)
            WHERE CCKey = @c_CCKey
            AND   Refno = @c_UCC
            AND   CCSheetNo = CASE WHEN @c_TaskDetailKey = '' THEN CCSheetNo ELSE @c_TaskDetailKey END
            AND   Storerkey = @c_StorerKey                                                                           --(Wan01)
            AND   Sku       = @c_Sku                                                                                 --(Wan01)

            INSERT INTO UCC
               (UCCNo, StorerKey, SKU, LOT, LOC, ID, Qty, Status, ExternKey)
            VALUES
               (@c_UCC, @c_StorerKey, @c_SKU, @c_LOT, @c_LOC, @c_ID, @n_CntQty, '1', '')

            SELECT @n_err = @@error
            IF @n_err > 0
            BEGIN
               ROLLBACK TRAN
               BREAK
            END
         END
      END
--         -- Insert UCC with latest values
--         IF @c_UCC > ''
--         BEGIN
--            INSERT INTO UCC
--               (UCCNo, StorerKey, SKU, LOT, LOC, ID, Qty, Status, ExternKey)
--            VALUES
--               (@c_UCC, @c_StorerKey, @c_SKU, @c_LOT, @c_LOC, @c_ID, @n_CntQty, '1', '')
--
--            SELECT @n_err = @@error
--            IF @n_err > 0
--            BEGIN
--               ROLLBACK TRAN
--               BREAK
--            END
--
--      END -- @c_Status = '4'

      -- Finalize/Close CCDETAIL record
      UPDATE CCDETAIL
      SET Status = '9' -- Posted
      WHERE CCKey = @c_CCKey
      AND   CCDetailKey = @c_CCDetailKey

      SELECT @n_err = @@error
      IF @n_err > 0
      BEGIN
         ROLLBACK TRAN
         BREAK
      END
      ELSE
      BEGIN
         COMMIT TRAN
      END

      SELECT @c_PrevStorerKey = @c_StorerKey

      FETCH NEXT FROM CCDET_CUR INTO @c_CCDetailKey, @c_StorerKey, @c_SKU, @c_UCC, @c_LOT, @c_LOC, @c_ID,
                                     @c_Facility, @c_Status,  @n_SystemQty, @n_CntQty
   END -- @@FETCH_STATUS <> -1

   CLOSE CCDET_CUR
   DEALLOCATE CCDET_CUR
   
   --NJOW02 S
   EXEC isp_PostCCAdjustment_Wrapper @c_StockTakeKey = @c_CCKey,  
                                     @c_SourceType = 'isp_CCPostingByAdjustment_UCC',  
                                     @b_Success = @b_Success OUTPUT,            
                                     @n_Err = @n_err OUTPUT,            
                                     @c_Errmsg = @c_errmsg OUTPUT                                                           
   --NJOW02 E

   IF @n_IsRDT = 1
   BEGIN
      -- Get task info
      SELECT
         @c_SKU = SKU,
         @c_LOC = FromLOC
      FROM dbo.TaskDetail
      WHERE TaskDetailKey = @c_TaskDetailKey

      -- Take out UCC not match LLI (QTY not on LLI, but UCC.Status = 1)
      IF EXISTS( SELECT TOP 1 1
         FROM dbo.UCC WITH (NOLOCK)
         WHERE UCC.LOC = @c_LOC
            AND UCC.SKU = CASE WHEN @c_SKU = '' THEN UCC.SKU ELSE @c_SKU END
            AND UCC.Status = '1'
            AND UCC.UCCNo NOT IN (
               SELECT RefNo
               FROM dbo.CCDetail WITH (NOLOCK)
               WHERE CCKey = @c_CCKey
                  AND CCSheetNo = @c_TaskDetailKey
                  AND RefNo <> ''))
      BEGIN
         UPDATE UCC SET
            Status = '6',
            EditWho = 'rdt.' + sUser_sName(),
            EditDate = GETDATE()
         WHERE UCC.LOC = @c_LOC
            AND UCC.SKU = CASE WHEN @c_SKU = '' THEN UCC.SKU ELSE @c_SKU END
            AND UCC.Status = '1'
        AND UCC.UCCNo NOT IN (
               SELECT RefNo
               FROM dbo.CCDetail WITH (NOLOCK)
               WHERE CCKey = @c_CCKey
                  AND CCSheetNo = @c_TaskDetailKey
                  AND RefNo <> '')
      END

--      SELECT * FROM @tAdjustment

      IF EXISTS( SELECT 1 FROM @tAdjustment)
      BEGIN
         --BEGIN TRAN
         WHILE 1=1
         BEGIN
            SELECT TOP 1 @c_AdjustmentKey = AdjustmentKey FROM @tAdjustment
            IF @c_AdjustmentKey <> ''
            BEGIN
               SET @n_err = 0
               EXEC isp_FinalizeADJ
                  @c_AdjustmentKey,
                  @b_Success  OUTPUT,
                  @n_err      OUTPUT,
                  @c_errmsg   OUTPUT
               IF @n_err <> 0
               BEGIN
                  --ROLLBACK TRAN
                  BREAK
               END
               DELETE @tAdjustment WHERE AdjustmentKey = @c_AdjustmentKey
               SET @c_AdjustmentKey = ''
            END
            ELSE
               BREAK
         END
         --COMMIT TRAN
      END
   END


END -- main

GO
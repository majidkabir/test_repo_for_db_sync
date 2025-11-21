SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispCCDetailUpd_AU01                                 */
/* Copyright      : MAERSK                                              */
/*                                                                      */
/* Purpose: Update CCDEtail Logic. Distribute qty equally over the      */
/*          ccdetail line. The last line has the remaining qty.         */
/*          Default lottable05 = count date                             */
/*                                                                      */
/* Called from: ispCycleCount_Wrapper                                   */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2023-09-06  1.0  James       WMS-23474. Created                      */
/************************************************************************/

CREATE   PROCEDURE [dbo].[ispCCDetailUpd_AU01]
   @c_SKU              NVARCHAR(20),
   @c_Storerkey        NVARCHAR(15),
   @c_Loc              NVARCHAR(10),
   @c_ID               NVARCHAR(18),
   @c_CCKey            NVARCHAR(10),
   @c_CountNo          NVARCHAR(10),
   @c_Ref01            NVARCHAR(20),
   @c_Ref02            NVARCHAR(20),
   @c_Ref03            NVARCHAR(20),
   @c_Ref04            NVARCHAR(20),
   @c_Ref05            NVARCHAR(20),
   @c_Qty              INT,
   @c_Lottable01Value  NVARCHAR(18),
   @c_Lottable02Value  NVARCHAR(18),
   @c_Lottable03Value  NVARCHAR(18),
   @dt_Lottable04Value DateTime,
   @dt_Lottable05Value DateTime,
   @c_LangCode         NVARCHAR(3),
   @c_oFieled01        NVARCHAR(20) OUTPUT,
   @c_oFieled02        NVARCHAR(20) OUTPUT,
   @c_oFieled03        NVARCHAR(20) OUTPUT,
   @c_oFieled04        NVARCHAR(20) OUTPUT,
   @c_oFieled05        NVARCHAR(20) OUTPUT,
   @c_oFieled06        NVARCHAR(20) OUTPUT,
   @c_oFieled07        NVARCHAR(20) OUTPUT,
   @c_oFieled08        NVARCHAR(20) OUTPUT,
   @c_oFieled09        NVARCHAR(20) OUTPUT,
   @c_oFieled10        NVARCHAR(20) OUTPUT,
   @b_Success          INT = 1  OUTPUT,
   @n_ErrNo            INT      OUTPUT,
   @c_ErrMsg           NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue     INT,
           @b_debug        INT,
           @cCCDetailKey   NVARCHAR(10),
           @nTranCount            INT

   DECLARE @c_UserName     NVARCHAR( 18)
   DECLARE @c_Facility     NVARCHAR( 5)
   DECLARE @c_CCLot        NVARCHAR( 10)
   DECLARE @c_CCLoc        NVARCHAR( 10)
   DECLARE @c_CCID         NVARCHAR( 10)
   
   SET @c_UserName = sUser_sName()

   SELECT @c_Facility = Facility
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE UserName = @c_UserName
   
   SELECT @b_Success = 1, @n_ErrNo = 0, @b_debug = 0
   SELECT @c_oFieled01  = '',
          @c_oFieled02  = '',
          @c_oFieled03  = '',
          @c_oFieled04  = '',
          @c_oFieled05  = '',
          @c_oFieled06  = '',
          @c_oFieled07  = '',
          @c_oFieled08  = '',
          @c_oFieled09  = '',
          @c_oFieled10  = ''

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN CycleCountTran

   DECLARE @c_CCDetailKey        NVARCHAR(10),
           @c_CCSheetNo          NVARCHAR(10),
           @cExecStatements      nvarchar(4000),
           @cExecArguments       nvarchar(4000),
           @n_Qty                int,
           @nQTY_PD              int

   DECLARE @c_ExcludeQtyAllocated   NVARCHAR( 1) = ''
   DECLARE @c_ExcludeQtyPicked      NVARCHAR( 1) = ''
   
   SELECT 
      @c_ExcludeQtyAllocated = ExcludeQtyAllocated, 
      @c_ExcludeQtyPicked = ExcludeQtyPicked 
   FROM dbo.StockTakeSheetParameters WITH (NOLOCK) 
   WHERE StockTakeKey = @c_CCKey

   SET @n_Qty = @c_Qty

   DECLARE CursorCCDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR

   SELECT c.CCDetailKey , c.Lot, c.Loc, c.Id
   FROM CCDetail c WITH (NOLOCK)
   WHERE c.CCKey     = @c_CCKey
   AND c.Storerkey   = @c_StorerKey
   AND c.SKU         = @c_SKU
   AND c.LOC         = @c_LOC
   Order By c.CCDetailKey

   OPEN CursorCCDetail
   FETCH NEXT FROM CursorCCDetail INTO @c_CCDetailKey, @c_CCLot, @c_CCLoc, @c_CCID
   WHILE @@FETCH_STATUS<>-1
   BEGIN

      SELECT @nQTY_PD = 
         CASE WHEN @c_ExcludeQtyAllocated = 'Y' AND @c_ExcludeQtyPicked = 'Y' THEN SUM( Qty - QtyAllocated - QtyPicked)     
              WHEN @c_ExcludeQtyAllocated = 'Y' THEN SUM (Qty - QtyAllocated)   
              WHEN @c_ExcludeQtyPicked    = 'Y' THEN SUM( Qty - QtyPicked)  
              ELSE SUM( Qty)
         END
      FROM dbo.LOTxLOCxID WITH (NOLOCK)
      WHERE Lot = @c_CCLot
      AND   Loc = @c_Loc
      AND   Id = @c_CCID
      
      --IF SUSER_SNAME() = 'jameswong'
      --   SELECT @nQTY_PD '@nQTY_PD', @n_Qty '@n_Qty'
         
      IF @nQTY_PD=@n_Qty
      BEGIN

         UPDATE dbo.CCDEtail WITH (ROWLOCK) SET
             SystemQty = @nQTY_PD
           , Qty      = CASE WHEN @c_CountNo = '1' THEN @n_Qty ELSE Qty  END
           , Qty_Cnt2 = CASE WHEN @c_CountNo = '2' THEN @n_Qty ELSE Qty_Cnt2 END
           , Qty_Cnt3 = CASE WHEN @c_CountNo = '3' THEN @n_Qty ELSE Qty_Cnt3 END
           , Status  = '2'
           , Counted_Cnt1 = CASE WHEN @c_CountNo = '1' THEN '1' ELSE Counted_Cnt1 END
           , Counted_Cnt2 = CASE WHEN @c_CountNo = '2' THEN '1' ELSE Counted_Cnt2 END
           , Counted_Cnt3 = CASE WHEN @c_CountNo = '3' THEN '1' ELSE Counted_Cnt3 END
           , EditWho_Cnt1 = CASE WHEN @c_CountNo = '1' THEN @c_UserName ELSE EditWho_Cnt1 END
           , EditWho_Cnt2 = CASE WHEN @c_CountNo = '2' THEN @c_UserName ELSE EditWho_Cnt2 END
           , EditWho_Cnt3 = CASE WHEN @c_CountNo = '3' THEN @c_UserName ELSE EditWho_Cnt3 END
           , EditDate_Cnt1 = CASE WHEN @c_CountNo = '1' THEN GETDATE() ELSE EditDate_Cnt1 END
           , EditDate_Cnt2 = CASE WHEN @c_CountNo = '2' THEN GETDATE() ELSE EditDate_Cnt2 END
           , EditDate_Cnt3 = CASE WHEN @c_CountNo = '3' THEN GETDATE() ELSE EditDate_Cnt3 END
         WHERE CCKey = @c_CCKey
         AND CCDetailKey = @c_CCDetailKey

         IF @@ERROR <> 0
         BEGIN
             SET @n_ErrNo = 82051
             SET @c_ErrMsg = rdt.rdtgetmessage(@n_ErrNo, @c_LangCode, 'DSP')  -- UpdCCDetailFail
             GOTO RollBackTran
         END
      END
      ELSE
      IF @n_Qty > @nQTY_PD
      BEGIN

          UPDATE dbo.CCDEtail WITH (ROWLOCK) SET
              SystemQty = @nQTY_PD
            , Qty      = CASE WHEN @c_CountNo = '1' THEN @nQTY_PD ELSE Qty  END
            , Qty_Cnt2 = CASE WHEN @c_CountNo = '2' THEN @nQTY_PD ELSE Qty_Cnt2 END
            , Qty_Cnt3 = CASE WHEN @c_CountNo = '3' THEN @nQTY_PD ELSE Qty_Cnt3 END
            , Status  = '2'
            , Counted_Cnt1 = CASE WHEN @c_CountNo = '1' THEN '1' ELSE Counted_Cnt1 END
            , Counted_Cnt2 = CASE WHEN @c_CountNo = '2' THEN '1' ELSE Counted_Cnt2 END
            , Counted_Cnt3 = CASE WHEN @c_CountNo = '3' THEN '1' ELSE Counted_Cnt3 END
            , EditWho_Cnt1 = CASE WHEN @c_CountNo = '1' THEN @c_UserName ELSE EditWho_Cnt1 END
            , EditWho_Cnt2 = CASE WHEN @c_CountNo = '2' THEN @c_UserName ELSE EditWho_Cnt2 END
            , EditWho_Cnt3 = CASE WHEN @c_CountNo = '3' THEN @c_UserName ELSE EditWho_Cnt3 END
            , EditDate_Cnt1 = CASE WHEN @c_CountNo = '1' THEN GETDATE() ELSE EditDate_Cnt1 END
            , EditDate_Cnt2 = CASE WHEN @c_CountNo = '2' THEN GETDATE() ELSE EditDate_Cnt2 END
            , EditDate_Cnt3 = CASE WHEN @c_CountNo = '3' THEN GETDATE() ELSE EditDate_Cnt3 END
          WHERE CCKey = @c_CCKey
          AND CCDetailKey = @c_CCDetailKey

          IF @@ERROR <> 0
          BEGIN
             SET @n_ErrNo = 82052
             SET @c_ErrMsg = rdt.rdtgetmessage(@n_ErrNo, @c_LangCode, 'DSP')  -- UpdCCDetailFail
             GOTO RollBackTran
          END
      END
      ELSE
      IF @n_Qty < @nQTY_PD AND @n_Qty > 0
      BEGIN

          UPDATE dbo.CCDEtail WITH (ROWLOCK) SET
             SystemQty = @nQTY_PD
           , Qty      = CASE WHEN @c_CountNo = '1' THEN @n_Qty ELSE Qty  END
           , Qty_Cnt2 = CASE WHEN @c_CountNo = '2' THEN @n_Qty ELSE Qty_Cnt2 END
           , Qty_Cnt3 = CASE WHEN @c_CountNo = '3' THEN @n_Qty ELSE Qty_Cnt3 END
           , Status  = '2'
           , Counted_Cnt1 = CASE WHEN @c_CountNo = '1' THEN '1' ELSE Counted_Cnt1 END
           , Counted_Cnt2 = CASE WHEN @c_CountNo = '2' THEN '1' ELSE Counted_Cnt2 END
           , Counted_Cnt3 = CASE WHEN @c_CountNo = '3' THEN '1' ELSE Counted_Cnt3 END
           , EditWho_Cnt1 = CASE WHEN @c_CountNo = '1' THEN @c_UserName ELSE EditWho_Cnt1 END
           , EditWho_Cnt2 = CASE WHEN @c_CountNo = '2' THEN @c_UserName ELSE EditWho_Cnt2 END
           , EditWho_Cnt3 = CASE WHEN @c_CountNo = '3' THEN @c_UserName ELSE EditWho_Cnt3 END
           , EditDate_Cnt1 = CASE WHEN @c_CountNo = '1' THEN GETDATE() ELSE EditDate_Cnt1 END
           , EditDate_Cnt2 = CASE WHEN @c_CountNo = '2' THEN GETDATE() ELSE EditDate_Cnt2 END
           , EditDate_Cnt3 = CASE WHEN @c_CountNo = '3' THEN GETDATE() ELSE EditDate_Cnt3 END
          WHERE CCKey = @c_CCKey
          AND CCDetailKey = @c_CCDetailKey

         IF @@ERROR <> 0
         BEGIN
            SET @n_ErrNo = 82053
            SET @c_ErrMsg = rdt.rdtgetmessage(@n_ErrNo, @c_LangCode, 'DSP')  -- UpdCCDetailFail
            GOTO RollBackTran
         END
      END
      IF @n_Qty = 0 -- Treat as Counted when Qty = 0 and still have same SKU and Loc not counted.
      BEGIN

         UPDATE dbo.CCDEtail WITH (ROWLOCK) SET
              SystemQty = @nQTY_PD
            , Status  = '2'
            , Counted_Cnt1 = CASE WHEN @c_CountNo = '1' THEN '1' ELSE Counted_Cnt1 END
            , Counted_Cnt2 = CASE WHEN @c_CountNo = '2' THEN '1' ELSE Counted_Cnt2 END
            , Counted_Cnt3 = CASE WHEN @c_CountNo = '3' THEN '1' ELSE Counted_Cnt3 END
            , EditWho_Cnt1 = CASE WHEN @c_CountNo = '1' THEN @c_UserName ELSE EditWho_Cnt1 END
            , EditWho_Cnt2 = CASE WHEN @c_CountNo = '2' THEN @c_UserName ELSE EditWho_Cnt2 END
            , EditWho_Cnt3 = CASE WHEN @c_CountNo = '3' THEN @c_UserName ELSE EditWho_Cnt3 END
            , EditDate_Cnt1 = CASE WHEN @c_CountNo = '1' THEN GETDATE() ELSE EditDate_Cnt1 END
            , EditDate_Cnt2 = CASE WHEN @c_CountNo = '2' THEN GETDATE() ELSE EditDate_Cnt2 END
            , EditDate_Cnt3 = CASE WHEN @c_CountNo = '3' THEN GETDATE() ELSE EditDate_Cnt3 END
          WHERE CCKey = @c_CCKey
          AND CCDetailKey = @c_CCDetailKey

         IF @@ERROR <> 0
         BEGIN
            SET @n_ErrNo = 82054
            SET @c_ErrMsg = rdt.rdtgetmessage(@n_ErrNo, @c_LangCode, 'DSP')  -- UpdCCDetailFail
            GOTO RollBackTran
         END
      END

      SET @n_Qty = @n_Qty - @nQTY_PD

      IF @n_Qty < 0
      BEGIN
         SET @n_Qty = 0
      END

      FETCH NEXT FROM CursorCCDetail INTO @c_CCDetailKey, @c_CCLot, @c_CCLoc, @c_CCID
   END -- While Loop for PickDetail Key
   CLOSE CursorCCDetail
   DEALLOCATE CursorCCDetail

   IF @n_Qty > 0  -- Update Remaining Qty to last of the CCDetail line with Same Loc and SKU
   BEGIN
      UPDATE dbo.CCDEtail WITH (ROWLOCK) SET
        Qty      = CASE WHEN @c_CountNo = '1' THEN Qty  + @n_Qty ELSE Qty  END
      , Qty_Cnt2 = CASE WHEN @c_CountNo = '2' THEN Qty_Cnt2 + @n_Qty ELSE Qty_Cnt2 END
      , Qty_Cnt3 = CASE WHEN @c_CountNo = '3' THEN Qty_Cnt3 + @n_Qty ELSE Qty_Cnt3 END
      , Status  = '2'
      , Counted_Cnt1 = CASE WHEN @c_CountNo = '1' THEN '1' ELSE Counted_Cnt1 END
      , Counted_Cnt2 = CASE WHEN @c_CountNo = '2' THEN '1' ELSE Counted_Cnt2 END
      , Counted_Cnt3 = CASE WHEN @c_CountNo = '3' THEN '1' ELSE Counted_Cnt3 END
      , EditWho_Cnt1 = CASE WHEN @c_CountNo = '1' THEN @c_UserName ELSE EditWho_Cnt1 END
      , EditWho_Cnt2 = CASE WHEN @c_CountNo = '2' THEN @c_UserName ELSE EditWho_Cnt2 END
      , EditWho_Cnt3 = CASE WHEN @c_CountNo = '3' THEN @c_UserName ELSE EditWho_Cnt3 END
      , EditDate_Cnt1 = CASE WHEN @c_CountNo = '1' THEN GETDATE() ELSE EditDate_Cnt1 END
      , EditDate_Cnt2 = CASE WHEN @c_CountNo = '2' THEN GETDATE() ELSE EditDate_Cnt2 END
      , EditDate_Cnt3 = CASE WHEN @c_CountNo = '3' THEN GETDATE() ELSE EditDate_Cnt3 END
      WHERE CCKey = @c_CCKey
      AND  CCDetailKey = @c_CCDetailKey

      IF @@ERROR <> 0
      BEGIN
         SET @n_ErrNo = 82060
         SET @c_ErrMsg = rdt.rdtgetmessage(@n_ErrNo, @c_LangCode, 'DSP')  -- UpdCCDetailFail
         GOTO RollBackTran
      END
   END

   IF NOT EXISTS ( SELECT 1
                  FROM CCDetail c WITH (NOLOCK)
                  WHERE c.CCKey     = @c_CCKey
                  AND c.Storerkey   = @c_StorerKey
                  AND c.SKU         = @c_SKU
                  AND c.LOC         = @c_LOC )
   BEGIN
      EXECUTE dbo.nspg_GetKey
         'CCDETAILKEY',
         10 ,
         @c_CCDetailKey OUTPUT,
         @b_success OUTPUT,
         @n_ErrNo OUTPUT,
         @c_errmsg OUTPUT

      IF @b_success <> 1
      BEGIN
         SET @n_ErrNo = 82055
         SET @c_ErrMsg = rdt.rdtgetmessage(@n_ErrNo, @c_LangCode, 'DSP')  -- GetKeyFail
         GOTO RollBackTran
      END

      SELECT TOP 1 @c_CCSheetNo = c.CCSheetNo
      FROM CCDetail c (NOLOCK)
      WHERE c.CCKey = @c_CCKey
      AND c.Loc = @c_LOC

      IF ISNULL(RTRIM(@c_CCSheetNo), '') = ''
      BEGIN
         EXECUTE dbo.nspg_GetKey
            'CCSheetNo',
            10 ,
            @c_CCSheetNo       OUTPUT,
            @b_success        OUTPUT,
            @n_ErrNo            OUTPUT,
            @c_errmsg         OUTPUT

         IF @b_success <> 1
         BEGIN
            SET @n_ErrNo = 82056
            SET @c_ErrMsg = rdt.rdtgetmessage(@n_ErrNo, @c_LangCode, 'DSP')  -- GetCCSheetNoFail
            GOTO RollBackTran
         END
      END

      SET @dt_Lottable05Value = GETDATE()

      IF ISNULL(@c_CountNo,'') = '1'
      BEGIN
         INSERT INTO CCDETAIL (CCKey, CCDetailKey, CCSheetNo, TagNo, Storerkey, Sku, Lot,
                     Loc, Id, SystemQty, Qty, Lottable01, Lottable02, Lottable03,
                     Lottable04, Lottable05, FinalizeFlag, Status, Counted_Cnt1, EditWho_Cnt1, EditDate_Cnt1)
         VALUES (@c_CCKey, @c_CCDetailKey, @c_CCSheetNo, '', @c_StorerKey, @c_SKU,
                 '', @c_LOC, '', 0, @c_Qty, @c_Lottable01Value, @c_Lottable02Value, @c_Lottable03Value,
                 NULL, @dt_Lottable05Value, 'N', '4', '1', @c_UserName, GETDATE())

         IF @@ERROR <> 0
         BEGIN
            SET @n_ErrNo = 82057
            SET @c_ErrMsg = rdt.rdtgetmessage(@n_ErrNo, @c_LangCode, 'DSP')  -- InsertCCFail
            GOTO RollBackTran
         END
      END
      ELSE IF ISNULL(@c_CountNo,'') = '2'
      BEGIN
         INSERT INTO CCDETAIL (CCKey, CCDetailKey, CCSheetNo, TagNo, Storerkey, Sku, Lot,
                     Loc, Id, SystemQty, Qty_Cnt2, Lottable01, Lottable02, Lottable03,
                     Lottable04, Lottable05, FinalizeFlag, Status, Counted_Cnt2, EditWho_Cnt2, EditDate_Cnt2)
         VALUES (@c_CCKey, @c_CCDetailKey, @c_CCSheetNo, '', @c_StorerKey, @c_SKU,
                 '', @c_LOC, '', 0, @c_Qty, @c_Lottable01Value, @c_Lottable02Value, @c_Lottable03Value,
                 NULL, @dt_Lottable05Value, 'N', '4', '1', @c_UserName, GETDATE())

         IF @@ERROR <> 0
         BEGIN
            SET @n_ErrNo = 82058
            SET @c_ErrMsg = rdt.rdtgetmessage(@n_ErrNo, @c_LangCode, 'DSP')  -- InsertCCFail
            GOTO RollBackTran
         END
      END
      ELSE IF ISNULL(@c_CountNo,'') = '3'
      BEGIN
         INSERT INTO CCDETAIL (CCKey, CCDetailKey, CCSheetNo, TagNo, Storerkey, Sku, Lot,
                     Loc, Id, SystemQty, Qty_Cnt3, Lottable01, Lottable02, Lottable03,
                     Lottable04, Lottable05, FinalizeFlag, Status, Counted_Cnt3, EditWho_Cnt3, EditDate_Cnt3)
         VALUES (@c_CCKey, @c_CCDetailKey, @c_CCSheetNo, '', @c_StorerKey, @c_SKU,
                 '', @c_LOC, '', 0, @c_Qty, @c_Lottable01Value, @c_Lottable02Value, @c_Lottable03Value,
                 NULL, @dt_Lottable05Value, 'N', '4', '1', @c_UserName, GETDATE())

         IF @@ERROR <> 0
         BEGIN
            SET @n_ErrNo = 82059
            SET @c_ErrMsg = rdt.rdtgetmessage(@n_ErrNo, @c_LangCode, 'DSP')  -- InsertCCFail
            GOTO RollBackTran
         END
      END
   END

   GOTO QUIT

   RollBackTran:
    ROLLBACK TRAN CycleCountTran

   Quit:
    WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started
          COMMIT TRAN CycleCountTran

END -- End Procedure

GO
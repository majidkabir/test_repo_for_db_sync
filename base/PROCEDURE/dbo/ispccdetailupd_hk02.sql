SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: ispCCDetailUpd_HK02                                 */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Update CCDEtail Logic. Distribute qty equally over the      */  
/*          ccdetail line. The last line has the remaining qty.         */
/*          Default lottable05 = count date.                            */
/*          Update LOC.CycleCount for count #1                          */
/*                                                                      */  
/* Called from: rdtfnc_SimpleCC                                         */  
/*                                                                      */  
/* Exceed version: 5.4                                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author      Purposes                                */  
/* 27-06-2018  1.0  James       WMS5140 Created                         */  
/************************************************************************/  

CREATE PROCEDURE [dbo].[ispCCDetailUpd_HK02]  
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
           @nTranCount     INT

   DECLARE @cUserName      NVARCHAR( 18),
           @c_Facility     NVARCHAR( 5),
           @c_CCSheetNo    NVARCHAR( 10)

   DECLARE @c_Lottable11   NVARCHAR( 30)

   SET @cUserName = sUser_sName()

   SET @c_Facility = ''
   SET @c_CCSheetNo = ''

   SELECT @c_Facility = Facility, 
          @c_CCSheetNo = V_String17,
          @c_Lottable11 = I_Field03
   FROM rdt.rdtMobRec WITH (NOLOCK)
   WHERE UserName = @cUserName

   -- If user key in ucc then filter by ucc (lottable11)
   IF NOT EXISTS ( SELECT 1 
                   FROM dbo.CCDetail WITH (NOLOCK)
                   WHERE StorerKey = @c_Storerkey
                   AND   LOC = @c_Loc
                   AND   CCKey = @c_CCKey
                   AND   (( ISNULL( @c_CCSheetNo, '') = '') OR ( CCSheetNo = @c_CCSheetNo))
                   AND   Lottable11 = @c_Lottable11
                   AND   1 = CASE
                         WHEN @c_CountNo = '1' AND FinalizeFlag <> 'Y' THEN 1
                         WHEN @c_CountNo = '2' AND FinalizeFlag_Cnt2 <> 'Y' THEN 1
                         WHEN @c_CountNo = '3' AND FinalizeFlag_Cnt3 <> 'Y' THEN 1
                         ELSE 0 END)
   BEGIN
      SET @c_SKU = @c_Lottable11
      SET @c_Lottable11 = ''

      EXEC dbo.nspg_GETSKU
          @c_StorerKey= @c_Storerkey   OUTPUT
         ,@c_Sku      = @c_SKU         OUTPUT
         ,@b_Success  = @b_Success     OUTPUT
         ,@n_Err      = @n_ErrNo       OUTPUT
         ,@c_ErrMsg   = @c_ErrMsg      OUTPUT
   END
   --ELSE
   --BEGIN
   --   SET @c_SKU = ''
   --END

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
           @cExecStatements      nvarchar(4000),    
           @cExecArguments       nvarchar(4000),  
           @n_Qty                int,  
           @nQTY_PD              int,
           @n_QtyCnt1            int,
           @n_QtyCnt2            int,
           @n_QtyCnt3            int,
           @n_UPDQty             int,
           @n_Ttl_Qty            int,
           @n_Ttl_SystemQty      int

   -- If user key in ucc then filter by ucc (lottable11)
   --IF ISNULL( @c_Lottable11, '') = ''
   --   SET @c_SKU = ''

   IF ISNULL( @c_SKU, '') <> ''
   BEGIN
      -- Check if this sku exists in this loc
       SELECT
         @n_Ttl_SystemQty = ISNULL( SUM( SystemQty), 0),
         @n_Ttl_Qty = CASE WHEN @c_CountNo = '1' THEN ISNULL( SUM( Qty), 0)
                           WHEN @c_CountNo = '2' THEN ISNULL( SUM( Qty_Cnt2), 0)
                           WHEN @c_CountNo = '3' THEN ISNULL( SUM( Qty_Cnt3), 0)
                           ELSE 0 END
         FROM dbo.CCDetail WITH (NOLOCK)
         WHERE StorerKey = @c_Storerkey
         AND   LOC = @c_Loc
         AND   CCKey = @c_CCKey
         AND   (( ISNULL( @c_CCSheetNo, '') = '') OR ( CCSheetNo = @c_CCSheetNo))
         AND   SKU = @c_SKU
         AND   1 = CASE
               WHEN @c_CountNo = '1' AND Counted_Cnt1 = '0' THEN 1
               WHEN @c_CountNo = '2' AND Counted_Cnt2 = '0' THEN 1
               WHEN @c_CountNo = '3' AND Counted_Cnt3 = '0' THEN 1
               ELSE 0 END

      IF @@ROWCOUNT = 0
      BEGIN        
         SET @n_ErrNo = 132568        
         SET @c_ErrMsg = rdt.rdtgetmessage(@n_ErrNo, @c_LangCode, 'DSP')  -- SKU Not in Loc  
         GOTO RollBackTran         
      END 

      IF ( @n_Ttl_Qty + @n_Qty) > @n_Ttl_SystemQty
      BEGIN        
         SET @n_ErrNo = 132569
         SET @c_ErrMsg = rdt.rdtgetmessage(@n_ErrNo, @c_LangCode, 'DSP')  -- QtyOverLocMax  
         GOTO RollBackTran         
      END 
   END

   SET @n_Qty = CAST( @c_Qty AS INT)

   IF ISNULL( @c_Lottable11, '') <> ''
      DECLARE CursorCCDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
      SELECT c.CCDetailKey , c.SystemQty , c.Qty, c.Qty_Cnt2, c.Qty_Cnt3
      FROM CCDetail c WITH (NOLOCK)  
      WHERE c.CCKey     = @c_CCKey   
      AND c.Storerkey   = @c_StorerKey  
      AND c.LOC         = @c_LOC  
      AND ( ( ISNULL( @c_CCSheetNo, '') = '') OR ( c.CCSheetNo = @c_CCSheetNo))
      AND 1 = CASE
        WHEN @c_CountNo = 1 AND FinalizeFlag <> 'Y' THEN 1
        WHEN @c_CountNo = 2 AND FinalizeFlag_Cnt2 <> 'Y' THEN 1
        WHEN @c_CountNo = 3 AND FinalizeFlag_Cnt3 <> 'Y' THEN 1
        ELSE 0 END
      AND 1 = CASE
        WHEN @c_CountNo = 1 AND Lottable11 = @c_Lottable11 THEN 1
        WHEN @c_CountNo = 2 AND Lottable11_Cnt2 = @c_Lottable11 THEN 1
        WHEN @c_CountNo = 3 AND Lottable11_Cnt3 = @c_Lottable11 THEN 1
        ELSE 0 END
      Order By c.CCDetailKey  
   ELSE
      DECLARE CursorCCDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
      SELECT c.CCDetailKey , c.SystemQty , c.Qty, c.Qty_Cnt2, c.Qty_Cnt3
      FROM CCDetail c WITH (NOLOCK)  
      WHERE c.CCKey     = @c_CCKey   
      AND c.Storerkey   = @c_StorerKey  
      AND c.SKU = @c_SKU
      AND c.LOC         = @c_LOC  
      AND ( ( ISNULL( @c_CCSheetNo, '') = '') OR ( c.CCSheetNo = @c_CCSheetNo))
      AND 1 = CASE
        WHEN @c_CountNo = 1 AND FinalizeFlag <> 'Y' THEN 1
        WHEN @c_CountNo = 2 AND FinalizeFlag_Cnt2 <> 'Y' THEN 1
        WHEN @c_CountNo = 3 AND FinalizeFlag_Cnt3 <> 'Y' THEN 1
        ELSE 0 END
      Order By c.CCDetailKey  

   OPEN CursorCCDetail    
   FETCH NEXT FROM CursorCCDetail INTO @c_CCDetailKey, @nQTY_PD, @n_QtyCnt1, @n_QtyCnt3, @n_QtyCnt3
   WHILE @@FETCH_STATUS<>-1    
   BEGIN    

      -- Offset each ccdetail line.
      -- If over the system qty
      IF @c_CountNo = 1
      BEGIN
         IF @nQTY_PD >= ( @n_QtyCnt1 + @n_Qty)
            SET @n_UPDQty = @n_Qty
         ELSE
            SET @n_UPDQty = @nQTY_PD

         IF @nQTY_PD >= ( @n_QtyCnt1 + @n_UPDQty)
         BEGIN
            UPDATE dbo.CCDEtail WITH (ROWLOCK) SET 
                Qty      = CASE WHEN @c_CountNo = '1' THEN Qty + @n_UPDQty ELSE Qty END  
              , Qty_Cnt2 = CASE WHEN @c_CountNo = '2' THEN Qty_Cnt2 + @n_UPDQty ELSE Qty_Cnt2 END  
              , Qty_Cnt3 = CASE WHEN @c_CountNo = '3' THEN Qty_Cnt3 + @n_UPDQty ELSE Qty_Cnt3 END  
              , Status  = '2'  
              , Counted_Cnt1 = CASE WHEN @c_CountNo = '1' THEN '1' ELSE Counted_Cnt1 END  
              , Counted_Cnt2 = CASE WHEN @c_CountNo = '2' THEN '1' ELSE Counted_Cnt2 END  
              , Counted_Cnt3 = CASE WHEN @c_CountNo = '3' THEN '1' ELSE Counted_Cnt3 END  
              , EditWho_Cnt1 = CASE WHEN @c_CountNo = '1' THEN @cUserName ELSE EditWho_Cnt1 END  
              , EditWho_Cnt2 = CASE WHEN @c_CountNo = '2' THEN @cUserName ELSE EditWho_Cnt2 END  
              , EditWho_Cnt3 = CASE WHEN @c_CountNo = '3' THEN @cUserName ELSE EditWho_Cnt3 END  
              , EditDate_Cnt1 = CASE WHEN @c_CountNo = '1' THEN GETDATE() ELSE EditDate_Cnt1 END  
              , EditDate_Cnt2 = CASE WHEN @c_CountNo = '2' THEN GETDATE() ELSE EditDate_Cnt2 END  
              , EditDate_Cnt3 = CASE WHEN @c_CountNo = '3' THEN GETDATE() ELSE EditDate_Cnt3 END  
            WHERE CCKey = @c_CCKey  
            AND CCDetailKey = @c_CCDetailKey  

            IF @@ERROR <> 0     
            BEGIN    
                SET @n_ErrNo = 132551  
                SET @c_ErrMsg = rdt.rdtgetmessage(@n_ErrNo, @c_LangCode, 'DSP')  -- UpdCCDetailFail  
                GOTO RollBackTran    
            END   

            SET @n_Qty = @n_Qty - @n_UPDQty    
         END
      END

      IF @c_CountNo = 2
      BEGIN
         IF @n_QtyCnt1 >= ( @n_QtyCnt2 + @n_Qty)
            SET @n_UPDQty = @n_Qty
         ELSE
            SET @n_UPDQty = @n_QtyCnt1

         IF @n_QtyCnt1 >= ( @n_QtyCnt2 + @n_UPDQty)
         BEGIN
            UPDATE dbo.CCDEtail WITH (ROWLOCK) SET 
                Qty      = CASE WHEN @c_CountNo = '1' THEN Qty + @n_UPDQty ELSE Qty END  
              , Qty_Cnt2 = CASE WHEN @c_CountNo = '2' THEN Qty_Cnt2 + @n_UPDQty ELSE Qty_Cnt2 END  
              , Qty_Cnt3 = CASE WHEN @c_CountNo = '3' THEN Qty_Cnt3 + @n_UPDQty ELSE Qty_Cnt3 END  
              , Status  = '2'  
              , Counted_Cnt1 = CASE WHEN @c_CountNo = '1' THEN '1' ELSE Counted_Cnt1 END  
              , Counted_Cnt2 = CASE WHEN @c_CountNo = '2' THEN '1' ELSE Counted_Cnt2 END  
              , Counted_Cnt3 = CASE WHEN @c_CountNo = '3' THEN '1' ELSE Counted_Cnt3 END  
              , EditWho_Cnt1 = CASE WHEN @c_CountNo = '1' THEN @cUserName ELSE EditWho_Cnt1 END  
              , EditWho_Cnt2 = CASE WHEN @c_CountNo = '2' THEN @cUserName ELSE EditWho_Cnt2 END  
              , EditWho_Cnt3 = CASE WHEN @c_CountNo = '3' THEN @cUserName ELSE EditWho_Cnt3 END  
              , EditDate_Cnt1 = CASE WHEN @c_CountNo = '1' THEN GETDATE() ELSE EditDate_Cnt1 END  
              , EditDate_Cnt2 = CASE WHEN @c_CountNo = '2' THEN GETDATE() ELSE EditDate_Cnt2 END  
              , EditDate_Cnt3 = CASE WHEN @c_CountNo = '3' THEN GETDATE() ELSE EditDate_Cnt3 END  
            WHERE CCKey = @c_CCKey  
            AND CCDetailKey = @c_CCDetailKey  

            IF @@ERROR <> 0     
            BEGIN    
                SET @n_ErrNo = 132552  
                SET @c_ErrMsg = rdt.rdtgetmessage(@n_ErrNo, @c_LangCode, 'DSP')  -- UpdCCDetailFail  
                GOTO RollBackTran    
            END   

            SET @n_Qty = @n_Qty - @n_UPDQty    
         END
      END

      IF @c_CountNo = 3
      BEGIN
         IF @n_QtyCnt2 >= ( @n_QtyCnt3 + @n_Qty)
            SET @n_UPDQty = @n_Qty
         ELSE
            SET @n_UPDQty = @n_QtyCnt2

         IF @n_QtyCnt2 >= ( @n_QtyCnt3 + @n_UPDQty)
         BEGIN
            UPDATE dbo.CCDEtail WITH (ROWLOCK) SET 
                Qty      = CASE WHEN @c_CountNo = '1' THEN Qty + @n_UPDQty ELSE Qty END  
              , Qty_Cnt2 = CASE WHEN @c_CountNo = '2' THEN Qty_Cnt2 + @n_UPDQty ELSE Qty_Cnt2 END  
              , Qty_Cnt3 = CASE WHEN @c_CountNo = '3' THEN Qty_Cnt3 + @n_UPDQty ELSE Qty_Cnt3 END  
              , Status  = '2'  
              , Counted_Cnt1 = CASE WHEN @c_CountNo = '1' THEN '1' ELSE Counted_Cnt1 END  
              , Counted_Cnt2 = CASE WHEN @c_CountNo = '2' THEN '1' ELSE Counted_Cnt2 END  
              , Counted_Cnt3 = CASE WHEN @c_CountNo = '3' THEN '1' ELSE Counted_Cnt3 END  
              , EditWho_Cnt1 = CASE WHEN @c_CountNo = '1' THEN @cUserName ELSE EditWho_Cnt1 END  
              , EditWho_Cnt2 = CASE WHEN @c_CountNo = '2' THEN @cUserName ELSE EditWho_Cnt2 END  
              , EditWho_Cnt3 = CASE WHEN @c_CountNo = '3' THEN @cUserName ELSE EditWho_Cnt3 END  
              , EditDate_Cnt1 = CASE WHEN @c_CountNo = '1' THEN GETDATE() ELSE EditDate_Cnt1 END  
              , EditDate_Cnt2 = CASE WHEN @c_CountNo = '2' THEN GETDATE() ELSE EditDate_Cnt2 END  
              , EditDate_Cnt3 = CASE WHEN @c_CountNo = '3' THEN GETDATE() ELSE EditDate_Cnt3 END  
            WHERE CCKey = @c_CCKey  
            AND CCDetailKey = @c_CCDetailKey  

            IF @@ERROR <> 0     
            BEGIN    
                SET @n_ErrNo = 132553  
                SET @c_ErrMsg = rdt.rdtgetmessage(@n_ErrNo, @c_LangCode, 'DSP')  -- UpdCCDetailFail  
                GOTO RollBackTran    
            END   

            SET @n_Qty = @n_Qty - @n_UPDQty    
         END
      END

      IF @n_Qty = 0 -- Treat as Counted when Qty = 0 and still have same SKU and Loc not counted.  
      BEGIN  

         UPDATE dbo.CCDEtail WITH (ROWLOCK) SET  
              Status  = '2'  
            , Counted_Cnt1 = CASE WHEN @c_CountNo = '1' THEN '1' ELSE Counted_Cnt1 END  
            , Counted_Cnt2 = CASE WHEN @c_CountNo = '2' THEN '1' ELSE Counted_Cnt2 END  
            , Counted_Cnt3 = CASE WHEN @c_CountNo = '3' THEN '1' ELSE Counted_Cnt3 END  
            , EditWho_Cnt1 = CASE WHEN @c_CountNo = '1' THEN @cUserName ELSE EditWho_Cnt1 END  
            , EditWho_Cnt2 = CASE WHEN @c_CountNo = '2' THEN @cUserName ELSE EditWho_Cnt2 END  
            , EditWho_Cnt3 = CASE WHEN @c_CountNo = '3' THEN @cUserName ELSE EditWho_Cnt3 END  
            , EditDate_Cnt1 = CASE WHEN @c_CountNo = '1' THEN GETDATE() ELSE EditDate_Cnt1 END  
            , EditDate_Cnt2 = CASE WHEN @c_CountNo = '2' THEN GETDATE() ELSE EditDate_Cnt2 END  
            , EditDate_Cnt3 = CASE WHEN @c_CountNo = '3' THEN GETDATE() ELSE EditDate_Cnt3 END  
          WHERE CCKey = @c_CCKey  
          AND CCDetailKey = @c_CCDetailKey  

         IF @@ERROR <> 0     
         BEGIN    
            SET @n_ErrNo = 132554  
            SET @c_ErrMsg = rdt.rdtgetmessage(@n_ErrNo, @c_LangCode, 'DSP')  -- UpdCCDetailFail  
            GOTO RollBackTran    
         END     
      END  



      IF @n_Qty < 0   
      BEGIN  
         SET @n_Qty = 0   
      END  

      IF @n_Qty = 0   
         BREAK

      IF EXISTS ( SELECT 1 FROM dbo.CCDetail WITH (NOLOCK)
                  WHERE CCDetailKey = @c_CCDetailKey
                  AND 1 = CASE
                    WHEN @c_CountNo = 1 THEN 0
                    WHEN @c_CountNo = 2 AND ( SystemQty = Qty_Cnt2) AND FinalizeFlag_Cnt2 <> 'Y' THEN 1
                    WHEN @c_CountNo = 3 AND ( SystemQty = Qty_Cnt3) AND FinalizeFlag_Cnt3 <> 'Y' THEN 1
                    ELSE 0 END)
      BEGIN
         UPDATE dbo.CCDetail WITH (ROWLOCK) SET 
            FinalizeFlag_Cnt2 = CASE WHEN @c_CountNo = 2 THEN 'Y' ELSE FinalizeFlag_Cnt2 END,
            FinalizeFlag_Cnt3 = CASE WHEN @c_CountNo = 3 THEN 'Y' ELSE FinalizeFlag_Cnt3 END
         WHERE CCDetailKey = @c_CCDetailKey
         AND 1 = CASE
                    WHEN @c_CountNo = 1 THEN 0
                    WHEN @c_CountNo = 2 AND ( SystemQty = Qty_Cnt2) AND FinalizeFlag_Cnt2 <> 'Y' THEN 1
                    WHEN @c_CountNo = 3 AND ( SystemQty = Qty_Cnt3) AND FinalizeFlag_Cnt3 <> 'Y' THEN 1
                 ELSE 0 END
                    
         IF @@ERROR <> 0
         BEGIN    
            SET @n_ErrNo = 132563  
            SET @c_ErrMsg = rdt.rdtgetmessage(@n_ErrNo, @c_LangCode, 'DSP')  -- UpdCCDtlFail  
            GOTO RollBackTran    
         END 
      END

      FETCH NEXT FROM CursorCCDetail INTO @c_CCDetailKey, @nQTY_PD, @n_QtyCnt1, @n_QtyCnt3, @n_QtyCnt3
   END -- While Loop for PickDetail Key    
   CLOSE CursorCCDetail    
   DEALLOCATE CursorCCDetail    

   IF @n_Qty > 0  -- Update Remaining Qty to last of the CCDetail line with Same Loc and SKU  
   BEGIN  
      UPDATE dbo.CCDEtail WITH (ROWLOCK) SET 
        Qty      = CASE WHEN @c_CountNo = '1' THEN Qty + @n_Qty ELSE Qty  END  
      , Qty_Cnt2 = CASE WHEN @c_CountNo = '2' THEN Qty_Cnt2 + @n_Qty ELSE Qty_Cnt2 END  
      , Qty_Cnt3 = CASE WHEN @c_CountNo = '3' THEN Qty_Cnt3 + @n_Qty ELSE Qty_Cnt3 END  
      , Status  = '2'  
      , Counted_Cnt1 = CASE WHEN @c_CountNo = '1' THEN '1' ELSE Counted_Cnt1 END  
      , Counted_Cnt2 = CASE WHEN @c_CountNo = '2' THEN '1' ELSE Counted_Cnt2 END  
      , Counted_Cnt3 = CASE WHEN @c_CountNo = '3' THEN '1' ELSE Counted_Cnt3 END  
      , EditWho_Cnt1 = CASE WHEN @c_CountNo = '1' THEN @cUserName ELSE EditWho_Cnt1 END  
      , EditWho_Cnt2 = CASE WHEN @c_CountNo = '2' THEN @cUserName ELSE EditWho_Cnt2 END  
      , EditWho_Cnt3 = CASE WHEN @c_CountNo = '3' THEN @cUserName ELSE EditWho_Cnt3 END  
      , EditDate_Cnt1 = CASE WHEN @c_CountNo = '1' THEN GETDATE() ELSE EditDate_Cnt1 END  
      , EditDate_Cnt2 = CASE WHEN @c_CountNo = '2' THEN GETDATE() ELSE EditDate_Cnt2 END  
      , EditDate_Cnt3 = CASE WHEN @c_CountNo = '3' THEN GETDATE() ELSE EditDate_Cnt3 END  
      WHERE CCKey = @c_CCKey  
      AND  CCDetailKey = @c_CCDetailKey  

      IF @@ERROR <> 0     
      BEGIN    
         SET @n_ErrNo = 132560  
         SET @c_ErrMsg = rdt.rdtgetmessage(@n_ErrNo, @c_LangCode, 'DSP')  -- UpdCCDetailFail  
         GOTO RollBackTran    
      END  

      IF EXISTS ( SELECT 1 FROM dbo.CCDetail WITH (NOLOCK)
                  WHERE CCDetailKey = @c_CCDetailKey
                  AND 1 = CASE
                    WHEN @c_CountNo = 1 THEN 0
                    WHEN @c_CountNo = 2 AND ( SystemQty = Qty_Cnt2) AND FinalizeFlag_Cnt2 <> 'Y' THEN 1
                    WHEN @c_CountNo = 3 AND ( SystemQty = Qty_Cnt3) AND FinalizeFlag_Cnt3 <> 'Y' THEN 1
                    ELSE 0 END)
      BEGIN
         UPDATE dbo.CCDetail WITH (ROWLOCK) SET 
            FinalizeFlag_Cnt2 = CASE WHEN @c_CountNo = 2 THEN 'Y' ELSE FinalizeFlag_Cnt2 END,
            FinalizeFlag_Cnt3 = CASE WHEN @c_CountNo = 3 THEN 'Y' ELSE FinalizeFlag_Cnt3 END
         WHERE CCDetailKey = @c_CCDetailKey
         AND 1 = CASE
                    WHEN @c_CountNo = 1 THEN 0
                    WHEN @c_CountNo = 2 AND ( SystemQty = Qty_Cnt2) AND FinalizeFlag_Cnt2 <> 'Y' THEN 1
                    WHEN @c_CountNo = 3 AND ( SystemQty = Qty_Cnt3) AND FinalizeFlag_Cnt3 <> 'Y' THEN 1
                 ELSE 0 END
                    
         IF @@ERROR <> 0
         BEGIN    
            SET @n_ErrNo = 132564  
            SET @c_ErrMsg = rdt.rdtgetmessage(@n_ErrNo, @c_LangCode, 'DSP')  -- UpdCCDtlFail  
            GOTO RollBackTran    
         END 
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
         SET @n_ErrNo = 132555        
         SET @c_ErrMsg = rdt.rdtgetmessage(@n_ErrNo, @c_LangCode, 'DSP')  -- GetKeyFail  
         GOTO RollBackTran         
      END    

      IF ISNULL(RTRIM(@c_CCSheetNo), '') = ''    
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
            SET @n_ErrNo = 132556  
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
                 NULL, @dt_Lottable05Value, 'N', '4', '1', @cUserName, GETDATE())   

         IF @@ERROR <> 0        
         BEGIN        
            SET @n_ErrNo = 132557        
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
                 NULL, @dt_Lottable05Value, 'N', '4', '1', @cUserName, GETDATE())    

         IF @@ERROR <> 0        
         BEGIN        
            SET @n_ErrNo = 132558        
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
                 NULL, @dt_Lottable05Value, 'N', '4', '1', @cUserName, GETDATE())   

         IF @@ERROR <> 0        
         BEGIN        
            SET @n_ErrNo = 132559        
            SET @c_ErrMsg = rdt.rdtgetmessage(@n_ErrNo, @c_LangCode, 'DSP')  -- InsertCCFail      
            GOTO RollBackTran        
         END               
      END       

      IF EXISTS ( SELECT 1 FROM dbo.CCDetail WITH (NOLOCK)
                  WHERE CCDetailKey = @c_CCDetailKey
                  AND 1 = CASE
                    WHEN @c_CountNo = 1 THEN 0
                    WHEN @c_CountNo = 2 AND ( SystemQty = Qty_Cnt2) AND FinalizeFlag_Cnt2 <> 'Y' THEN 1
                    WHEN @c_CountNo = 3 AND ( SystemQty = Qty_Cnt3) AND FinalizeFlag_Cnt3 <> 'Y' THEN 1
                    ELSE 0 END)
      BEGIN
         UPDATE dbo.CCDetail WITH (ROWLOCK) SET 
            FinalizeFlag_Cnt2 = CASE WHEN @c_CountNo = 2 THEN 'Y' ELSE FinalizeFlag_Cnt2 END,
            FinalizeFlag_Cnt3 = CASE WHEN @c_CountNo = 3 THEN 'Y' ELSE FinalizeFlag_Cnt3 END
         WHERE CCDetailKey = @c_CCDetailKey
         AND 1 = CASE
                    WHEN @c_CountNo = 1 THEN 0
                    WHEN @c_CountNo = 2 AND ( SystemQty = Qty_Cnt2) AND FinalizeFlag_Cnt2 <> 'Y' THEN 1
                    WHEN @c_CountNo = 3 AND ( SystemQty = Qty_Cnt3) AND FinalizeFlag_Cnt3 <> 'Y' THEN 1
                 ELSE 0 END
                    
         IF @@ERROR <> 0
         BEGIN    
            SET @n_ErrNo = 132565  
            SET @c_ErrMsg = rdt.rdtgetmessage(@n_ErrNo, @c_LangCode, 'DSP')  -- UpdCCDtlFail  
            GOTO RollBackTran    
         END 
      END
   END     

   -- Check if cckey + loc update before loc.cyclecounter
   -- Only need update loc.cyclecounter 1 time per cckey + loc
   IF NOT EXISTS ( SELECT 1 FROM dbo.CCDetail WITH (NOLOCK)
                   WHERE CCKey = @c_CCKey
                   AND   Storerkey = @c_StorerKey  
                   AND   LOC = @c_LOC
                   AND   StatusMsg = '1')
   BEGIN

      UPDATE dbo.LOC WITH (ROWLOCK) SET 
         CycleCounter = ISNULL( CycleCounter, 0) + 1
      WHERE LOC = @c_Loc
      AND   Facility = @c_Facility
      
      IF @@ERROR <> 0
      BEGIN    
         SET @n_ErrNo = 132561  
         SET @c_ErrMsg = rdt.rdtgetmessage(@n_ErrNo, @c_LangCode, 'DSP')  -- UpdCounterFail  
         GOTO RollBackTran    
      END      

      UPDATE TOP (1) dbo.CCDetail WITH (ROWLOCK) SET 
         StatusMsg = '1'
      WHERE CCKey = @c_CCKey
      AND   Storerkey = @c_StorerKey  
      AND   LOC = @c_LOC
      AND   StatusMsg <> '1'
      AND   ( Qty + Qty_Cnt2 + Qty_Cnt3) > 0 -- something counted

      IF @@ERROR <> 0
      BEGIN    
         SET @n_ErrNo = 132562  
         SET @c_ErrMsg = rdt.rdtgetmessage(@n_ErrNo, @c_LangCode, 'DSP')  -- UpdCCDtlFail  
         GOTO RollBackTran    
      END      
   END

   -- Clean up unnecessary ccdetail record
   -- For example add new loc will create a ccdetail record with blank sku
   IF EXISTS ( SELECT 1  
               FROM CCDetail WITH (NOLOCK)  
               WHERE CCKey = @c_CCKey   
               AND   Storerkey = @c_StorerKey  
               AND   SKU = ''   
               AND   LOC = @c_LOC
               AND   Status IN ('0', '4')
               AND   ( Qty + Qty_Cnt2 + Qty_Cnt3) = 0)  -- empty loc
   BEGIN    
      DELETE FROM CCDetail WITH (ROWLOCK)  
      WHERE CCKey = @c_CCKey   
      AND   Storerkey = @c_StorerKey  
      AND   SKU = ''   
      AND   LOC = @c_LOC
      AND   Status IN ('0', '4')
      AND   ( Qty + Qty_Cnt2 + Qty_Cnt3) = 0

      IF @@ERROR <> 0
      BEGIN    
         SET @n_ErrNo = 132566  
         SET @c_ErrMsg = rdt.rdtgetmessage(@n_ErrNo, @c_LangCode, 'DSP')  -- DelCCDtlFail  
         GOTO RollBackTran    
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
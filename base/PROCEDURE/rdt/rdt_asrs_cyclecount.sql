SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_ASRS_CycleCount                                 */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purposes: SOS#315031 Confirm CCDetail for rdtfnc_ASRS_CycleCount     */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 27-Apr-2015 1.0  James       Created                                 */
/************************************************************************/

CREATE PROC [RDT].[rdt_ASRS_CycleCount] (
   @nMobile       INT,              
   @nFunc         INT,              
   @cLangCode     NVARCHAR( 3),              
   @cUserName     NVARCHAR( 15),              
   @cCCRefNo      NVARCHAR( 10),
   @cCCSheetNo    NVARCHAR( 10),
   @nCCCountNo    INT,   
   @cStorerKey    NVARCHAR( 15),
   @cCCDetailKey  NVARCHAR( 10),
   @nQTY          INT,   
   @cSKU          NVARCHAR( 20),
   @cLOC          NVARCHAR( 10),
   @cID           NVARCHAR( 18),
   @cLottable01   NVARCHAR( 18),
   @cLottable02   NVARCHAR( 18),
   @cLottable03   NVARCHAR( 18),
   @dLottable04   DATETIME, 
   @dLottable05   DATETIME, 
   @cLottable06   NVARCHAR( 30), 
   @cLottable07   NVARCHAR( 30), 
   @cLottable08   NVARCHAR( 30), 
   @cLottable09   NVARCHAR( 30), 
   @cLottable10   NVARCHAR( 30), 
   @cLottable11   NVARCHAR( 30), 
   @cLottable12   NVARCHAR( 30), 
   @dLottable13   DATETIME, 
   @dLottable14   DATETIME, 
   @dLottable15   DATETIME, 
   @cOption       NVARCHAR( 1),
   @nErrNo        INT            OUTPUT, 
   @cErrMsg       NVARCHAR( 20)  OUTPUT  -- screen limitation, 20 char max
) AS
BEGIN
   
   SET NOCOUNT ON              
   SET ANSI_NULLS OFF              
   SET QUOTED_IDENTIFIER OFF              
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE  @nTranCount       INT, 
            @bSuccess         INT, 
            @cNewCCDetailKey  NVARCHAR( 10)

   SET @nTranCount = @@TRANCOUNT            
                
   BEGIN TRAN            
   SAVE TRAN Cfm_CCDetail         
   
   IF @cOption = 1
   BEGIN
      SELECT TOP 1 @cLOC = LOC 
      FROM dbo.LOTxLOCxID WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND   ID = @cID
      AND   Qty > 0

      SET @bsuccess = 0

      EXECUTE dbo.nspg_GetKey
         'CCDETAILKEY', 
         10 ,
         @cNewCCDetailKey  OUTPUT,
         @bSuccess         OUTPUT,
         @nErrNo           OUTPUT,
         @cErrMsg          OUTPUT
   
      IF @bSuccess <> 1
      BEGIN
         SET @nErrNo = 53951
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- GetDetKey fail
         GOTO RollBackTran 
      END

      -- Default Lottable05 if RCP_DATE
      IF (SELECT Lottable05Label FROM dbo.SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU) = 'RCP_DATE' AND @dLottable05 IS NULL
         SET @dLottable05 = CONVERT( NVARCHAR(8), GETDATE(), 112)


      INSERT INTO dbo.CCDETAIL
         (CCKey,        CCDetailKey,     CCSheetNo,       StorerKey,      SKU,              LOT, 
         LOC,           ID,              RefNo,           Status,
         Qty,           Lottable01,      Lottable02,      Lottable03,      Lottable04,      Lottable05, 
         Lottable06,      Lottable07,      Lottable08,      Lottable09,      Lottable10, 
         Lottable11,      Lottable12,      Lottable13,      Lottable14,      Lottable15, 
         EditDate_Cnt1, EditWho_Cnt1,    Counted_Cnt1,
         Qty_Cnt2,      Lottable01_Cnt2, Lottable02_Cnt2, Lottable03_Cnt2, Lottable04_Cnt2, Lottable05_Cnt2, 
         Lottable06_Cnt2, Lottable07_Cnt2, Lottable08_Cnt2, Lottable09_Cnt2, Lottable10_Cnt2, 
         Lottable11_Cnt2, Lottable12_Cnt2, Lottable13_Cnt2, Lottable14_Cnt2, Lottable15_Cnt2, 
         EditDate_Cnt2, EditWho_Cnt2,    Counted_Cnt2,
         Qty_Cnt3,      Lottable01_Cnt3, Lottable02_Cnt3, Lottable03_Cnt3, Lottable04_Cnt3, Lottable05_Cnt3,
         Lottable06_Cnt3, Lottable07_Cnt3, Lottable08_Cnt3, Lottable09_Cnt3, Lottable10_Cnt3, 
         Lottable11_Cnt3, Lottable12_Cnt3, Lottable13_Cnt3, Lottable14_Cnt3, Lottable15_Cnt3, 
         EditDate_Cnt3, EditWho_Cnt3,    Counted_Cnt3)
      VALUES (
         @cCCRefNo, @cNewCCDetailKey, @cCCSheetNo, @cStorerKey, @cSKU, '', 
         @cLOC, @cID, '', '4',
         CASE WHEN @nCCCountNo = 1 THEN @nQty ELSE 0 END,
         CASE WHEN @nCCCountNo = 1 THEN @cLottable01 ELSE NULL END,
         CASE WHEN @nCCCountNo = 1 THEN @cLottable02 ELSE NULL END,
         CASE WHEN @nCCCountNo = 1 THEN @cLottable03 ELSE NULL END,  
         CASE WHEN @nCCCountNo = 1 AND  @dLottable04 IS NOT NULL THEN @dLottable04 ELSE NULL END,
         CASE WHEN @nCCCountNo = 1 AND  @dLottable05 IS NOT NULL THEN @dLottable05 ELSE NULL END,
         CASE WHEN @nCCCountNo = 1 THEN @cLottable06 ELSE NULL END,
         CASE WHEN @nCCCountNo = 1 THEN @cLottable07 ELSE NULL END,
         CASE WHEN @nCCCountNo = 1 THEN @cLottable08 ELSE NULL END,  
         CASE WHEN @nCCCountNo = 1 THEN @cLottable09 ELSE NULL END,
         CASE WHEN @nCCCountNo = 1 THEN @cLottable10 ELSE NULL END,  
         CASE WHEN @nCCCountNo = 1 THEN @cLottable11 ELSE NULL END,
         CASE WHEN @nCCCountNo = 1 THEN @cLottable12 ELSE NULL END,  
         CASE WHEN @nCCCountNo = 1 AND  @dLottable13 IS NOT NULL THEN @dLottable13 ELSE NULL END,
         CASE WHEN @nCCCountNo = 1 AND  @dLottable14 IS NOT NULL THEN @dLottable14 ELSE NULL END,
         CASE WHEN @nCCCountNo = 1 AND  @dLottable15 IS NOT NULL THEN @dLottable15 ELSE NULL END,
         CASE WHEN @nCCCountNo = 1 THEN GetDate() ELSE NULL END,
         CASE WHEN @nCCCountNo = 1 THEN @cUserName ELSE NULL END,
         CASE WHEN @nCCCountNo = 1 THEN '1' ELSE '0' END,
         CASE WHEN @nCCCountNo = 2 THEN @nQty ELSE 0 END,
         CASE WHEN @nCCCountNo = 2 THEN @cLottable01 ELSE NULL END,
         CASE WHEN @nCCCountNo = 2 THEN @cLottable02 ELSE NULL END,
         CASE WHEN @nCCCountNo = 2 THEN @cLottable03 ELSE NULL END,  
         CASE WHEN @nCCCountNo = 2 AND  @dLottable04 IS NOT NULL THEN @dLottable04 ELSE NULL END,
         CASE WHEN @nCCCountNo = 2 AND  @dLottable05 IS NOT NULL THEN @dLottable05 ELSE NULL END, 
         CASE WHEN @nCCCountNo = 2 THEN @cLottable06 ELSE NULL END,
         CASE WHEN @nCCCountNo = 2 THEN @cLottable07 ELSE NULL END,
         CASE WHEN @nCCCountNo = 2 THEN @cLottable08 ELSE NULL END,  
         CASE WHEN @nCCCountNo = 2 THEN @cLottable09 ELSE NULL END,
         CASE WHEN @nCCCountNo = 2 THEN @cLottable10 ELSE NULL END,  
         CASE WHEN @nCCCountNo = 2 THEN @cLottable11 ELSE NULL END,
         CASE WHEN @nCCCountNo = 2 THEN @cLottable12 ELSE NULL END,  
         CASE WHEN @nCCCountNo = 2 AND  @dLottable13 IS NOT NULL THEN @dLottable13 ELSE NULL END,
         CASE WHEN @nCCCountNo = 2 AND  @dLottable14 IS NOT NULL THEN @dLottable14 ELSE NULL END,
         CASE WHEN @nCCCountNo = 2 AND  @dLottable15 IS NOT NULL THEN @dLottable15 ELSE NULL END,
         CASE WHEN @nCCCountNo = 2 THEN GetDate() ELSE NULL END,
         CASE WHEN @nCCCountNo = 2 THEN @cUserName ELSE NULL END,
         CASE WHEN @nCCCountNo = 2 THEN '1' ELSE '0' END,         
         CASE WHEN @nCCCountNo = 3 THEN @nQty ELSE 0 END,
         CASE WHEN @nCCCountNo = 3 THEN @cLottable01 ELSE NULL END,
         CASE WHEN @nCCCountNo = 3 THEN @cLottable02 ELSE NULL END,
         CASE WHEN @nCCCountNo = 3 THEN @cLottable03 ELSE NULL END,  
         CASE WHEN @nCCCountNo = 3 AND  @dLottable04 IS NOT NULL THEN @dLottable04 ELSE NULL END,
         CASE WHEN @nCCCountNo = 3 AND  @dLottable05 IS NOT NULL THEN @dLottable05 ELSE NULL END, 
         CASE WHEN @nCCCountNo = 3 THEN @cLottable06 ELSE NULL END,
         CASE WHEN @nCCCountNo = 3 THEN @cLottable07 ELSE NULL END,
         CASE WHEN @nCCCountNo = 3 THEN @cLottable08 ELSE NULL END,  
         CASE WHEN @nCCCountNo = 3 THEN @cLottable09 ELSE NULL END,
         CASE WHEN @nCCCountNo = 3 THEN @cLottable10 ELSE NULL END,  
         CASE WHEN @nCCCountNo = 3 THEN @cLottable11 ELSE NULL END,
         CASE WHEN @nCCCountNo = 3 THEN @cLottable12 ELSE NULL END,  
         CASE WHEN @nCCCountNo = 3 AND  @dLottable13 IS NOT NULL THEN @dLottable13 ELSE NULL END,
         CASE WHEN @nCCCountNo = 3 AND  @dLottable14 IS NOT NULL THEN @dLottable14 ELSE NULL END,
         CASE WHEN @nCCCountNo = 3 AND  @dLottable15 IS NOT NULL THEN @dLottable15 ELSE NULL END,
         CASE WHEN @nCCCountNo = 3 THEN GetDate() ELSE NULL END,
         CASE WHEN @nCCCountNo = 3 THEN @cUserName ELSE NULL END,
         CASE WHEN @nCCCountNo = 3 THEN '1' ELSE '0' END)

      IF @@ERROR <> 0 
      BEGIN
         SET @nErrNo = 53952
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Add CCDET fail
         GOTO RollBackTran
      END
   END
   ELSE IF @cOption = 2
   BEGIN
      UPDATE dbo.CCDETAIL WITH (ROWLOCK)
      SET   
         Status        = CASE WHEN Status = '0' THEN '2' ELSE Status END,
         QTY           = CASE WHEN @nCCCountNo = 1 THEN @nQTY ELSE QTY END,
         Counted_Cnt1  = CASE WHEN @nCCCountNo = 1 THEN '1' ELSE Counted_Cnt1 END,
         EditDate_Cnt1 = CASE WHEN @nCCCountNo = 1 THEN GETDATE() ELSE EditDate_Cnt1 END,
         EditWho_Cnt1  = CASE WHEN @nCCCountNo = 1 THEN @cUserName ELSE EditWho_Cnt1 END,      
         QTY_Cnt2      = CASE WHEN @nCCCountNo = 2 THEN @nQTY ELSE QTY_Cnt2 END,
         Counted_Cnt2  = CASE WHEN @nCCCountNo = 2 THEN '1' ELSE Counted_Cnt2 END,
         EditDate_Cnt2 = CASE WHEN @nCCCountNo = 2 THEN GETDATE() ELSE EditDate_Cnt2 END,
         EditWho_Cnt2  = CASE WHEN @nCCCountNo = 2 THEN @cUserName ELSE EditWho_Cnt2 END,      
         QTY_Cnt3      = CASE WHEN @nCCCountNo = 3 THEN @nQTY ELSE QTY_Cnt3 END,
         Counted_Cnt3  = CASE WHEN @nCCCountNo = 3 THEN '1' ELSE Counted_Cnt3 END,
         EditDate_Cnt3 = CASE WHEN @nCCCountNo = 3 THEN GETDATE() ELSE EditDate_Cnt3 END,
         EditWho_Cnt3  = CASE WHEN @nCCCountNo = 3 THEN @cUserName ELSE EditWho_Cnt3 END      
      WHERE CCKey = @cCCRefNo
         AND CCSheetNo = @cCCSheetNo
         AND CCDetailKey = @cCCDetailKey
         AND Status < '9'
        
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 53953
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Upd CCDET fail
         GOTO RollBackTran
      END
   END
   ELSE IF @cOption = 3
   BEGIN
      UPDATE dbo.CCDETAIL WITH (ROWLOCK)
      SET   
         Status        = CASE WHEN Status = '0' THEN '2' ELSE Status END,
         Counted_Cnt1  = CASE WHEN @nCCCountNo = 1 THEN '1' ELSE Counted_Cnt1 END,
         EditDate_Cnt1 = CASE WHEN @nCCCountNo = 1 THEN GETDATE() ELSE EditDate_Cnt1 END,
         EditWho_Cnt1  = CASE WHEN @nCCCountNo = 1 THEN @cUserName ELSE EditWho_Cnt1 END,      
         Counted_Cnt2  = CASE WHEN @nCCCountNo = 2 THEN '1' ELSE Counted_Cnt2 END,
         EditDate_Cnt2 = CASE WHEN @nCCCountNo = 2 THEN GETDATE() ELSE EditDate_Cnt2 END,
         EditWho_Cnt2  = CASE WHEN @nCCCountNo = 2 THEN @cUserName ELSE EditWho_Cnt2 END,      
         Counted_Cnt3  = CASE WHEN @nCCCountNo = 3 THEN '1' ELSE Counted_Cnt3 END,
         EditDate_Cnt3 = CASE WHEN @nCCCountNo = 3 THEN GETDATE() ELSE EditDate_Cnt3 END,
         EditWho_Cnt3  = CASE WHEN @nCCCountNo = 3 THEN @cUserName ELSE EditWho_Cnt3 END      
      WHERE CCKey = @cCCRefNo
         AND CCSheetNo = @cCCSheetNo
         AND CCDetailKey = @cCCDetailKey
         AND Status < '9'
        
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 53953
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Upd CCDET fail
         GOTO RollBackTran
      END
   END
   GOTO QUIT            
                
            
   RollBackTran:            
   ROLLBACK TRAN Cfm_CCDetail        
                
   Quit:            
   WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started            
          COMMIT TRAN Cfm_CCDetail            
END   

GO
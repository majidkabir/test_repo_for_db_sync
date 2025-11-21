SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_CycleCount_SKU_Confirm                          */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Comfirm BOM Count                                           */  
/*                                                                      */  
/* Called from: rdt_CycleCount_SKU_Confirm                              */  
/*                                                                      */  
/* Exceed version: 5.4                                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author      Purposes                                */  
/* 03-JUN-2010 1.0  Shong       Created                                 */  
/* 22-Dec-2011 1.1  Ung         SOS231818 Handle empty LOC no StorerKey */
/* 20-Apr-2017 1.2  James       Remove ANSI_WARNINGS (james01)          */
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_CycleCount_SKU_Confirm] (  
   @nMobile       INT,  
   @cCCRefNo      NVARCHAR( 10),  
   @cCCSheetNo    NVARCHAR( 10),  
   @nCCCountNo    INT,  
   @cStorerKey    NVARCHAR( 15),  
   @cSKU          NVARCHAR( 20),  -- BOM SKU scanned in  
   @cLOC          NVARCHAR( 10),  
   @cID           NVARCHAR( 18),  
   @nQty          INT,   
   @nPackValue    INT,  
   @cUserName     NVARCHAR( 18),  
   @cLottable01   NVARCHAR( 18),  
   @cLottable02   NVARCHAR( 18),  
   @cLottable03   NVARCHAR( 18),  
   @dLottable04   DATETIME,  
   @dLottable05   DATETIME,  
   @cLangCode     NVARCHAR( 3),  
   @nErrNo        INT          OUTPUT,  
   @cErrMsg       NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max  
  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET ANSI_DEFAULTS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE  
      @b_success        INT,  
      @n_err            INT,  
      @c_errmsg         NVARCHAR( 250),  
      @cCCDetailKey     NVARCHAR( 10),  
      @nTranCount       INT,  
      @cParentSKU       NVARCHAR( 20),  
      @cComponentSKU    NVARCHAR( 20),  
      @nBOM_Qty         INT  
  
  
   SET @nTranCount = @@TRANCOUNT  
  
   BEGIN TRAN  
   SAVE TRAN CycleCount_BOM_Confirm  
  
   -- james01  
   IF @dLottable04 = 0     SET @dLottable04 = NULL  
   IF @dLottable05 = 0     SET @dLottable05 = NULL  
     
   -- Truncate the time portion  
   IF @dLottable04 IS NOT NULL  
      SET @dLottable04 = CONVERT( DATETIME, CONVERT( NVARCHAR( 10), @dLottable04, 120), 120)  
   IF @dLottable05 IS NOT NULL  
      SET @dLottable05 = CONVERT( DATETIME, CONVERT( NVARCHAR( 10), @dLottable05, 120), 120)  
  
   -- Start lookup ccdetail lines for offset  
   SELECT TOP 1 @cCCDetailKey = CCDetailKey 
   FROM RDT.RDTCCLOCK WITH (NOLOCK)  
   WHERE Mobile = @nMobile  
      AND CCKey = @cCCRefNo  
      AND SheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN SheetNo ELSE @cCCSheetNo END  
      AND AddWho = @cUserName  
      AND SKU = @cSKU  
      AND LOC = @cLOC  
      AND ID = CASE WHEN ISNULL(@cID, '') = '' THEN ID ELSE @cID END           
      AND Status = '0'  
      AND Lottable01 = CASE WHEN ISNULL(@cLottable01, '') = '' THEN Lottable01 ELSE @cLottable01 END  
      AND Lottable02 = CASE WHEN ISNULL(@cLottable02, '') = '' THEN Lottable02 ELSE @cLottable02 END  
      AND IsNULL( Lottable04, 0) = IsNULL( @dLottable04, 0) -- james01  
      AND IsNULL( Lottable05, 0) = IsNULL( @dLottable05, 0) -- james01  
   ORDER BY CCDetailKey  
  
   IF ISNULL(@cCCDetailKey, '') = ''  
   BEGIN  
      SET @nErrNo = 68516  
      SET @cErrMsg = rdt.rdtgetmessage( 68516, @cLangCode, 'DSP') -- 'Confirm Fail'  
      GOTO RollBackTran  
   END  
  
   UPDATE RDT.RDTCCLOCK WITH (ROWLOCK) SET   
      CountedQty = @nQty,  
      Status = '9',  
      EditWho = @cUserName,  
      EditDate = GETDATE()  
   WHERE CCDetailKey = @cCCDetailKey  
  
   IF @@ERROR <> 0  
   BEGIN  
      SET @nErrNo = 68517  
      SET @cErrMsg = rdt.rdtgetmessage( 68517, @cLangCode, 'DSP') -- 'Confirm Fail'  
      GOTO RollBackTran  
   END  
  
   UPDATE dbo.CCDetail WITH (ROWLOCK) SET   
      Qty = CASE WHEN @nCCCountNo = 1 THEN (@nQty) ELSE Qty END,  
      Qty_Cnt2 = CASE WHEN @nCCCountNo = 2 THEN (@nQty) ELSE Qty_Cnt2 END,  
      Qty_Cnt3 = CASE WHEN @nCCCountNo = 3 THEN (@nQty) ELSE Qty_Cnt3 END,  
      Counted_Cnt1 = CASE WHEN @nCCCountNo = 1 THEN 1 ELSE Counted_Cnt1 END,  
      Counted_Cnt2 = CASE WHEN @nCCCountNo = 2 THEN 1 ELSE Counted_Cnt2 END,  
      Counted_Cnt3 = CASE WHEN @nCCCountNo = 3 THEN 1 ELSE Counted_Cnt3 END,  
      Status = '2',  
      EditWho_Cnt1 = CASE WHEN @nCCCountNo = 1 THEN @cUserName ELSE EditWho_Cnt1 END,  
      EditDate_Cnt1 = CASE WHEN @nCCCountNo = 1 THEN GETDATE() ELSE EditDate_Cnt1 END,  
      EditWho_Cnt2 = CASE WHEN @nCCCountNo = 2 THEN @cUserName ELSE EditWho_Cnt2 END,  
      EditDate_Cnt2 = CASE WHEN @nCCCountNo = 2 THEN GETDATE() ELSE EditDate_Cnt2 END,  
      EditWho_Cnt3 = CASE WHEN @nCCCountNo = 3 THEN @cUserName ELSE EditWho_Cnt3 END,  
      EditDate_Cnt3 = CASE WHEN @nCCCountNo = 3 THEN GETDATE() ELSE EditDate_Cnt3 END  
   WHERE CCDetailKey = @cCCDetailKey  
  
   IF @@ERROR <> 0  
   BEGIN  
      SET @nErrNo = 68518  
      SET @cErrMsg = rdt.rdtgetmessage( 68518, @cLangCode, 'DSP') -- 'Confirm Fail'  
      GOTO RollBackTran  
   END  
  
   GOTO Quit  
  
   RollBackTran:  
      ROLLBACK TRAN CycleCount_BOM_Confirm  
  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
         COMMIT TRAN CycleCount_BOM_Confirm  
END

GO
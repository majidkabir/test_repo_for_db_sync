SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_CycleCount_SKU_Insert                           */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Comfirm BOM Count                                           */  
/*                                                                      */  
/* Called from: rdt_CycleCount_SKU_Insert                               */  
/*                                                                      */  
/* Exceed version: 5.4                                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author      Purposes                                */  
/* 03-JUN-2010 1.0  Shong       Created                                 */  
/* 22-Dec-2011 1.1  Ung         SOS231818 Handle empty LOC no StorerKey */
/* 20-Dec-2017 1.2  James       Remove ANSI_WARNINGS (james01)          */
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_CycleCount_SKU_Insert] (  
   @nMobile       INT,  
   @cCCRefNo      NVARCHAR( 10),  
   @cCCSheetNo    NVARCHAR( 10),  
   @nCCCountNo    INT,  
   @cStorerKey    NVARCHAR( 15),  
   @cSKU          NVARCHAR( 20),  
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
      @nBOM_Qty         INT,  
      @nCC_Qty          INT,  
      @cNewCCDetailKey  NVARCHAR( 10),  
      @cParentSKU       NVARCHAR( 20)  
        
   SET @nTranCount = @@TRANCOUNT  
  
   BEGIN TRAN  
   SAVE TRAN CycleCount_SKU_Insert  
     
        
   IF ISNULL(@cCCSheetNo, '') = ''  
   BEGIN  
      SELECT @cCCSheetNo = MAX(CCSheetNo)  
      FROM dbo.CCDETAIL WITH (NOLOCK)  
      WHERE CCKey = @cCCRefNo  
   END  


   SET @b_success = 0  

   EXECUTE dbo.nspg_GetKey  
      'CCDETAILKEY',   
      10 ,  
      @cNewCCDetailKey  OUTPUT,  
      @b_success        OUTPUT,  
      @n_err            OUTPUT,  
      @c_errmsg         OUTPUT  
        
   IF @b_success <> 1  
   BEGIN  
      SET @nErrNo = 68541  
      SET @cErrMsg = rdt.rdtgetmessage( 68541, @cLangCode, 'DSP') -- GetDetKey fail  
      CLOSE CUR_BOM_COMPONENTSKU  
      DEALLOCATE CUR_BOM_COMPONENTSKU  
      GOTO RollBackTran   
   END  
  
   SET @nCC_Qty = @nQty   
  
   INSERT INTO dbo.CCDETAIL  
      (CCKey,        CCDetailKey,     CCSheetNo,       StorerKey,      SKU,     LOT,   
      LOC,           ID,              RefNo,           Status,  
      Qty,           Lottable01,      Lottable02,      Lottable03,      Lottable04,      Lottable05,   
      EditDate_Cnt1, EditWho_Cnt1,    Counted_Cnt1,  
      Qty_Cnt2,      Lottable01_Cnt2, Lottable02_Cnt2, Lottable03_Cnt2, Lottable04_Cnt2, Lottable05_Cnt2,   
      EditDate_Cnt2, EditWho_Cnt2,    Counted_Cnt2,  
      Qty_Cnt3,      Lottable01_Cnt3, Lottable02_Cnt3, Lottable03_Cnt3, Lottable04_Cnt3, Lottable05_Cnt3,  
      EditDate_Cnt3, EditWho_Cnt3,    Counted_Cnt3)  
   VALUES (  
      @cCCRefNo, @cNewCCDetailKey, ISNULL(@cCCSheetNo, ''), @cStorerKey, @cSKU, '', --@cLOT,   
      @cLOC, ISNULL(@cID, ''), '', '4',  
      CASE WHEN @nCCCountNo = 1 THEN @nCC_Qty ELSE 0 END,  
      CASE WHEN @nCCCountNo = 1 THEN @cLottable01 ELSE NULL END,  
      CASE WHEN @nCCCountNo = 1 THEN @cLottable02 ELSE NULL END,  
      CASE WHEN @nCCCountNo = 1 THEN '' ELSE NULL END,    
      CASE WHEN @nCCCountNo = 1 AND  @dLottable04 IS NOT NULL THEN @dLottable04 ELSE NULL END,  
      CASE WHEN @nCCCountNo = 1 AND  @dLottable05 IS NOT NULL THEN @dLottable05 ELSE NULL END,  
      CASE WHEN @nCCCountNo = 1 THEN GetDate() ELSE NULL END,  
      CASE WHEN @nCCCountNo = 1 THEN @cUserName ELSE NULL END,  
      CASE WHEN @nCCCountNo = 1 THEN '1' ELSE '0' END,  
      CASE WHEN @nCCCountNo = 2 THEN @nCC_Qty ELSE 0 END,  
      CASE WHEN @nCCCountNo = 2 THEN @cLottable01 ELSE NULL END,  
      CASE WHEN @nCCCountNo = 2 THEN @cLottable02 ELSE NULL END,  
      CASE WHEN @nCCCountNo = 2 THEN '' ELSE NULL END,    
      CASE WHEN @nCCCountNo = 2 AND  @dLottable04 IS NOT NULL THEN @dLottable04 ELSE NULL END,  
      CASE WHEN @nCCCountNo = 2 AND  @dLottable05 IS NOT NULL THEN @dLottable05 ELSE NULL END,   
      CASE WHEN @nCCCountNo = 2 THEN GetDate() ELSE NULL END,  
      CASE WHEN @nCCCountNo = 2 THEN @cUserName ELSE NULL END,  
      CASE WHEN @nCCCountNo = 2 THEN '1' ELSE '0' END,           
      CASE WHEN @nCCCountNo = 3 THEN @nCC_Qty ELSE 0 END,  
      CASE WHEN @nCCCountNo = 3 THEN @cLottable01 ELSE NULL END,  
      CASE WHEN @nCCCountNo = 3 THEN @cLottable02 ELSE NULL END,  
      CASE WHEN @nCCCountNo = 3 THEN '' ELSE NULL END,    
      CASE WHEN @nCCCountNo = 3 AND  @dLottable04 IS NOT NULL THEN @dLottable04 ELSE NULL END,  
      CASE WHEN @nCCCountNo = 3 AND  @dLottable05 IS NOT NULL THEN @dLottable05 ELSE NULL END,   
      CASE WHEN @nCCCountNo = 3 THEN GetDate() ELSE NULL END,  
      CASE WHEN @nCCCountNo = 3 THEN @cUserName ELSE NULL END,  
      CASE WHEN @nCCCountNo = 3 THEN '1' ELSE '0' END)  
  
   IF @@ERROR <> 0  
   BEGIN  
      SET @nErrNo = 68542  
      SET @cErrMsg = rdt.rdtgetmessage( 68542, @cLangCode, 'DSP') -- Inst CCD Fail  
      CLOSE CUR_BOM_COMPONENTSKU  
      DEALLOCATE CUR_BOM_COMPONENTSKU  
      GOTO RollBackTran   
   END  
  
   GOTO Quit  
  
   RollBackTran:  
      ROLLBACK TRAN CycleCount_SKU_Insert  
  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
         COMMIT TRAN CycleCount_SKU_Insert  
END

GO
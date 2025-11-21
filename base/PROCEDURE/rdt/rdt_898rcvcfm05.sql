SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

  
  
/***************************************************************************/  
/* Store procedure: rdt_898RcvCfm05                                        */  
/* Copyright      : LF Logistics                                           */  
/*                                                                         */  
/* Date       Rev  Author  Purposes                                        */  
/* 2018-11-09 1.0  ChewKP  WMS-6931 Created                                */  
/***************************************************************************/  
CREATE PROC [RDT].[rdt_898RcvCfm05](  
   @nFunc          INT,  
   @nMobile        INT,  
   @cLangCode      NVARCHAR( 3),  
   @nErrNo         INT           OUTPUT,  
   @cErrMsg        NVARCHAR( 20) OUTPUT,   
   @cStorerKey     NVARCHAR( 15),  
   @cFacility      NVARCHAR( 5),  
   @cReceiptKey    NVARCHAR( 10),  
   @cPOKey         NVARCHAR( 10),  
   @cToLOC         NVARCHAR( 10),  
   @cToID          NVARCHAR( 18),  
   @cSKUCode       NVARCHAR( 20),  
   @cSKUUOM        NVARCHAR( 10),  
   @nSKUQTY        INT,  
   @cUCC           NVARCHAR( 20),  
   @cUCCSKU        NVARCHAR( 20),  
   @nUCCQTY        INT,  
   @cCreateUCC     NVARCHAR( 1),  
   @cLottable01    NVARCHAR( 18),  
   @cLottable02    NVARCHAR( 18),  
   @cLottable03    NVARCHAR( 18),  
   @dLottable04    DATETIME,  
   @dLottable05    DATETIME,  
   @nNOPOFlag      INT,  
   @cConditionCode NVARCHAR( 10),  
   @cSubreasonCode NVARCHAR( 10)  
) AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @curPDUCC       CURSOR  
   DECLARE @nQTY_Bal       INT  
          ,@nCount         INT  
          ,@nRowRef        INT  
     
   IF NOT EXISTS ( SELECT 1 FROM rdt.rdtUCCReceive2Log WITH (NOLOCK)   
                   WHERE StorerKey = @cStorerKey  
                   AND ReceiptKey = @cReceiptKey  
                   AND UCCNo = @cUCC)  
   BEGIN  
      INSERT INTO rdt.rdtUCCReceive2Log (ReceiptKey, ReceiptLineNumber, POKey, StorerKey, SKU, UOM, QtyExpected, QtyReceived, ToID, ToLoc, UCCNo, EditWho, EditDate, Status, AddDate, AddWho, Lottable01, Lottable09 )   
      SELECT @cReceiptKey, '', @cPOKey, @cStorerKey, SKU, @cSKUUOM, Qty , Qty, @cTOID, @cToLoc, UCCNo, SUSER_NAME(), GetDate() , '1', GetDate(), SUSER_NAME(), UCC_RowRef, UserDefined09  
      FROM dbo.UCC WITH (NOLOCK)   
      WHERE StorerKey = @cStorerKey  
      AND UCCNo = @cUCC  
        
              
      IF @@ERROR <> 0   
      BEGIN  
         SET @nErrNo = 131651  
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --UpdUCCLogFail  
         GOTO Quit  
      END  
        
   END  
   --SELECT @cUCCSKU '@cUCCSKU' , @nUCCQty '@nUCCQty'   
     
   EXEC rdt.rdt_Receive      
      @nFunc          = @nFunc,  
      @nMobile        = @nMobile,  
      @cLangCode      = @cLangCode,  
      @nErrNo         = @nErrNo  OUTPUT,  
      @cErrMsg        = @cErrMsg OUTPUT,  
      @cStorerKey     = @cStorerKey,  
      @cFacility      = @cFacility,  
      @cReceiptKey    = @cReceiptKey,  
      @cPOKey         = @cPOKey,  
      @cToLOC         = @cToLOC,  
      @cToID          = @cTOID,  
      @cSKUCode       = @cSKUCode,  
      @cSKUUOM        = @cSKUUOM,  
      @nSKUQTY        = @nSKUQTY,  
      @cUCC           = @cUCC,  
      @cUCCSKU        = @cUCCSKU,  
      @nUCCQTY        = @nUCCQTY,  
      @cCreateUCC     = @cCreateUCC,  
      @cLottable01    = @cLottable01,  
      @cLottable02    = @cLottable02,     
      @cLottable03    = @cLottable03,  
      @dLottable04    = @dLottable04,  
      @dLottable05    = @dLottable05,  
      @nNOPOFlag      = @nNOPOFlag,  
      @cConditionCode = @cConditionCode,  
      @cSubreasonCode = @cSubreasonCode  
    
  SELECT @nCount = Count (SKU)  
  FROM dbo.UCC WITH (NOLOCK)   
  WHERE StorerKey = @cStorerKey  
  AND UCCNo = @cUCC   
  AND SKU = @cUCCSKU   
  
  --SELECT * FROM UCC (NOLOCK) WHERE UCCNo = @cUCC Order By SKU   
  --PRINT @cUCCSKU  
   --SELECT Lottable01, * FROM rdt.rdtUCCReceive2Log WITH (NOLOCK)   
   --where UCcno = @cUCc  
    
  SET @nRowRef = 0   
  
  SELECT TOP 1 @nRowRef = RowRef FROM rdt.rdtUCCReceive2Log WITH (NOLOCK)   
  WHERE StorerKey = @cStorerKey  
  AND ReceiptKey = @cReceiptKey  
  AND UCCNo = @cUCC  
  AND SKU = @CUCCSKU  
  AND QtyExpected = @nUCCQty   
  AND Status = '1'   
  ORDER BY Lottable01   
    
  UPDATE rdt.rdtUCCReceive2Log WITH (ROWLOCK)   
  SET Status = '9'   
  WHERE RowRef = @nRowRef  
    
  IF @nCount > 1   
  BEGIN  
         
       SET @nRowRef = 0   
  
       SET @curPDUCC = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
       SELECT QtyExpected , Lottable01  
       FROM rdt.rdtUCCReceive2Log  WITH (NOLOCK)   
       WHERE StorerKey = @cStorerKey  
       AND UCCNo = @cUCC  
       AND SKU = @cUCCSKU   
       --AND ExpectedQty <> @nUCCQty  
       --AND Status = '1'  
  
       -- Loop PickDetail  
       OPEN @curPDUCC  
       FETCH NEXT FROM @curPDUCC INTO @nQTY_Bal, @nRowRef  
       WHILE @@FETCH_STATUS = 0  
       BEGIN  
           
           
         -- Update Qty   
         UPDATE dbo.UCC WITH (ROWLOCK)   
         SET --Status = '0'  
             Qty = @nQTY_Bal  
         WHERE StorerKey = @cStorerKey   
         AND UCCNo = @cUCC  
         AND SKU = @cUCCSKU  
         AND UCC_RowRef = @nRowRef  
         --AND Qty <> @nUCCQTY  
           
         IF @@ERROR <> 0   
         BEGIN  
            SET @nErrNo = 131652  
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --UpdUCCFail  
            GOTO Quit  
         END  
  
         -- Update Status  
         IF EXISTS ( SELECT 1 FROM rdt.rdtUCCReceive2Log WITH (NOLOCK)   
                     WHERE StorerKey = @cStorerKey  
                     AND UCCNo = @cUCC  
                     AND SKU = @cUCCSKU  
                     AND Status = '1' )   
         BEGIN  
            -- Update Qty   
            UPDATE dbo.UCC WITH (ROWLOCK)   
               SET Status = '0'  
            WHERE StorerKey = @cStorerKey   
            AND UCCNo = @cUCC  
            AND SKU = @cUCCSKU  
              
            IF @@ERROR <> 0   
            BEGIN  
               SET @nErrNo = 131653  
               SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --UpdUCCFail  
               GOTO Quit  
            END  
         END  
                       
       
         FETCH NEXT FROM @curPDUCC INTO @nQTY_Bal, @nRowRef  
       
       END  
        
  
  END  
  
Quit:  
        
END  

GO
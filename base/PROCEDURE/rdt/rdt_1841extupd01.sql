SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/  
/* Store procedure: rdt_1841ExtUpd01                                          */  
/* Copyright      : LF Logistics                                              */  
/*                                                                            */  
/* Purpose: Allow create Ucc with multi sku                                   */  
/*                                                                            */  
/*                                                                            */  
/* Date        Rev  Author       Purposes                                     */  
/* 2021-10-27  1.0  Chermaine    WMS-18096. Created                           */  
/******************************************************************************/  
  
CREATE PROCEDURE [RDT].[rdt_1841ExtUpd01]  
   @nMobile        INT,  
   @nFunc          INT,  
   @cLangCode      NVARCHAR( 3),  
   @nStep          INT,  
   @nAfterStep     INT,  
   @nInputKey      INT,  
   @cFacility      NVARCHAR( 5),   
   @cStorerKey     NVARCHAR( 15),  
   @cReceiptKey    NVARCHAR( 10),  
   @cLane          NVARCHAR( 10),  
   @cUCC           NVARCHAR( 20),  
   @cToID          NVARCHAR( 18),  
   @cSKU           NVARCHAR( 20),  
   @nQty           INT,  
   @cOption        NVARCHAR( 1),                 
   @cPosition      NVARCHAR( 20),  
   @tExtValidVar   VariableTable READONLY,   
   @nErrNo         INT           OUTPUT,   
   @cErrMsg        NVARCHAR( 20) OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE 
   	@nRowRef    INT,
   	@cUCCNo     NVARCHAR(20),
   	@cUCCSKU    NVARCHAR(20),
      @cEnternKey NVARCHAR(20),
   	@nUCCQty    INT
   
   
   IF @nStep = 7 -- Direct from SKUScn go to QTY Scn
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN        
      	SELECT TOP 1
      	   @cEnternKey = ExternReceiptKey
      	FROM receiptDetail WITH (NOLOCK)
      	WHERE StorerKey = @cStorerKey
      	AND sku = @cSKU
      	AND ReceiptKey = @cReceiptKey
      	      	   
         DECLARE @curPRL CURSOR  
         SET @curPRL = CURSOR FOR  
         SELECT RowRef, UCCNo, SKU, Qty 
         FROM RDT.rdtPreReceiveSort WITH (NOLOCK)  
         WHERE ReceiptKey = @cReceiptKey   
         AND UCCNo = @cUCC
         AND [Status] = '1'  
         AND StorerKey = @cStorerKey
         ORDER BY RowRef
         
         OPEN @curPRL  
         FETCH NEXT FROM @curPRL INTO @nRowRef, @cUCCNo, @cUCCSKU, @nUCCQty
         WHILE @@FETCH_STATUS = 0  
         BEGIN  
         	INSERT INTO dbo.UCC (StorerKey, UCCNo, Status, SKU, QTY, LOC, ID, ReceiptKey, ReceiptLineNumber, ExternKey)  
            VALUES (@cStorerKey, @cUCCNo, '0', @cUCCSKU, @nUCCQty, '', '', @cReceiptKey, '', @cEnternKey)  
            
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 177751  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INS UCC fail'   
               GOTO Quit  
            END  
         	
         	FETCH NEXT FROM @curPRL INTO @nRowRef, @cUCC, @cUCCSKU, @nUCCQty
         END
      END
   END

   Quit:  
  
END  

GO
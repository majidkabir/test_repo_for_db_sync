SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/  
/* Store procedure: rdt_1841ExtUpd02                                          */  
/* Copyright      : MAERSK                                                    */ 
/* Customer: For Amazon                                                       */ 
/*                                                                            */  
/* Purpose: Update  receiptdetail.beforereceivedqty                           */  
/*                                                                            */  
/*                                                                            */  
/* Date        Rev    Author       Purposes                                   */  
/* 2021-10-27  1.0.0  XLL045       FCR-1066                                   */  
/******************************************************************************/  
  
CREATE   PROCEDURE rdt.rdt_1841ExtUpd02  
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
   	@nUCCQty    INT,
      @cReceiveonUCCScan  NVARCHAR( 20) 

   SET @cReceiveonUCCScan = rdt.RDTGetConfig( @nFunc, 'ReceiveonUCCScan', @cStorerKey)

   IF @nFunc = 1841
   BEGIN 
      IF @nStep = 3 
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cReceiveonUCCScan = '1'
            BEGIN
               UPDATE dbo.receiptDetail WITH(ROWLOCK) SET beforereceivedqty = qtyExpected, ToId = @cToID
               WHERE receiptKey = @cReceiptKey AND userDefine01 = @cUCC

               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 228601  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'update beforereceiveqty'   
                  GOTO Quit  
               END  
            END
         END
      END
   END
   Quit:  
  
END  

GO
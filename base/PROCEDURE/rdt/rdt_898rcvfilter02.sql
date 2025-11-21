SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

  
  
/************************************************************************/  
/* Store procedure: rdt_898RcvFilter02                                  */  
/* Copyright      : LFLogistics                                         */  
/*                                                                      */  
/* Purpose: ReceiptDetail filter                                        */  
/*                                                                      */  
/* Date        Rev  Author      Purposes                                */  
/* 09-11-2018  1.0  ChewKP      WMS-6931 Created                        */  
/************************************************************************/  
  
CREATE PROCEDURE [RDT].[rdt_898RcvFilter02]  
    @nMobile     INT  
   ,@nFunc       INT  
   ,@cLangCode   NVARCHAR(  3)  
   ,@cReceiptKey NVARCHAR( 10)  
   ,@cPOKey      NVARCHAR( 10)  
   ,@cToLOC      NVARCHAR( 10)  
   ,@cToID       NVARCHAR( 18)  
   ,@cLottable01 NVARCHAR( 18)  
   ,@cLottable02 NVARCHAR( 18)  
   ,@cLottable03 NVARCHAR( 18)  
   ,@dLottable04 DATETIME   
   ,@cSKU        NVARCHAR( 20)  
   ,@cUCC        NVARCHAR( 20)  
   ,@nQTY        INT  
   ,@cCustomSQL  NVARCHAR( MAX) OUTPUT  
   ,@nErrNo      INT            OUTPUT  
   ,@cErrMsg     NVARCHAR( 20)  OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @cExternKey        NVARCHAR(20)  
          ,@cUserDefine09     NVARCHAR(30)  
          ,@nRowRef           INT  
          ,@cStorerKey        NVARCHAR(15)   
  
   SELECT @cStorerKey = StorerKey  
   FROM rdt.rdtMobRec WITH (NOLOCK)   
   WHERE Mobile = @nMobile   
     
   SELECT TOP 1 @nRowRef = RowRef FROM rdt.rdtUCCReceive2Log WITH (NOLOCK)   
   WHERE StorerKey = @cStorerKey  
   AND ReceiptKey = @cReceiptKey  
   AND UCCNo = @cUCC  
   AND SKU = @cSKU  
   AND QtyExpected = @nQTY   
   AND Status = '1'   
   ORDER BY Lottable01   
     
   SELECT   
         @cUserDefine09 = Lottable09    
   FROM rdt.rdtUCCReceive2Log WITH (NOLOCK)   
   WHERE RowRef = @nRowRef  
     
   SELECT @cExternKey = ExternKey   
   FROM dbo.UCC WITH (NOLOCK)   
   WHERE StorerKey = @cStorerKey   
   AND UCCNo = @cUCC  
   AND SKU = @cSKU   
   AND Qty = @nQTY  
   AND UserDefined09 = @cUserDefine09  
     
     
   IF @cUCC <> ''  
      SET @cCustomSQL = @cCustomSQL +   
         ' AND ExternReceiptKey = ' + QUOTENAME( @cExternKey, '''') +   
         ' AND ExternLineNo     = ' + QUOTENAME( @cUserDefine09, '''')   
           
  
QUIT:  
END -- End Procedure  
  


GO
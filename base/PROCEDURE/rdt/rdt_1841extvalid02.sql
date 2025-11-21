SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/  
/* Store procedure: rdt_1841ExtValid02                                        */  
/* Copyright      : LF Logistics                                              */  
/*                                                                            */  
/* Purpose: Allow only 1 ASN 1 Lane 1 User                                    */  
/*                                                                            */  
/*                                                                            */  
/* Date        Rev  Author       Purposes                                     */  
/* 2021-08-17  1.0  Chermaine    WMS-17254. Created                           */  
/******************************************************************************/  
  
CREATE PROCEDURE [RDT].[rdt_1841ExtValid02]  
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
   
   IF @nStep = 2 -- UCC
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN        
         -- Check UserDefine10 in OriLine ASN
         IF NOT EXISTS( SELECT TOP 1 1 
                        FROM ReceiptDetail RD WITH (NOLOCK)
                        JOIN UCC U WITH (NOLOCK) ON (RD.ExternReceiptKey = u.ExternKey AND RD.StorerKey = U.Storerkey)
                        WHERE U.UccNo = @cUCC 
                        AND RD.ReceiptKey = @cReceiptKey
                        AND RD.StorerKey = @cStorerKey )
         BEGIN
            SET @nErrNo = 173501
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid UCC
            GOTO Quit
         END
      END
   END

   Quit:  
  
END  

GO
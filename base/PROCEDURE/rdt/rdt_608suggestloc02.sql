SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/******************************************************************************/  
/* Store procedure: rdt_608SuggestLOC02                                       */  
/* Copyright      : LF Logistics                                              */  
/*                                                                            */  
/* Purpose: SuggestedLocSP                                                    */  
/*                                                                            */  
/* Date         Author    Ver.  Purposes                                      */  
/* 01-04-2020   YeeKung   1.0   WMS19543 - Created                            */  
/* 08-09-2022   Ung       1.1   WMS-20348 Expand RefNo to 60 chars            */
/******************************************************************************/  
  
CREATE   PROCEDURE [RDT].[rdt_608SuggestLOC02]
   @nMobile       INT,          
   @nFunc         INT,          
   @cLangCode     NVARCHAR( 3), 
   @nStep         INT,          
   @nInputKey     INT,          
   @cFacility     NVARCHAR( 5), 
   @cStorerKey    NVARCHAR( 15),
   @cReceiptKey   NVARCHAR( 10),
   @cPOKey        NVARCHAR( 10),
   @cRefNo        NVARCHAR( 60),
   @cID           NVARCHAR( 18),
   @cSKU          NVARCHAR( 20),
   @nQTY          INT,          
   @cDefaultToLOC NVARCHAR( 10) OUTPUT,
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT    
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @cReceiptGroup NVARCHAR(20)

   IF @nFunc = 608 -- Piece return
   BEGIN  
      IF EXISTS (SELECT 1 FROM 
                 RECEIPT (NOLOCK)
                 where receiptkey=@creceiptkey
                 AND doctype='R')
      BEGIN
         SELECT @cReceiptGroup=receiptGroup
         FROM RECEIPT (NOLOCK)
         where receiptkey=@creceiptkey

         SELECT TOP 1 @cDefaultToLOC=long
         FROM codelkup (NOLOCK)
         Where Listname = 'RDTRCVLOC' 
         AND storerkey=@cstorerkey
         AND code = @cReceiptGroup
         AND short=@nFunc
      END
      ELSE
      BEGIN
         SET @cDefaultToLOC = rdt.RDTGetConfig( @nFunc, 'DefaultToLOC', @cStorerKey)  
      END
 
   END  
Quit:  
  
END  

GO
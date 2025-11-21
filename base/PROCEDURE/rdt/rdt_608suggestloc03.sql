SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/******************************************************************************/  
/* Store procedure: rdt_608SuggestLOC03                                       */  
/* Copyright      : LF Logistics                                              */  
/*                                                                            */  
/* Purpose: SuggestedLocSP                                                    */  
/*                                                                            */  
/* Date         Author    Ver.  Purposes                                      */  
/* 22-09-2023   YeeKung   1.0   WMS-23685- Created                            */  
/******************************************************************************/  
  
CREATE   PROCEDURE [RDT].[rdt_608SuggestLOC03]
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
  
   DECLARE @cRecType NVARCHAR(20)

   IF @nFunc = 608 -- Piece return
   BEGIN  

      SELECT @cRecType=RecType
      FROM RECEIPT (NOLOCK)
      where receiptkey=@creceiptkey
      AND storerkey=@cstorerkey

      SELECT TOP 1 @cDefaultToLOC=UDF03
      FROM codelkup (NOLOCK)
      Where Listname = 'RECTYPE' 
      AND storerkey=@cstorerkey
      AND code = @cRecType
 
   END  
Quit:  
  
END  

GO
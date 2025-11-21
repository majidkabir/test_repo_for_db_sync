SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/  
/* Store procedure: rdt_608SuggestLOC01                                       */  
/* Copyright      : LF Logistics                                              */  
/*                                                                            */  
/* Purpose: SuggestedLocSP                                                    */  
/*                                                                            */  
/* Date         Author    Ver.  Purposes                                      */  
/* 01-04-2020   YeeKung   1.0   WMS14478 - Created                            */  
/* 08-09-2022   Ung       1.1   WMS-20348 Expand RefNo to 60 chars            */
/******************************************************************************/  
  
CREATE   PROCEDURE [RDT].[rdt_608SuggestLOC01]
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
        
   IF @nFunc = 608 -- Piece return
   BEGIN  
      SELECT TOP 1 @cDefaultToLOC=toloc
      FROM receiptdetail (NOLOCK)
      where receiptkey=@creceiptkey
      AND toloc<>''
 
   END  
Quit:  
  
END  

GO
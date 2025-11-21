SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_610ExtInfo02                                    */  
/*                                                                      */  
/* Purpose: Prompt last scanned ucc                                     */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author      Purposes                                */  
/* 2021-12-08  1.0  James       WMS-18486. Created                      */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_610ExtInfo02] (  
   @nMobile        INT,  
   @nFunc          INT,  
   @cLangCode      NVARCHAR( 3),  
   @nStep          INT,  
   @nAfterStep     INT,  
   @nInputKey      INT,  
   @cFacility      NVARCHAR( 5),  
   @cStorerKey     NVARCHAR( 15),  
   @cCCRefNo       NVARCHAR( 10),  
   @cCCSheetNo     NVARCHAR( 10),  
   @nCCCountNo     INT,  
   @cZone1         NVARCHAR( 10),  
   @cZone2         NVARCHAR( 10),  
   @cZone3         NVARCHAR( 10),  
   @cZone4         NVARCHAR( 10),  
   @cZone5         NVARCHAR( 10),  
   @cAisle         NVARCHAR( 10),  
   @cLevel         NVARCHAR( 10),  
   @cLOC           NVARCHAR( 10),  
   @cID            NVARCHAR( 18),    
   @cUCC           NVARCHAR( 20),  
   @cSKU           NVARCHAR( 20),  
   @nQty           INT,  
   @cLottable01    NVARCHAR( 18),    
   @cLottable02    NVARCHAR( 18),    
   @cLottable03    NVARCHAR( 18),    
   @dLottable04    DATETIME,    
   @dLottable05    DATETIME,   
   @tExtValidate   VariableTable READONLY,  
   @cExtendedInfo  NVARCHAR( 20) OUTPUT  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   SET @cExtendedInfo = ''  
     
   IF @nStep = 9  
   BEGIN  
      IF @nInputKey = 1  
      BEGIN  
         SET @cExtendedInfo = @cUCC  
      END    
   END  
  
   Quit:  
  
END  

GO
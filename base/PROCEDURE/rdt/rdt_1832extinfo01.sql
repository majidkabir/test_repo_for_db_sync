SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
        
/************************************************************************/      
/* Store procedure: rdt_1832ExtInfo01                                   */      
/* Copyright      : LF Logistics                                        */      
/*                                                                      */      
/* Date       Rev Author      Purposes                                  */      
/* 19-02-2018 1.0 YeeKung     WMS-7796 Created                          */      
/* 09-01-2020 1.1 James       WMS-11639 Add display MAX ucc qty(james01)*/
/************************************************************************/      
      
CREATE PROC [RDT].[rdt_1832ExtInfo01] (      
   @nMobile        INT,                
   @nFunc          INT,                
   @cLangCode      NVARCHAR( 3),       
   @nStep          INT,                
   @nAfterStep     INT,                
   @nInputKey      INT,                
   @cFacility      NVARCHAR( 5),       
   @cStorerKey     NVARCHAR( 15),      
   @tVar           VariableTable READONLY,      
   @cExtendedInfo  NVARCHAR( 20) OUTPUT,      
   @nErrNo         INT           OUTPUT,      
   @cErrMsg        NVARCHAR( 20) OUTPUT       
)      
AS      
BEGIN      
   SET NOCOUNT ON      
   SET QUOTED_IDENTIFIER OFF      
   SET ANSI_NULLS OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF      

   -- Variable mapping      
   DECLARE  @cSKU       NVARCHAR(20),
				@cToID      NVARCHAR(18),       
            @nUCCCnt    INT,
            @cFromLOC   NVARCHAR( 10),
            @cFromID    NVARCHAR( 10),
            @nUCC_Qty   INT
      
   SELECT @cSKU = Value FROM @tVar WHERE Variable = '@cSKU'
	SELECT @cToID = Value FROM @tVar WHERE Variable = '@cToID'   
   SELECT @cFromLOC = Value FROM @tVar WHERE Variable = '@cFromLOC'
	SELECT @cFromID = Value FROM @tVar WHERE Variable = '@cFromID'
   
   IF @nFunc = 1832 -- Move to UCC      
   BEGIN      
      IF @nStep = 6
      BEGIN
         SET @nUCC_Qty = 0
         SELECT @nUCC_Qty = MAX( Qty)
         FROM dbo.UCC WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   SKU = @cSKU
         AND   [Status] = '1'

         SET @cExtendedInfo = 'MAX QTY: ' + CAST( @nUCC_Qty AS NVARCHAR(5))      
      END

      IF @nStep = 7
      BEGIN
         IF ISNULL( @cSKU, '') = ''
            SELECT @cSKU = O_Field01
            FROM rdt.RDTMOBREC WITH (NOLOCK)
            WHERE Mobile = @nMobile

         SET @nUCC_Qty = 0
         SELECT @nUCC_Qty = MAX( Qty)
         FROM dbo.UCC WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   SKU = @cSKU
         AND   [Status] = '1'

         SET @cExtendedInfo = 'MAX QTY: ' + CAST( @nUCC_Qty AS NVARCHAR(5))      
      END

      IF @nAfterStep = 7
      BEGIN
         IF ISNULL( @cSKU, '') = ''
            SELECT @cSKU = O_Field01
            FROM rdt.RDTMOBREC WITH (NOLOCK)
            WHERE Mobile = @nMobile

         SET @nUCC_Qty = 0
         SELECT @nUCC_Qty = MAX( Qty)
         FROM dbo.UCC WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   SKU = @cSKU
         AND   [Status] = '1'

         SET @cExtendedInfo = 'MAX QTY: ' + CAST( @nUCC_Qty AS NVARCHAR(5))      
      END
      
      IF @nAfterStep = 8    
      BEGIN      
    
      
         IF @cSKU <> ''      
         BEGIN      
            SELECT @nUCCCnt = count(*)      
            FROM dbo.UCC WITH (NOLOCK)     
            WHERE StorerKey = @cStorerKey      
            AND   SKU = @cSKU AND ID=@cToID 
      
            SET @cExtendedInfo = 'UCCCnt: ' + CAST( @nUCCCnt AS NVARCHAR(5))      
         END      
      END      
   END      

      
Quit:  
END    
          

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_741ExtInfo01                                    */  
/* Purpose: Display UCC Qty                                             */
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author    Purposes                                   */  
/* 2018-01-16 1.0  James     WMS3770. Created                           */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_741ExtInfo01] (  
   @nMobile         INT, 
   @nFunc           INT, 
   @cLangCode       NVARCHAR( 3),  
   @nStep           INT, 
   @nInputKey       INT, 
   @cStorerKey      NVARCHAR( 15), 
   @cTrolleyNo      NVARCHAR( 5),  
   @cLOC            NVARCHAR( 10), 
   @cUCC            NVARCHAR( 20), 
   @cPosition       NVARCHAR( 1),
   @nQty            INT,           
   @cExtendedInfo   NVARCHAR( 20) OUTPUT
)  
AS  

SET NOCOUNT ON    
SET QUOTED_IDENTIFIER OFF    
SET ANSI_NULLS OFF    
SET CONCAT_NULL_YIELDS_NULL OFF    

   DECLARE @nUCCQTY INT

   IF @nInputKey = 1  
   BEGIN  
      IF @nStep IN ( 1, 4)
      BEGIN
         -- Get UCC info
         SELECT @nUCCQTY = QTY
         FROM dbo.UCC WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   UCCNo = @cUCC
         AND   [Status] < '6'

         SET @cExtendedInfo = 'QTY: ' + CAST( @nUCCQTY AS NVARCHAR( 3))
      END
   END
    
   QUIT:
 

GO
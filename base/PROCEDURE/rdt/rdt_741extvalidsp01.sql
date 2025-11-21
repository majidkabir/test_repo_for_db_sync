SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_741ExtValidSP01                                 */  
/* Purpose: Validate UCC qty. If not match then prompt error            */
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author    Purposes                                   */  
/* 2017-04-19 1.0  James     WMS1399. Created                           */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_741ExtValidSP01] (  
   @nMobile         INT, 
   @nFunc           INT, 
   @cLangCode       NVARCHAR( 3),  
   @nStep           INT, 
   @nInputKey       INT, 
   @cStorerKey      NVARCHAR( 15), 
   @cTrolleyNo      NVARCHAR( 5),  
   @cUCC            NVARCHAR( 20), 
   @nQty            INT,           
   @cSuggestedLOC   NVARCHAR( 10), 
   @nErrNo          INT           OUTPUT,  
   @cErrMsg         NVARCHAR( 20) OUTPUT
)  
AS  

SET NOCOUNT ON    
SET QUOTED_IDENTIFIER OFF    
SET ANSI_NULLS OFF    
SET CONCAT_NULL_YIELDS_NULL OFF    

   DECLARE @nUCCQTY INT

   IF @nInputKey = 1  
   BEGIN  
      IF @nStep = 3
      BEGIN
         -- Get UCC info
         SELECT @nUCCQTY = QTY
         FROM dbo.UCC WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   UCCNo = @cUCC

         IF @nUCCQTY <> @nQty
         BEGIN
            SET @nErrNo = 108251
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UCCQty X Match
            GOTO Quit
         END
      END
   END
    
   QUIT:
 

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_1842ExtValid01                                  */  
/* Purpose:                                                             */
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author    Purposes                                   */  
/* 2020-06-12 1.0  YeeKung    WMS-13629 Created                         */
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_1842ExtValid01] (  
   @nMobile         INT,            
   @nFunc           INT,            
   @cLangCode       NVARCHAR( 3),   
   @nStep           INT,            
   @nInputKey       INT,            
   @cStorerKey      NVARCHAR( 15),  
   @cFacility       NVARCHAR( 5),   
   @cFromLOC        NVARCHAR( 10),  
   @cSKU            NVARCHAR( 20),  
   @cSuggToLoc      NVARCHAR( 10), 
   @cFromID         NVARCHAR( 20),
   @cSuggID         NVARCHAR( 20),
   @nErrNo          INT           OUTPUT,
   @cErrMsg         NVARCHAR( 20) OUTPUT 
)  
AS  

   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    

   IF @nInputKey = 1  
   BEGIN  
      IF @nStep = 1
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM SKUXLOC (NOLOCK) 
                        WHERE STORERKEY=@cStorerkey
                           AND SKU=@cSKU
                           AND locationtype <>'PICK')
         BEGIN
            SET @nErrNo = 154001  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NoPickFace
            GOTO QUIT 
         END

         IF NOT EXISTS (SELECT 1 FROM SKUXLOC (NOLOCK) 
               WHERE STORERKEY=@cStorerkey
                  AND SKU=@cSKU
                  AND locationtype ='PICK')
         BEGIN
            SET @nErrNo = 154002 
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NoPickFace
            GOTO QUIT 
         END
      END
   END
   QUIT:
 

GO
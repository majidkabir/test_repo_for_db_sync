SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_Replesh_GetLoc01                                */  
/* Purpose:                                                             */
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author    Purposes                                   */  
/* 2020-06-12 1.0  YeeKung    WMS-13629 Created                         */
/* 2020-10-07 1.1  YeeKung    Add loc.loclocationtype='pick'            */
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_Replesh_GetLoc01] (  
   @nMobile         INT,           
   @nFunc           INT,           
   @cLangCode       NVARCHAR( 3),  
   @nStep           INT,           
   @nInputKey       INT,           
   @cStorerKey      NVARCHAR( 15), 
   @cFacility       NVARCHAR( 5),  
   @cSKU            NVARCHAR( 20), 
   @cFromLOC        NVARCHAR( 10) OUTPUT,
   @cSuggToLoc      NVARCHAR( 10) OUTPUT,
   @cSuggID         NVARCHAR( 20) OUTPUT, 
   @cFromLOT        NVARCHAR( 20) OUTPUT, 
   @nQTY            INT           OUTPUT,
   @nQTYAlloc       INT           OUTPUT,
   @nQTYPick        INT           OUTPUT,
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
         SET @cFromLOC=''
         SET @cSuggToLoc=''
         SET @cSuggID=''
         SET @cFromLOT=''
         SET @nQTY=''

         DECLARE @cLong NVARCHAR(20)

         SELECT @cLong=long
         FROM CODELKUP(NOLOCK)
         WHERE storerkey=@cstorerkey
         and listname='THGCUSREQ'
         and code = 'REPLENLOCTYPE'
         and code2=@nFunc

         SELECT TOP 1 @cFromLOC=L.LOC,@cSuggID=lli.id,@cFromLOT=lli.lot,@nQTY=LLI.QTY,@nQTYAlloc=lli.Qtyallocated,@nQTYPick=lli.QtyPicked
         FROM  SKUXLOC SL WITH (NOLOCK)
         JOIN LOC L WITH (NOLOCK) ON SL.loc=L.LOC
         JOIN LOTXLOCXID LLI WITH (NOLOCK) ON SL.SKU=LLI.SKU AND L.LOC=LLI.LOC
         JOIN Lotattribute LA WITH (NOLOCK) ON LLI.LOT=LA.LOT AND SL.SKU=LA.SKU
         WHERE SL.SKU=@cSKU
            AND SL.storerkey=@cStorerKey
            AND L.Locationtype = case when ISNULL(@cLong,'')<>'' THEN @cLong ELSE L.Locationtype END
            AND SL.locationtype<>'PICK'
            --AND LLI.QTY-LLI.QTYAllocated<>0
            AND LLI.QTY<>0
            AND L.HOSTWHCODE='GOOD'
            AND LLI.ID<>''
         ORDER by La.lottable04,LA.lottable05,L.logicallocation

         SELECT TOP 1 @cSuggToLoc=LOC
         FROM  SKUXLOC WITH (NOLOCK)
         WHERE SKU=@cSKU
            AND storerkey=@cStorerKey
            AND locationtype='PICK'
      END
   END
   QUIT:
 

GO
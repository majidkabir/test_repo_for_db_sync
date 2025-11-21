SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_521ExtPA16                                      */    
/*                                                                      */    
/* Purpose: Get suggested loc                                           */    
/*                                                                      */    
/* Called from: rdt_UCCPutaway_GetSuggestLOC                            */    
/*                                                                      */    
/* Date         Rev  Author   Purposes                                  */    
/* 2023-09-08   yeekung   1.0   WMS-23546 Created                       */
/************************************************************************/    
    
CREATE   PROC [RDT].[rdt_521ExtPA16] (    
   @nMobile          INT,     
   @nFunc            INT,     
   @cLangCode        NVARCHAR( 3),     
   @cUserName        NVARCHAR( 18),    
   @cStorerKey       NVARCHAR( 15),    
   @cFacility        NVARCHAR( 5),     
   @cLOC             NVARCHAR( 10),    
   @cID              NVARCHAR( 18),    
   @cLOT             NVARCHAR( 10),    
   @cUCC             NVARCHAR( 20),    
   @cSKU             NVARCHAR( 20),    
   @nQty             INT,              
   @cSuggestedLOC    NVARCHAR( 10) OUTPUT,      
   @cPickAndDropLoc  NVARCHAR( 10) OUTPUT,      
   @nPABookingKey    INT           OUTPUT,      
   @nErrNo           INT           OUTPUT,     
   @cErrMsg          NVARCHAR( 20) OUTPUT      
) AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
 
   DECLARE @cPutawayZone   NVARCHAR(10)   

   --New Empty LOC
   IF @cSuggestedLOC=''
   BEGIN
      
      SELECT  @cPutawayZone = ZONE
      FROM PutawayStrategydetail (nolock) 
      WHERE PutawayStrategykey ='LVSUCC'
      AND Fromloc = @cLOC

      select TOP 1 @cSuggestedLOC = LOC.LOC
      FROM LOC LOC (nolock)
      LEFT OUTER JOIN LOTxLOCxID WITH (NOLOCK) ON ( LOC.loc = LOTxLOCxID.LOC )
      LEFT JOIN UCC UCC (nolock) on LOTxLOCxID.loc = UCC.Loc AND UCC.Storerkey = LOTxLOCxID.StorerKey
      WHERE LOC.facility = @cFacility
         AND LOC.PutawayZone = @cPutawayZone
         AND Loc.LOC <> @cLOC
      GROUP BY LOC.LOC,LOC.maxcarton,LOC.LogicalLocation
      HAVING LOC.maxcarton > COUNT(DISTINCT UCC.UCCNO)
      ORDER BY LOC.LogicalLocation

      --New Empty LOC
      IF @cSuggestedLOC = ''
      BEGIN
         -- Suggest LOC
         EXEC @nErrNo = [dbo].[nspRDTPASTD]
              @c_userid        = 'RDT'          -- NVARCHAR(10)
            , @c_storerkey     = @cStorerkey    -- NVARCHAR(15)
            , @c_lot           = ''             -- NVARCHAR(10)
            , @c_sku           = @cSKU          -- NVARCHAR(20)
            , @c_id            = @cID           -- NVARCHAR(18)
            , @c_fromloc       = @cLOC          -- NVARCHAR(10)
            , @n_qty           = @nQty          -- int
            , @c_uom           = ''             -- NVARCHAR(10)
            , @c_packkey       = ''             -- NVARCHAR(10) -- optional
            , @n_putawaycapacity = 0
            , @c_final_toloc     = @cSuggestedLOC     OUTPUT
            , @c_PickAndDropLoc  = @cPickAndDropLoc   OUTPUT

         -- Check suggest loc
         IF @cSuggestedLOC = ''
         BEGIN
            SET @nErrNo = -1
            GOTO Quit
         END
      END

                             
   END

   /*-------------------------------------------------------------------------------    
                                 Book suggested location    
   -------------------------------------------------------------------------------*/    
   IF @cSuggestedLOC <> ''    
   BEGIN    
          
      EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'    
         ,@cLOC    
         ,@cID    
         ,@cSuggestedLOC    
         ,@cStorerKey    
         ,@nErrNo  OUTPUT    
         ,@cErrMsg OUTPUT    
         ,@cSKU          = @cSKU    
         ,@nPutawayQTY   = @nQTY    
         ,@cFromLOT      = @cLOT    
         ,@cUCCNo        = @cUCC    
         ,@nPABookingKey = @nPABookingKey OUTPUT    
      IF @nErrNo <> 0    
         GOTO QUIT    
   END    
   GOTO Quit    
     
Quit:    
END


GO
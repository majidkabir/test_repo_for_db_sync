SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
            
/************************************************************************/                
/* Store procedure: rdt_1819ExtPASP49                                   */                
/*                                                                      */                
/* Modifications log:                                                   */                
/*                                                                      */                
/* Date         Rev  Author   Purposes                                  */                
/* 2023-06-22  1.0  yeekung   WMS-22935. Created                        */                 
/************************************************************************/                
                
CREATE   PROC [RDT].[rdt_1819ExtPASP49] (                
   @nMobile          INT,                
   @nFunc            INT,                
   @cLangCode        NVARCHAR( 3),                
   @cUserName        NVARCHAR( 18),                
   @cStorerKey       NVARCHAR( 15),                 
   @cFacility        NVARCHAR( 5),                 
   @cFromLOC         NVARCHAR( 10),                
   @cID              NVARCHAR( 18),                
   @cSuggLOC         NVARCHAR( 10) = ''  OUTPUT,                
   @cPickAndDropLOC  NVARCHAR( 10)  OUTPUT,                
   @cFitCasesInAisle NVARCHAR( 1)   OUTPUT,                
   @nPABookingKey    INT            OUTPUT,                 
   @nErrNo           INT            OUTPUT,                
   @cErrMsg          NVARCHAR( 20)  OUTPUT                
) AS                
BEGIN                
   SET NOCOUNT ON                
   SET QUOTED_IDENTIFIER OFF                
   SET ANSI_NULLS OFF                
   SET CONCAT_NULL_YIELDS_NULL OFF                
                   
   DECLARE @cSKU           NVARCHAR( 20)                
   DECLARE @cPutawayZone   NVARCHAR(10)                   
   DECLARE @cLottable03    NVARCHAR( 20)                
   DECLARE @nTranCount     INT                
   DECLARE @nPalletTotStdCube FLOAT              
                          
   SELECT TOP 1 @cSKU = SKU.SKU,                 
               @cLottable03 = La.Lottable03,                
               @cFromLOC = LLI.LOC,                
               @cPutawayZone = SKU.PutawayZone ,              
               @nPalletTotStdCube = SKU.STDCUBE * LLI.Qty              
   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)                
      JOIN LOTATTRIBUTE LA (NOLOCK) on LA.Lot = LLI.Lot AND LLI.SKU = LA.SKU                
      JOIN SKU SKU (NOLOCK) ON SKU.SKU = LLI.SKU AND SKU.Storerkey = LLI.Storerkey                
   WHERE ID = @cID                
      AND SKU.Storerkey = @cStorerKey                
   ORDER BY LLI.QTY DESC                
      
         
                
   -- Find a friend                
   IF ISNULL( @cLottable03,'') IN ( 'TERMINAL' , 'VESSEL' )           
   BEGIN             
              
      IF EXISTS ( SELECT 1 FROM dbo.LotxLocxID WITH (NOLOCK)         
                  WHERE StorerKey = @cStorerKey        
                  AND ID = @cID        
                  HAVING Count(Distinct SKU) = 1 )        
      BEGIN         
          
         SELECT TOP 1                
             @cSuggLOC = LOC.LOC                
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)                
         JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)                
         JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON ( LLI.LOT = LA.LOT)                
         JOIN SKU SKU (NOLOCK) ON SKU.SKU = LLI.SKU AND SKU.Storerkey = LLI.Storerkey                
         WHERE LOC.Facility = @cFacility                
            AND   LOC.LOC <> @cFromLOC                
            AND   LLI.StorerKey = @cStorerKey                
            AND   LA.Lottable03 = @cLottable03                
            AND   SKU.PutawayZone = @cPutawayZone            
            AND   LOC.LocationType = 'PICK'                
            AND   LOC.locationFlag = 'NONE'             
            AND LLI.SKU          = @cSKU             
         GROUP BY LOC.PALogicalLoc, LOC.Loc                
         HAVING SUM( lli.Qty - lli.QtyAllocated - lli.QtyPicked - LLI.QtyReplen) > 0                
         AND @nPalletTotStdCube + ISNULL((SUM( isnull(lli.Qty,0)  - isnull(lli.QtyAllocated,0) - isnull(lli.QtyPicked,0) - isnull(LLI.QtyReplen,0) +isnull(LLI.PendingMoveIN,0)) *  SUM( DISTINCT SKU.STDCUBE)) ,0)  <=  MAX(LOC.CubicCapacity)               

         ORDER BY LOC.PALogicalLoc, LOC.Loc      
             
         IF ISNULL(@cSuggLoc,'')  = ''      
         BEGIN    
            SELECT TOP 1                
                @cSuggLOC = LOC.LOC                
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)                
            JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)                
            JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON ( LLI.LOT = LA.LOT)                
            JOIN SKU SKU (NOLOCK) ON SKU.SKU = LLI.SKU AND SKU.Storerkey = LLI.Storerkey                
            WHERE LOC.Facility = @cFacility                
               AND   LOC.LOC <> @cFromLOC                
               AND   LLI.StorerKey = @cStorerKey                
               AND   LA.Lottable03 = @cLottable03                
               AND   SKU.PutawayZone = @cPutawayZone                
               AND   LOC.LocationType = 'BULK'                
               AND   LOC.locationFlag = 'NONE'             
               AND   LLI.SKU          = @cSKU             
            GROUP BY LOC.PALogicalLoc, LOC.Loc                
            HAVING SUM( lli.Qty - lli.QtyAllocated - lli.QtyPicked - LLI.QtyReplen) > 0                
            AND @nPalletTotStdCube + ISNULL((SUM( isnull(lli.Qty,0)  - isnull(lli.QtyAllocated,0) - isnull(lli.QtyPicked,0) - isnull(LLI.QtyReplen,0) +isnull(LLI.PendingMoveIN,0)) *  SUM( DISTINCT SKU.STDCUBE)) ,0)  <=  MAX(LOC.CubicCapacity)            
            ORDER BY LOC.PALogicalLoc, LOC.Loc      
         END                    
      END           
              
   END          
           
   -- Find NearBy empty location                
   IF ISNULL(@cSuggLOC,'')  =  ''                
   BEGIN                
                
      IF EXISTS ( SELECT 1 FROM dbo.LotxLocxID WITH (NOLOCK)         
               WHERE StorerKey = @cStorerKey        
               AND ID = @cID        
               HAVING Count(Distinct SKU) = 1 )        
      BEGIN        
                 
         SELECT TOP 1  @cSuggLOC = LOC.LOC                
         FROM dbo.LOC LOC WITH (NOLOCK)               
         LEFT JOIN LOTxLOCxID LLI  WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)                 
         LEFT JOIN SKU SKU (NOLOCK) ON SKU.SKU = LLI.SKU AND SKU.Storerkey = LLI.Storerkey                
         WHERE LOC.Facility = @cFacility                
            AND   LOC.LOC <> @cFromLOC                 
            AND   LOC.LocationType = 'PICK'                
            AND   LOC.locationFlag = 'NONE'                
         GROUP BY LOC.PALogicalLoc, LOC.Loc                
         HAVING SUM( isnull(lli.Qty,0)  - isnull(lli.QtyPicked,0) - isnull(LLI.QtyReplen,0) +isnull(LLI.PendingMoveIN,0)) = 0                
            AND @nPalletTotStdCube + ISNULL((SUM( isnull(lli.Qty,0)  - isnull(lli.QtyPicked,0) - isnull(LLI.QtyReplen,0) +isnull(LLI.PendingMoveIN,0)) *  SUM( DISTINCT SKU.STDCUBE)) ,0)  <=  MAX(LOC.CubicCapacity)              
         ORDER BY LOC.PALogicalLoc, LOC.Loc          
                    
         IF ISNULL(@cSuggLOC,'') =''                
         BEGIN                
            SELECT TOP 1  @cSuggLOC = LOC.LOC                
            FROM dbo.LOC LOC WITH (NOLOCK)               
            LEFT JOIN LOTxLOCxID LLI  WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)                 
            LEFT JOIN SKU SKU (NOLOCK) ON SKU.SKU = LLI.SKU AND SKU.Storerkey = LLI.Storerkey                
            WHERE LOC.Facility = @cFacility                
               AND   LOC.LOC <> @cFromLOC                  
               AND   LOC.LocationType = 'BULK'                
               AND   LOC.locationFlag = 'NONE'                
            GROUP BY LOC.PALogicalLoc, LOC.Loc                
            HAVING SUM( isnull(lli.Qty,0)  - isnull(lli.QtyPicked,0) - isnull(LLI.QtyReplen,0) +isnull(LLI.PendingMoveIN,0)) = 0         
            AND @nPalletTotStdCube + ISNULL((SUM( isnull(lli.Qty,0)  - isnull(lli.QtyPicked,0) - isnull(LLI.QtyReplen,0) +isnull(LLI.PendingMoveIN,0)) *  SUM( DISTINCT SKU.STDCUBE)) ,0)  <=  MAX(LOC.CubicCapacity)           
            ORDER BY LOC.PALogicalLoc, LOC.Loc                    
         END                           
      END                   
   END                
         
         
      
   IF ISNULL( @cSuggLOC, '') = ''                
   BEGIN                
      SET @nErrNo = 202901                
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NOSuiteLoc                
      GOTO Fail                
   END                
                
   IF ISNULL( @cSuggLOC, '') <> ''                
   BEGIN                
      -- Handling transaction                
      SET @nTranCount = @@TRANCOUNT                
      BEGIN TRAN  -- Begin our own transaction                
      SAVE TRAN rdt_1819ExtPASP49 -- For rollback or commit only our own transaction                
                
      EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'                
         ,@cFromLOC                
         ,@cID                
         ,@cSuggLOC                
         ,@cStorerKey            
         ,@nErrNo  OUTPUT                
         ,@cErrMsg OUTPUT                
         ,@nPABookingKey = @nPABookingKey OUTPUT                
      IF @nErrNo <> 0                
         GOTO RollBackTraN                
                   
      COMMIT TRAN rdt_1819ExtPASP49        
         
                 
      GOTO Quit                
                
      RollBackTran:                
      ROLLBACK TRAN rdt_1819ExtPASP49 -- Only rollback change made here            
      SET @nErrNo = 0 -- To Go to ToLoc screen even have error        
   SET @cSuggLOC = ''       
      Quit:                
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started                
         COMMIT TRAN                
   END                
                
Fail:                
      --SET @nErrNo = 0 -- To Go to ToLoc screen even have error       
         
END   



GO
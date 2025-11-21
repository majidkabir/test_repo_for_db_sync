SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/******************************************************************************/  
/* Store procedure: rdt_523ExtPA29                                            */  
/* Copyright: LF Logistics                                                    */  
/*                                                                            */  
/* Date        Rev  Author    Purposes                                        */   
/* 2020-01-30  1.0  Chermaine WMS-11813 Created                               */  
/* 2021-09-10  1.1  Chermaine SET QUOTED_IDENTIFIER OFF                       */
/******************************************************************************/  
  
CREATE PROC [RDT].[rdt_523ExtPA29] (  
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
   @nQTY             INT,  
   @cSuggestedLOC    NVARCHAR( 10)  OUTPUT,  
   @nPABookingKey    INT            OUTPUT,  
   @nErrNo           INT            OUTPUT,  
   @cErrMsg          NVARCHAR( 20)  OUTPUT  
) AS  
BEGIN   
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @nTranCount     INT  
   DECLARE @cSuggToLOC     NVARCHAR( 10) = ''  
   DECLARE @cPutawayLoc    NVARCHAR( 20)  
   DECLARE @cPutawayZone   NVARCHAR( 20)  
   DECLARE @dLottable01    NVARCHAR( 20)  
   DECLARE @cPAStrategyKey NVARCHAR( 10)    
     
    -- Get putaway strategy from SKU  
   SET @cPAStrategyKey = ''    
   SET @cSuggestedLOC = ''  
  
   SELECT    
      @cPAStrategyKey = PS.PutawayStrategyKey  
   FROM SKU S WITH (NOLOCK)   
   JOIN PutawayStrategy PS WITH (NOLOCK) ON s.StrategyKey = PS.PutawayStrategyKey  
   WHERE S.SKU = @cSKU  
   AND S.StorerKey = @cStorerKey  
  
   IF @cPAStrategyKey <> ''       
   BEGIN  
  
      -- Suggest LOC  
      EXEC @nErrNo = [dbo].[nspRDTPASTD]  
         @c_userid          = 'RDT'    
         , @c_storerkey       = @cStorerKey    
         , @c_lot             = @cLOT    
         , @c_sku             = @cSKU    
         , @c_id              = @cID    
         , @c_fromloc         = @cLOC    
         , @n_qty             = @nQTY    
         , @c_uom             = '' -- not used    
         , @c_packkey         = '' -- optional, if pass-in SKU    
         , @n_putawaycapacity = 0    
         , @c_final_toloc     = @cSuggestedLOC  OUTPUT    
         , @c_PAStrategyKey   = @cPAStrategyKey  
   END       
     
   IF @cSuggestedLOC = ''  
   BEGIN  
    SET @nTranCount = @@TRANCOUNT  
      SET @cSuggToLOC = ''  
        
    -- Get putawayloc info  
      SELECT @cPutawayLoc = PutawayLoc, @cPutawayZone = PutawayZone FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU  
  
      IF (@cPutawayLoc IN ('','UNKNOWN') OR  @cPutawayLoc IS NULL ) OR (@cPutawayZone IN ('','UNKNOWN') OR  @cPutawayZone IS NULL )  
      BEGIN  
       SET @cSuggestedLOC = 'NONE'  
         GOTO Quit  
      END  
        
      -- damage and Ageing loc  
      IF EXISTS (SELECT TOP 1 1 FROM LOTxLOCxID WITH (NOLOCK) WHERE storerkey = @cStorerKey  AND SKU = @cSKU AND ID =@cID AND Loc IN ('PMIDMGSTG','PMIAGEDSTG') )  
      BEGIN  
       SET @cSuggestedLOC = ''  
       GOTO Quit  
      END  
        
      --return  
      IF EXISTS (SELECT TOP 1 1 FROM LOTxLOCxID WITH (NOLOCK) WHERE storerkey = @cStorerKey  AND SKU = @cSKU AND Loc = 'PMIRTNSTG' AND ID = @cID )  
      BEGIN  
       DECLARE @cUPC       NVARCHAR( 30)  
       DECLARE @cPickZone  NVARCHAR ( 20)
       SELECT   
            @cUPC = I_Field05   
         FROM rdt.RDTMOBREC WITH (NOLOCK)  
         WHERE Func = @nFunc  
         AND Mobile = @nMobile  
           
         --suggest location will based on sku.putawayzone, and loc.pickzone must be \u2018PMICARPZ\u2019  
         IF (SELECT DISTINCT UOM FROM UPC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND UPC = @cUPC) = 'CARTON'  
         BEGIN  
         	SELECT @cPickZone = UDF01 FROM  dbo.codelkup WITH (NOLOCK) WHERE listname = 'PMIPA' AND code = 'CARTON'
         	
         	SELECT TOP 1    
                @cSuggToLOC = LOC.LOC  
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)  
            JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)  
            JOIN dbo.SKUxLOC SL WITH (NOLOCK) ON ( SL.StorerKey = LLI.StorerKey AND SL.Loc = LLI.Loc AND SL.SKU = LLI.SKU)  
            WHERE LOC.Facility = @cFacility  
            AND LLI.StorerKey = @cStorerKey  
            AND LOC.pickzone = @cPickZone 
            AND SL.LocationType = 'PICK'  
            AND LLI.SKU = @cSKU  
            
            IF @cSuggToLOC = ''  
            BEGIN  
            	SELECT TOP 1    
                  @cSuggToLOC = LOC.LOC  
               FROM dbo.LOC LOC WITH (NOLOCK)  
               JOIN dbo.SKUxLOC SL WITH (NOLOCK) ON (Loc.Loc = SL.Loc)
               WHERE LOC.Facility = @cFacility  
               AND LOC.pickzone = @cPickZone  
               AND SL.LocationType = 'PICK'
               AND SL.StorerKey = @cStorerKey
               AND SL.SKU = @cSKU 
            END  
            
         END  
         ELSE IF (SELECT DISTINCT UOM FROM UPC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND UPC = @cUPC) = 'PACK'  
         BEGIN  
         	SELECT @cPickZone = UDF01 FROM  dbo.codelkup WITH (NOLOCK) WHERE listname = 'PMIPA' AND code = 'CARTON'
         	
            SELECT TOP 1    
               @cSuggToLOC = LOC.LOC  
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)  
            JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)  
            JOIN dbo.SKUxLOC SL WITH (NOLOCK) ON ( SL.StorerKey = LLI.StorerKey AND SL.Loc = LLI.Loc  AND SL.SKU = LLI.SKU)  
            WHERE LOC.Facility = @cFacility  
            AND LLI.StorerKey = @cStorerKey  
            AND LOC.pickzone = @cPickZone  
            AND SL.LocationType = 'PICK'  
            AND LLI.SKU = @cSKU  
            
            IF @cSuggToLOC = ''  
            BEGIN  
            	SELECT TOP 1    
                  @cSuggToLOC = LOC.LOC  
               FROM dbo.LOC LOC WITH (NOLOCK)  
               JOIN dbo.SKUxLOC SL WITH (NOLOCK) ON (Loc.Loc = SL.Loc)
               WHERE LOC.Facility = @cFacility  
               AND LOC.pickzone = @cPickZone  
               AND SL.LocationType = 'PICK'
               AND SL.StorerKey = @cStorerKey
               AND SL.SKU = @cSKU 
            END
            
         END  
      END  
      ELSE  
      --IF @cSuggToLOC = ''  
      BEGIN  
       --special condition  
         IF EXISTS (SELECT TOP 1 1 FROM LOTxLOCxID WITH (NOLOCK) WHERE storerkey = @cStorerKey  AND SKU = @cSKU AND Loc = 'PMIAGESTG' AND ID = @cID )  
         BEGIN  
          SELECT TOP 1    
               @cSuggToLOC = LOC.LOC  
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)  
            JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)  
            WHERE LOC.Facility = @cFacility  
            --AND LOC.LocLevel = '1'  
            AND LLI.StorerKey = @cStorerKey  
            AND LOC.pickzone  ='PMIAGING'  
            AND (lli.QtyAllocated + lli.QtyPicked + LLI.QtyReplen) = 0  
            ORDER BY LOC.Loc  
           
            IF @cSuggToLOC = ''  
            BEGIN  
             SELECT TOP 1    
                  @cSuggToLOC = LOC.LOC  
               FROM dbo.LOC LOC WITH (NOLOCK)  
               WHERE LOC.Facility = @cFacility  
               --AND LOC.LocLevel = '1'  
               AND LOC.pickzone ='PMIAGING'  
            END  
         END  
         ELSE  
         BEGIN   
          -- not special condition, look for EMPTY putaway loc  
          IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.LOTxLOCxID WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND LOC = @cPutawayLoc AND ID = @cID )  
          BEGIN  
             -- check dbo.LOC  
             SELECT TOP 1    
                  @cSuggToLOC = LOC.LOC  
               FROM dbo.LOC LOC WITH (NOLOCK)  
               WHERE LOC.Facility = @cFacility  
               --AND LOC.LocLevel = '1'  
               AND LOC.Loc = @cPutawayLoc  
          END  
          ELSE  
          BEGIN  
           -- 1.find empty loc by PutawayLoc  
             SELECT TOP 1    
                  @cSuggToLOC = LOC.LOC  
               FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)  
               JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)  
               WHERE LOC.Facility = @cFacility  
               AND LOC.LOC = @cPutawayLoc  
               --AND LOC.LocLevel = '1'  
               AND LLI.StorerKey = @cStorerKey  
             GROUP BY LOC.Loc  
             HAVING SUM((lli.QTY - lli.QtyAllocated - lli.QtyPicked - LLI.QtyReplen - LLI.PendingMoveIN)) = 0  
               ORDER BY LOC.Loc  
            END  
              
            --2.no empty location, look for same SKU diff lottable01 - empty loc  
            IF @cSuggToLOC = ''  
            BEGIN  
               SELECT @dLottable01 = Lottable01 FROM LOTAttribute WITH (NOLOCK) WHERE LOT = @cLOT  
  
                  SELECT TOP 1    
                     @cSuggToLOC = LOC.LOC  
                  FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)  
                  JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)  
                  JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON ( LLI.LOT = LA.LOT)  
                  WHERE LOC.Facility = @cFacility  
                  --AND LA.Lottable01 = @dLottable01  
                  --AND LOC.LocLevel = '1'  
                  AND LLI.StorerKey = @cStorerKey  
                  AND LOC.LocationCategory LIKE 'RACK%'  
                  --AND LOC.Loc <> @cPutawayLoc  
                  AND LLI.SKU = @cSKU  
                  GROUP BY LOC.LOC  
                  HAVING SUM((lli.QTY - lli.QtyAllocated - lli.QtyPicked - LLI.QtyReplen - LLI.PendingMoveIN)) = 0  
                  ORDER BY SUM( lli.Qty - lli.QtyAllocated - lli.QtyPicked - LLI.QtyReplen), LOC.Loc  
                 
                  --2b.no empty location, look for same SKU same lottable01 - occupied loc  
                  IF @@rowcount = 0  
                  BEGIN  
                   SELECT TOP 1    
                        @cSuggToLOC = LOC.LOC  
                     FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)  
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)  
                     JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON ( LLI.LOT = LA.LOT)  
                     WHERE LOC.Facility = @cFacility  
                     AND LA.Lottable01 = @dLottable01  
                     --AND LOC.LocLevel = '1'  
                     AND LLI.StorerKey = @cStorerKey  
                     AND LOC.LocationCategory LIKE 'RACK%'  
                     --AND LOC.Loc <> @cPutawayLoc  
                     AND LLI.SKU = @cSKU  
                     GROUP BY LOC.LOC  
                     HAVING SUM((lli.QTY - lli.QtyAllocated - lli.QtyPicked - LLI.QtyReplen - LLI.PendingMoveIN)) > 0  
                     ORDER BY SUM( lli.Qty - lli.QtyAllocated - lli.QtyPicked - LLI.QtyReplen) , LOC.Loc  
                  END  
                    
                  ----2c.no empty location, look for diff SKU diff altsku diff lottable01 - occupied loc  
                  --IF @@rowcount = 0  
                  --BEGIN  
                  -- SELECT TOP 1    
                  --      @cSuggToLOC = LOC.LOC  
                  --   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)  
                  --   JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)  
                  --   JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON ( LLI.LOT = LA.LOT)  
                  --   WHERE LOC.Facility = @cFacility  
                  --   AND LA.Lottable01 = @dLottable01  
                  --   AND LOC.LocLevel = '1'  
                  --   AND LLI.StorerKey = @cStorerKey  
                  --   AND LOC.LocationCategory LIKE 'RACK%'  
                  --   AND LOC.Loc <> @cPutawayLoc  
                  --   AND LLI.SKU = @cSKU  
                  --   GROUP BY LOC.LOC  
                  --   HAVING SUM((lli.QTY - lli.QtyAllocated - lli.QtyPicked - LLI.QtyReplen - LLI.PendingMoveIN)) > 0  
                  --   ORDER BY SUM( lli.Qty - lli.QtyAllocated - lli.QtyPicked - LLI.QtyReplen) , LOC.Loc  
                  --END  
             END  
                 
            IF @cSuggToLOC = ''  
            BEGIN  
               -- 3. Find a empty loc by PutawayZone in LOTxLOCxID  
               SELECT TOP 1    
                  @cSuggToLOC = LOC.LOC  
               FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)  
               JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)  
               JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON ( LLI.LOT = LA.LOT)  
               WHERE LOC.Facility = @cFacility  
               --AND LOC.LocLevel = '1'  
               AND LLI.StorerKey = @cStorerKey  
               AND LOC.LocationCategory LIKE 'RACK%'  
               AND LOC.PutawayZone = @cPutawayZone  
               GROUP BY LOC.LOC  
               HAVING SUM((lli.QTY - lli.QtyAllocated - lli.QtyPicked - LLI.QtyReplen - LLI.PendingMoveIN)) = 0  
               ORDER BY LOC.Loc  
              
               IF @@rowcount = 0  
               BEGIN  
                  -- 3b.  Find a empty loc by PutawayZone in LOC  
                  SELECT TOP 1  
                      @cSuggToLOC = LOC.LOC  
                  FROM dbo.LOC LOC WITH (NOLOCK)   
                  WHERE LOC.Facility = @cFacility  
                  AND LOC.LocationCategory LIKE 'RACK%'  
                  AND LOC.PutawayZone = @cPutawayZone  
                  AND Loc.loc NOT IN (SELECT loc FROM dbo.LOTxLOCxID (nolock) WHERE storerkey = @cStorerKey)  
                  ORDER BY LOC.Loc  
               END                  
            END  
                 
            IF @cSuggToLOC = ''  
            BEGIN  
               SET @cSuggestedLOC = ''  
               GOTO Quit  
            END            
         END  
      END  
        
   END  
     
  
   /*-------------------------------------------------------------------------------  
                                 Book suggested location  
   -------------------------------------------------------------------------------*/  
   -- Handling transaction  
   BEGIN TRAN  -- Begin our own transaction  
   SAVE TRAN rdt_523ExtPA29 -- For rollback or commit only our own transaction  
  
   IF @cSuggToLOC <> ''  
   BEGIN  
      SET @nErrNo = 0  
      EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'  
         ,@cLOC  
         ,@cID  
         ,@cSuggToLOC  
         ,@cStorerKey  
         ,@nErrNo  OUTPUT  
         ,@cErrMsg OUTPUT  
         ,@cSKU          = @cSKU  
         ,@nPutawayQTY   = @nQTY  
         ,@nPABookingKey = @nPABookingKey OUTPUT  
      IF @nErrNo <> 0  
         GOTO RollBackTran  
  
      SET @cSuggestedLOC = @cSuggToLOC  
  
      COMMIT TRAN rdt_523ExtPA29 -- Only commit change made here  
   END  
   GOTO Quit  
  
RollBackTran:  
   ROLLBACK TRAN rdt_523ExtPA29 -- Only rollback change made here  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  
END

GO
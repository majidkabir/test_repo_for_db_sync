SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_513ExtUpd01                                     */  
/* Purpose: If move all stock out of pick face then do the following    */  
/*          1. auto unassign pick face (from loc)                       */  
/*          2. auto assign pick face (to loc)                           */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date         Author    Ver.  Purposes                                */  
/* 2015-06-26   James     1.0   SOS342780 Created                       */  
/************************************************************************/  
  
CREATE PROCEDURE [RDT].[rdt_513ExtUpd01]  
    @nMobile         INT   
   ,@nFunc           INT   
   ,@cLangCode       NVARCHAR( 3)   
   ,@nStep           INT   
   ,@nInputKey       INT  
   ,@cStorerKey      NVARCHAR( 15)  
   ,@cFacility       NVARCHAR(  5)  
   ,@cFromLOC        NVARCHAR( 10)  
   ,@cFromID         NVARCHAR( 18)  
   ,@cSKU            NVARCHAR( 20)  
   ,@nQTY            INT  
   ,@cToID           NVARCHAR( 18)  
   ,@cToLOC          NVARCHAR( 10)  
   ,@nErrNo          INT           OUTPUT   
   ,@cErrMsg         NVARCHAR( 20) OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE  @cToLOC_Fac             NVARCHAR( 5),  
            @cLoseID                NVARCHAR( 1),  
            @cLocationType          NVARCHAR( 10),  
            @nTranCount             INT,  
            @nQtyLocationLimit      INT,  
            @nQtyLocationMinimum    INT,  
            @cReplenishmentPriority NVARCHAR( 5),     
            @nReplenishmentSeverity INT,               
            @nReplenishmentCasecnt  INT  
  
   SELECT @cToLOC_Fac = Facility FROM dbo.LOC WITH (NOLOCK) WHERE LOC = @cToLOC  
  
   SET @nTranCount = @@TRANCOUNT    
   BEGIN TRAN  
   SAVE TRAN rdt_513ExtUpd01  
     
   -- Move by SKU  
   IF @nFunc = 513  
   BEGIN  
      IF @nStep = 6 -- ToLOC  
      BEGIN  
         IF @nInputKey = 1 -- Enter  
         BEGIN  
            SET @cLoseID = ''  
            SET @cLocationType = ''  
  
            -- Get FinalLOC info  
            SELECT  
               @cLocationType = LocationType,  
               @cLoseID = LoseID  
            FROM dbo.LOC WITH (NOLOCK)  
            WHERE LOC = @cToLOC  
  
            SELECT   
               @nQtyLocationLimit = QtyLocationLimit,   
               @nQtyLocationMinimum = QtyLocationMinimum,   
               @cReplenishmentPriority = ReplenishmentPriority,   
               @nReplenishmentSeverity = ReplenishmentSeverity,               
               @nReplenishmentCasecnt = ReplenishmentCasecnt  
            FROM dbo.SKUxLOC WITH (NOLOCK)   
            WHERE StorerKey = @cStorerKey  
               AND SKU = @cSKU  
               AND LOC = @cFromLOC  
  
            IF @cLocationType = 'PICK'  
            BEGIN  
               -- 1. Un assign pick face for from loc  
               UPDATE dbo.SKUxLOC WITH (ROWLOCK) SET  
                  LocationType = ''  
               WHERE StorerKey = @cStorerKey  
                  AND SKU = @cSKU  
                  AND LOC = @cFromLOC  
  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 55201  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UnAssign Pick Err  
                  GOTO RollBackTran  
               END        
                 
               -- 2. Assign pick face  
               -- Check SKU has pick face setup in this facility  
               IF NOT EXISTS( SELECT 1  
                  FROM dbo.SKUxLOC SL WITH (NOLOCK)  
                  JOIN LOC WITH (NOLOCK) ON (SL.LOC = LOC.LOC)  
                  WHERE SL.StorerKey = @cStorerKey  
                     AND SL.SKU = @cSKU  
            AND SL.LocationType IN ('CASE', 'PICK')  
                     AND LOC.Facility = @cToLOC_Fac)  
               BEGIN  
                  -- Set pick face LOC must loseID (checked in ntrSKUxLOCAdd)  
                  IF @cLoseID <> '1'  
                  BEGIN  
                     UPDATE LOC WITH (ROWLOCK) SET   
                        LoseID = '1'   
                     WHERE LOC = @cToLOC  
  
                     IF @@ERROR <> 0  
                     BEGIN  
                        SET @nErrNo = 55202  
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Lose ID Fail  
                        GOTO RollBackTran  
                     END        
                  END  
  
                  IF EXISTS( SELECT 1 FROM dbo.SKUxLOC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU AND LOC = @cToLOC)  
                  BEGIN  
                     UPDATE SKUxLOC WITH (ROWLOCK) SET  
                        LocationType = 'PICK',   
                        QtyLocationLimit = CASE WHEN ISNULL( QtyLocationLimit, 0) = 0 THEN @nQtyLocationLimit ELSE QtyLocationLimit END,   
                        QtyLocationMinimum = CASE WHEN ISNULL( QtyLocationMinimum, 0) = 0 THEN @nQtyLocationMinimum ELSE QtyLocationMinimum END,  
                        ReplenishmentCasecnt = CASE WHEN ISNULL( ReplenishmentCasecnt, 0) = 0 THEN @nReplenishmentCasecnt ELSE ReplenishmentCasecnt END  
                     WHERE StorerKey = @cStorerKey  
                        AND SKU = @cSKU  
                        AND LOC = @cToLOC  
  
                     IF @@ERROR <> 0  
                     BEGIN  
                        SET @nErrNo = 55203  
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Update Pick Fail  
                        GOTO RollBackTran  
                     END        
                  END  
                  ELSE  
                  BEGIN  
                     INSERT INTO dbo.SKUxLOC (StorerKey,   
                     SKU,   
                     LOC,   
                     LocationType,   
                     QtyLocationLimit,   
                     QtyLocationMinimum,   
                     ReplenishmentPriority,   
                     ReplenishmentSeverity,   
                     ReplenishmentCasecnt) VALUES   
                     (@cStorerKey,   
                     @cSKU,   
                     @cToLOC,   
                     'PICK',   
                     @nQtyLocationLimit,   
                     @nQtyLocationMinimum,   
                     @cReplenishmentPriority,   
                     @nReplenishmentSeverity,   
                     @nReplenishmentCasecnt)  
  
                     IF @@ERROR <> 0  
                     BEGIN  
                        SET @nErrNo = 55204  
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Assign Pick Fail  
                        GOTO RollBackTran  
                     END        
                  END  
               END  
            END  
         END  
      END  
   END  
END  
  
GOTO Quit  
  
RollBackTran:  
   ROLLBACK TRAN rdt_513ExtUpd01 -- Only rollback change made in rdt_513ExtUpd01  
Quit:  
   -- Commit until the level we started  
   WHILE @@TRANCOUNT > @nTranCount  
      COMMIT TRAN     
  
Fail:   

GO
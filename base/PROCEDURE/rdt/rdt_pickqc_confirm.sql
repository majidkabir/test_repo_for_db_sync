SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

    
/******************************************************************************/    
/* Store procedure: rdt_PickQC_Confirm                                        */    
/* Copyright      : LF Logistics                                              */    
/*                                                                            */    
/* Date       Rev  Author     Purposes                                        */    
/* 10-09-2020 1.0  Chermaine  WMS-14893 Created                               */    
/******************************************************************************/    
    
CREATE PROC [RDT].[rdt_PickQC_Confirm] (    
    @nMobile         INT    
   ,@nFunc           INT  
   ,@cUserName       NVARCHAR(18)         
   ,@cLangCode       NVARCHAR( 3)    
   ,@nStep           INT    
   ,@nInputKey       INT    
   ,@cFacility       NVARCHAR( 5)    
   ,@cStorerKey      NVARCHAR( 15)      
   ,@cPickSlipNo     NVARCHAR( 10)        
   ,@nErrNo          INT           OUTPUT    
   ,@cErrMsg         NVARCHAR(250) OUTPUT    
)    
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE @nTranCount  INT   
    
   DECLARE 
      @cScanPickslip    NVARCHAR( 10),
      @cScanSKU         NVARCHAR( 20),
      @nScanTtlQty      INT,
      @nScanReasonCode  NVARCHAR( 10),
      @cPickDetailKey   NVARCHAR( 18),
      @cToID            NVARCHAR( 18),
      @nQTY_PD          INT,
      @cFromLoc         NVARCHAR( 10),
      @cFromLot         NVARCHAR( 10),
      @cOrderKey        NVARCHAR( 10),
      @cFromID          NVARCHAR( 18),
      @cPickQCToLoc     NVARCHAR( 10),
      @nMove            INT
      
   DECLARE @curPD       CURSOR
   DECLARE @curLog      CURSOR
   
   SET @cPickQCToLoc = ''
   SET @cPickQCToLoc = rdt.RDTGetConfig( @nFunc, 'PickQCToLoc', @cStorerKey) 
   
   SET @nMove = 0
   
   IF @cPickQCToLoc = '0' 
   BEGIN
      SET @nErrNo = 158814  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need To Loc  
      GOTO RollBackTran
   END
   
   -- Handling transaction    
   SET @nTranCount = @@TRANCOUNT    
   BEGIN TRAN  -- Begin our own transaction    
   SAVE TRAN rdt_PickQC_Confirm -- For rollback or commit only our own transaction    
   
   SET @curLog = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      select 
         pickslipNo,sku,SUM(ScanQty),ReasonCode 
      FROM RDT.RDTPickQCLog WITH (NOLOCK) 
      WHERE pickslipNo = @cPickslipNo 
      AND Mobile = @nMobile 
      AND MovedQty =0
      GROUP BY pickslipNo,sku,ReasonCode 
         
   OPEN @curLog;
   FETCH NEXT FROM @curLog INTO @cScanPickslip,@cScanSKU,@nScanTtlQty,@nScanReasonCode
   WHILE @@FETCH_STATUS = 0
   BEGIN
   	
   	SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   	   SELECT 
   	      PD.pickDetailKey, PD.QTY, PD.Loc, PD.Lot, PD.OrderKey, PD.ID
         FROM pickDetail PD WITH (NOLOCK) 
         JOIN LOC LOC WITH (NOLOCK) ON (PD.Loc = LOC.LOC)
         WHERE PD.pickSlipNo = @cScanPickslip
         AND PD.SKU = @cScanSKU
         AND PD.QTY > 0
         AND PD.Storerkey = @cStorerKey
         ORDER BY CASE WHEN LOC.LocationType = 'PICK' THEN 0 WHEN LOC.LocationType ='OTHER' THEN 1 END
         
      OPEN @curPD;
      FETCH NEXT FROM @curPD INTO @cPickDetailKey,@nQTY_PD,@cFromLoc,@cFromLot,@cOrderKey,@cFromID
      WHILE @@FETCH_STATUS = 0
      BEGIN

      	--pickDetail hav more or same qty can direct minus from this PD line 
   	   IF @nQTY_PD >= @nScanTtlQty AND @nScanTtlQty > 0
   	   BEGIN
   	   	UPDATE pickDetail WITH (ROWLOCK) SET
         	   QTY = QTY - @nScanTtlQty
         	WHERE pickslipNo = @cScanPickslip
         	AND SKU = @cScanSKU
         	AND storerKey = @cStorerKey
         	AND pickDetailKey = @cPickDetailKey 
         	
         	IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 158816  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Fail UPD PKD   
               GOTO RollBackTran   
            END
            
            SET @cToID = @nScanReasonCode + @cScanPickslip
            
            EXEC rdt.rdt_Move
               @nMobile     = @nMobile,  
               @cLangCode   = @cLangCode,   
               @nErrNo      = @nErrNo  OUTPUT,  
               @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 char max  
               @cSourceType = 'rdt_PickQC_Confirm',   
               @cStorerKey  = @cStorerKey,  
               @cFacility   = @cFacility,   
               @cFromLOC    = @cFromLOC,   
               @cToLOC      = @cPickQCToLoc,   
               @cFromID     = @cFromID,      -- NULL means not filter by ID. Blank is a valid ID  
               @cToID       = @cToID,    -- NULL means not changing ID. Blank consider a valid ID  
               @cSKU        = @cScanSKU,   
               @cUCC        = NULL,
               @nQTY        = @nScanTtlQty,     
               @cFromLOT    = @cFromLot, 
               @nFunc       = @nFunc,
               @cOrderKey   = @cOrderKey
                             
               
            IF @nErrNo <> 0  
            GOTO RollBackTran  
                     
            EXEC RDT.rdt_STD_EventLog  
               @cActionType   = '8',   
               @cUserID       = @cUserName,  
               @nMobileNo     = @nMobile,  
               @nFunctionID   = @nFunc,  
               @cFacility     = @cFacility,  
               @cStorerKey    = @cStorerkey,
               @cLocation     = @cFromLoc,
               @cToLocation   = @cPickQCToLoc,
               @cToID         = @cToID,
               @nQTY          = @nScanTtlQty,
               @cPickSlipNo   = @cScanPickslip,
               @cReasonKey    = @nScanReasonCode,
               @cSKU          = @cScanSKU
               
            SET @nScanTtlQty = 0
         	
   	   END
   	   --PD line not enuf to minus need loop others PD line to minus
   	   ELSE IF @nQTY_PD < @nScanTtlQty
   	   BEGIN
   	   	UPDATE pickDetail WITH (ROWLOCK) SET
         	   QTY = 0
         	WHERE pickslipNo = @cScanPickslip
         	AND SKU = @cScanSKU
         	AND storerKey = @cStorerKey
         	AND pickDetailKey = @cPickDetailKey
         	
         	SET @nScanTtlQty = @nScanTtlQty - @nQTY_PD
         	
         	SET @cToID = @nScanReasonCode + @cScanPickslip
            
            EXEC rdt.rdt_Move
               @nMobile     = @nMobile,  
               @cLangCode   = @cLangCode,   
               @nErrNo      = @nErrNo  OUTPUT,  
               @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 char max  
               @cSourceType = 'rdt_PickQC_Confirm',   
               @cStorerKey  = @cStorerKey,  
               @cFacility   = @cFacility,   
               @cFromLOC    = @cFromLOC,   
               @cToLOC      = @cPickQCToLoc,   
               @cFromID     = @cFromID,      -- NULL means not filter by ID. Blank is a valid ID  
               @cToID       = @cToID,    -- NULL means not changing ID. Blank consider a valid ID  
               @cSKU        = @cScanSKU,   
               @cUCC        = NULL,
               @nQTY        = @nQTY_PD,     
               @cFromLOT    = @cFromLot, 
               @nFunc       = @nFunc,
               @cOrderKey   = @cOrderKey
               
            IF @nErrNo <> 0  
            GOTO RollBackTran  
   	   
         	IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 158815  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Fail UPD PKD   
               GOTO RollBackTran   
            END
            
            EXEC RDT.rdt_STD_EventLog  
               @cActionType   = '8',   
               @cUserID       = @cUserName,  
               @nMobileNo     = @nMobile,  
               @nFunctionID   = @nFunc,  
               @cFacility     = @cFacility,  
               @cStorerKey    = @cStorerkey,
               @cLocation     = @cFromLoc,
               @cToLocation   = @cPickQCToLoc,
               @cToID         = @cToID,
               @nQTY          = @nQTY_PD,
               @cPickSlipNo   = @cScanPickslip,
               @cReasonKey    = @nScanReasonCode
               
          END

          if EXISTS (SELECT 1 FROM pickdetail (NOLOCK) 
                     WHERE storerKey = @cStorerKey 
                     AND pickslipNo = @cPickSlipNo 
                     AND sku = @cScanSKU 
                     AND PickDetailKey = @cPickDetailKey 
                     AND qty = 0)
          BEGIN
            DELETE pickDetail 
            WHERE storerKey = @cStorerKey 
            AND pickslipNo = @cPickSlipNo 
            AND sku = @cScanSKU 
            AND PickDetailKey = @cPickDetailKey 
            AND Qty = 0
          END

   	FETCH NEXT FROM @curPD INTO @cPickDetailKey,@nQTY_PD,@cFromLoc,@cFromLot,@cOrderKey,@cFromID
   	END
            	
      UPDATE rdt.RDTPickQCLog SET MovedQty = 1 WHERE pickslipNo = @cScanPickslip AND SKU = @cScanSKU AND movedQty = 0 AND Mobile = @nMobile 
    
   FETCH NEXT FROM @curLog INTO  @cScanPickslip,@cScanSKU,@nScanTtlQty,@nScanReasonCode  
   END    
     
    
   GOTO Quit    
    
RollBackTran:    
   ROLLBACK TRAN rdt_PickQC_Confirm -- Only rollback change made here    
Quit:    
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
      COMMIT TRAN    
END 

GO
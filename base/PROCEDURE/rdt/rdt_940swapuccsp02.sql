SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/**************************************************************************/  
/* Store procedure: rdt_940SwapUCCSP02                                    */  
/* Copyright      : Maersk                                                */  
/*                                                                        */  
/* Purpose: Swap UCC between allocated UCC and (allocated &               */  
/*          unallocated UCC within replenishment) for Granite             */  
/* Called by: UCC Replenishment From                                      */  
/*                                                                        */  
/* Modifications log:                                                     */  
/*                                                                        */  
/* Date       Rev    Author   Purposes                                    */  
/* 2024-09-02 1.0    LowZhe   Created UWP-23555.                          */
/*                            Based on rdt_940SwapUCCSP01                 */ 
/* 2024-09-02 1.1    JCH507   Fixed the missing part in V1.0              */ 
/* 2024-09-30 1.2    NLT013   FCR-884 Update REPLENISHMENT and PickDetail */
/*                            after swapping UCC                          */ 
/* 2024-11-04 1.3.0  NLT013   UWP-26518 Only non-allocated UCC is valid   */
/**************************************************************************/  
  
CREATE   PROC [RDT].[rdt_940SwapUCCSP02] (  
    @nMobile          INT,   
    @nFunc            INT,   
    @cLangCode        NVARCHAR( 3),  
    @cUserID          NVARCHAR( 18), 
    @cFacility        NVARCHAR( 5),  
    @cStorerKey       NVARCHAR( 15), 
    @nStep            INT,           
    @cUCC             NVARCHAR( 20), 
    @cReplenGroup     NVARCHAR( 10), 
    @cLoadKey         NVARCHAR( 10), 
    @cFromLoc         NVARCHAR( 10) ,  
    @cNewUCC          NVARCHAR( 20) OUTPUT, 
    @nErrNo           INT           OUTPUT,  
    @cErrMsg          NVARCHAR( 20) OUTPUT 
) AS   
  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE   
      @cSku                NVARCHAR( 30),  
      @nQty                INT,  
      @cLottable01         NVARCHAR( 18),  
      @cLottable02         NVARCHAR( 18),  
      @cLottable03         NVARCHAR( 18),  
      @dLottable04         DATETIME,  
      @cUCCLoc             NVARCHAR( 10),  
      @cID                 NVARCHAR( 18),  
      @cPickDetailKey      NVARCHAR( 18),  
      @cNewPickDetailKey   NVARCHAR( 18),  
      @cStatus             NVARCHAR( 1),  
      @cNewStatus          NVARCHAR( 1),  
      @nError              INT,  
      @nRowCount           INT,  
      @cReplenishmentKey   NVARCHAR( 10),  
      @cLOC                NVARCHAR( 10),  
      @cDataWindow         NVARCHAR( 50),   
      @cTargetDB           NVARCHAR( 10),  
      @cToLoc              NVARCHAR( 10), 
      @cToLocType          NVARCHAR( 10),	  
      @cCartonNo           NVARCHAR( 5),  
      @nCartonNo           INT,  
      @cPickSlipNo         NVARCHAR( 10),  
      @cWaveKey            NVARCHAR( 10),  
      @cNewWaveKey         NVARCHAR( 10),  
      @cLOT                NVARCHAR( 10),  
      @cNewLoadKey         NVARCHAR( 15),
      @nTranCount          INT,
      @cOrderKey           NVARCHAR( 10), 
      @cOrderLineNumber    NVARCHAR( 5),
      @cOriginalUCC        NVARCHAR(20),
      @cUCCStatus          NVARCHAR( 1),
      @cOriginalStatus     NVARCHAR( 1)

    


   SET @nTranCount = @@TRANCOUNT
   
   BEGIN TRAN
   SAVE TRAN rdt_940SwapUCCSP02
   
   IF @nFunc = 940 
   BEGIN
      IF @nStep = 4
      BEGIN
    
            SELECT @cSku = '',      
                   @nQty = 0,   
                   @cLottable01 = '',   
                   @cLottable02 = '',   
                   @cLottable03 = '',   
                   @dLottable04 = NULL,  
                   @cUCCLoc = '',   
                   @cID = '',   
                   @cPickDetailKey = '',   
                   @cNewUCC='',   
                   @cStatus = '',  
                   @cOrderKey = '',
                   @cOrderLineNumber = '',      
                   @cOriginalUCC = '',
                   @cUCCStatus = '' 

            
            SELECT   @cSku          = UCC.Sku,  
                     @nQty          = UCC.Qty,  
                     @cLOT          = UCC.LOT,  
                     @cUCCLoc       = UCC.Loc,  
                     @cID           = UCC.ID,
                     @cUCCStatus    = UCC.Status,
                     @cWaveKey      = UCC.WaveKey ,
                     @cLoadKey      = UCC.Userdefined01 , 
                     @cOrderKey     = UCC.OrderKey,
                     @cOrderLineNumber = UCC.OrderLineNumber,
                     @cPickDetailKey   = UCC.PickDetailKey
            FROM dbo.UCC UCC WITH (NOLOCK)  
            JOIN dbo.Lotattribute LOT WITH (NOLOCK) ON UCC.Lot = LOT.Lot AND UCC.StorerKey = LOT.StorerKey  
            WHERE UCC.UCCNo = @cUCC  
               AND UCC.StorerKey = @cStorerKey

            IF ISNULL(RTRIM(@cFromLoc),'')  <> '' 
            BEGIN
               IF ISNULL(RTRIM(@cFromLoc),'')  <> ISNULL(RTRIM(@cUCCLoc),'') 
               BEGIN
                  SET @nErrNo = 93468  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Invalid UCC  
                  GOTO RollBackTran
               END
            END
            
            -- Get Matching UCC Records
            SELECT  Top 1
                           @cOriginalUCC  = RP.RefNo,
                           @cToLoc        = RP.ToLoc,
                           @cLoc          = RP.FromLoc,
                           @cToLocType    = L.LocationType
            FROM dbo.Replenishment RP WITH (NOLOCK) 
            Inner join Loc L WITH (NOLOCK) on RP.ToLoc = L.LOC
            WHERE RP.StorerKey = @cStorerKey
            AND RP.SKU = @cSKU
            AND RP.Lot = @cLot
            AND RP.Qty = @nQty
            AND RP.FromLoc = @cUCCLoc
            AND RP.ID  = @cID
            AND RP.RefNo = @cUCC
            AND RP.ReplenishmentGroup = @cReplenGroup
            AND RP.Confirmed = 'N'
            ORDER BY RP.RefNo
            
            IF ISNULL(RTRIM(@cOriginalUCC),'')  <> ''
            BEGIN
               
               IF ISNULL(RTRIM(@cUCCStatus),'')  <> '1' 
               BEGIN
                  IF @cToLocType = 'PICK' 
                  BEGIN
                     IF NOT EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK)
                                     WHERE UCCNo = @cUCC
                                     AND Status = '3' ) 
                     BEGIN
                         SET @nErrNo = 93461  
                         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Invalid UCC  
                         GOTO RollBackTran
                     END
                  END
                  ELSE 
                  BEGIN
                     IF EXISTS ( SELECT 1 FROM dbo.LOC WITH (NOLOCK)
                                 WHERE Loc = @cToLoc
                                 AND LocationType = 'DYNAMICPK' ) 
                     BEGIN
                           IF NOT EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK)
                           WHERE UCCNo = @cUCC
                           AND Status = '3' ) 
                           BEGIN
                               SET @nErrNo = 93462 
                               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Invalid UCC  
                               GOTO RollBackTran
                           END
                     END  
                     ELSE
                     BEGIN
                        IF NOT EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK)
                                        WHERE UCCNo = @cUCC
                                        AND Status = '6' ) 
                        BEGIN
                            SET @nErrNo = 93463  
                            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Invalid UCC  
                            GOTO RollBackTran
                        END
                     END
                  END
               END
            END
            

            IF ISNULL(RTRIM(@cOriginalUCC),'')  <> ISNULL(RTRIM(@cUCC),'') 
            BEGIN
               SET @cPickDetailKey= ''
               SET @cStatus       = ''
               SET @cWaveKey      = '' 
               SET @cLoadKey      = ''
               SET @cOrderKey     = ''
               SET @cOrderLineNumber = ''
               SET @cOriginalUCC  = ''

               IF EXISTS ( SELECT 1 FROM dbo.Replenishment WITH (NOLOCK) 
                           WHERE RefNo = @cUCC
                           AND ReplenishmentGroup <> @cReplenGroup )
               BEGIN
                  SET @nErrNo = 93467
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidUCC
                  GOTO RollBackTran    
               END

               SELECT  Top 1 
                                         @cOriginalUCC  = RP.RefNo,
                                         @cToLoc        = RP.ToLoc,
                                         @cLoc          = RP.FromLoc,
                                         @cToLocType    = L.LocationType -- V1.1 JCH507
               FROM dbo.Replenishment RP WITH (NOLOCK)
               INNER JOIN Loc L WITH (NOLOCK) ON RP.ToLoc = L.Loc -- V1.1 JCH507
               WHERE RP.StorerKey = @cStorerKey
               AND RP.SKU = @cSKU
               AND RP.Lot = @cLot
               AND RP.Qty = @nQty
               AND RP.FromLoc = @cUCCLoc
               AND RP.ID  = @cID
               AND RP.RefNo <> @cUCC
               AND RP.ReplenishmentGroup = @cReplenGroup
               AND RP.Confirmed = 'N'
               ORDER BY RP.RefNo

               IF ISNULL(RTRIM(@cOriginalUCC),'')  = '' OR @cUCCStatus <> '1'
               BEGIN
                  SET @nErrNo = 93459
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidUCC
                  GOTO RollBackTran    
               END
               ELSE
               BEGIN
                  
                  SELECT   
                           @cOriginalStatus = UCC.Status,
                           @cWaveKey      = UCC.WaveKey ,
                           @cLoadKey      = UCC.Userdefined01 , 
                           @cOrderKey     = UCC.OrderKey,
                           @cOrderLineNumber = UCC.OrderLineNumber,
                           @cPickDetailKey   = UCC.PickDetailKey
                  FROM dbo.UCC UCC WITH (NOLOCK)  
                  JOIN dbo.Lotattribute LOT WITH (NOLOCK) ON UCC.Lot = LOT.Lot AND UCC.StorerKey = LOT.StorerKey  
                  WHERE UCC.UCCNo = @cOriginalUCC  
                    AND UCC.StorerKey = @cStorerKey 
                  
                  IF ISNULL(RTRIM(@cUCCStatus),'')  <> '1' 
                  BEGIN
                     IF @cToLocType = 'PICK' -- V1.1 JCH507
                     BEGIN
                        IF NOT EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK)
                                        WHERE UCCNo = @cUCC
                                        AND Status = '3' ) 
                        BEGIN
                            SET @nErrNo = 93464  
                            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Invalid UCC  
                            GOTO RollBackTran
                        END
                     END
                     ELSE 
                     BEGIN
                        IF EXISTS ( SELECT 1 FROM dbo.LOC WITH (NOLOCK)
                                    WHERE Loc = @cToLoc
                                    AND LocationType = 'DYNAMICPK' ) 
                        BEGIN
                              IF NOT EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK)
                              WHERE UCCNo = @cUCC
                              AND Status = '3' ) 
                              BEGIN
                                  SET @nErrNo = 93465 
                                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Invalid UCC  
                                  GOTO RollBackTran
                              END
                        END  
                        ELSE
                        BEGIN
                           IF NOT EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK)
                                           WHERE UCCNo = @cUCC
                                           AND Status = '6' ) 
                           BEGIN
                               SET @nErrNo = 93466  
                               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Invalid UCC  
                               GOTO RollBackTran
                           END
                        END
                     END
                  END
               END

            END
            ELSE
            BEGIN
               GOTO QUIT
            END

            SET @cNewUCC = @cUCC
     
            -- Check if scanned UCC (sku, qty, lot, loc, id) exists in our replenishmentgroup  
            IF NOT EXISTS (SELECT 1   
                           FROM dbo.Replenishment RP WITH (NOLOCK)  
                           JOIN dbo.Lotattribute LA WITH (NOLOCK)  
                                ON RP.Lot = LA.Lot    
                           WHERE RP.StorerKey = @cStorerKey   
                           AND RP.SKU = @cSku  
                           AND RP.ReplenishmentGroup = @cReplenGroup   
                           AND RP.QTY = @nQty  
                           AND RP.FromLOC = @cUCCLoc  
                           AND RP.ID = @cID  
                           AND LA.StorerKey = @cStorerKey   
                           AND LA.SKU = @cSku  
                           AND LA.LOT = @cLOT )  
            BEGIN  
               SET @nErrNo = 93452
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Invalid UCC  
               GOTO RollBackTran    
            END  

            -- Swap Begin  
            BEGIN  

               IF EXISTS(SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
                         WHERE StorerKey = @cStorerKey  
                           AND RefNo IN (@cUCC, @cOriginalUCC))  
               BEGIN   
                  --Update packDetail  
                  UPDATE PD WITH (ROWLOCK) SET  
                     PD.RefNo = @cUCC,
                     PD.ArchiveCop = NULL,   
                     PD.EditDate = GETDATE(),  
                     PD.EditWho = 'rdt.' + sUSER_sNAME()    
                  FROM dbo.PackDetail PD  
                  WHERE PD.RefNo IN (@cUCC, @cOriginalUCC)  
                     AND StorerKey = @cStorerKey  
                     AND SKU = @cSKU  
     
                  SELECT @nError = @@ERROR, @nRowCount = @@ROWCOUNT                 
     
     
                  IF @nError <> 0   
                  BEGIN  
                     SET @nErrNo = 93454  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Upd PKDtl fail  
                     GOTO RollBackTran   
                  END  
               END  
     
               --update Replenishment.RefNo  
               IF @cLOC = '' OR @cLOC IS NULL  
               BEGIN  
                  UPDATE RP WITH (ROWLOCK) SET  
                     RP.DropID = @cUCC
                  FROM dbo.Replenishment RP  
                  WHERE RP.RefNo = @cOriginalUCC
                     AND StorerKey = @cStorerKey  
                     AND SKU = @cSKU  

                  UPDATE RP WITH (ROWLOCK) SET  
                     RP.RefNo = @cUCC
                  FROM dbo.Replenishment RP  
                  WHERE RP.RefNo IN (@cUCC, @cOriginalUCC)  
                     AND StorerKey = @cStorerKey  
                     AND SKU = @cSKU  
     
                  SELECT @nError = @@ERROR, @nRowCount = @@ROWCOUNT
               END  
               ELSE  
               BEGIN  
                  UPDATE RP WITH (ROWLOCK) SET  
                     RP.DropID = @cUCC
                  FROM dbo.Replenishment RP  
                  WHERE RP.RefNo = @cOriginalUCC
                     AND StorerKey = @cStorerKey  
                     AND SKU = @cSKU  
                     AND FromLoc = @cLOC

                  UPDATE RP WITH (ROWLOCK) SET  
                     RP.RefNo = @cUCC
                  FROM dbo.Replenishment RP  
                  WHERE RP.RefNo IN (@cUCC, @cOriginalUCC)  
                     AND StorerKey = @cStorerKey  
                     AND SKU = @cSKU  
                     AND FromLoc = @cLOC  
     
                  SELECT @nError = @@ERROR, @nRowCount = @@ROWCOUNT  
               END  
     
               IF @nError <> 0   
               BEGIN  
                  SET @nErrNo = 93455  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --UpdReplenfail  
                  GOTO RollBackTran   
               END  
     
     
               --update new ucc.pickdetailkey and status  
               UPDATE dbo.UCC WITH (ROWLOCK) 
               SET Status           = @cOriginalStatus
                  ,OrderKey         = @cOrderKey
                  ,OrderLineNumber  = @cOrderLineNumber
                  ,PickDetailKey    = @cPickDetailKey
                  ,WaveKey          = @cWaveKey
               WHERE StorerKey = @cStorerKey
               AND UCCNo = @cUCC
                   
               IF @@ERROR <> 0   
               BEGIN  
                  SET @nErrNo = 93456  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --UpdNewUCCfail  
                  GOTO RollBackTran   
               END  
               
               UPDATE dbo.UCC WITH (ROWLOCK) 
               SET Status           = '1' 
                  ,OrderKey         = ''
                  ,OrderLineNumber  = ''
                  ,PickDetailKey  = ''
                  ,WaveKey        = ''
               WHERE StorerKey = @cStorerKey
               AND UCCNo = @cOriginalUCC
                   
               IF @@ERROR <> 0   
               BEGIN  
                  SET @nErrNo = 93457  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --UpdOldUCCfail  
                  GOTO RollBackTran   
               END  

               UPDATE dbo.PickDetail 
                  SET CartonGroup = RIGHT ( @cUCC ,8 )
                     , DropID = @cUCC
                     , EditWho     = suser_sname()
                     , EditDate    = Getdate()
                     , Trafficcop  = NULL
               WHERE StorerKey   = @cStorerKey
                  AND ISNULL(DropID, '') =  @cOriginalUCC
                  AND SKU = @cSKU  

--               
               IF @@ERROR <> 0 
               BEGIN
                  SET @nErrNo = 93458
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --UpdPDFail  
                  GOTO RollBackTran  
               END
               
  
            END  
      
      END -- Step 4 
      
   GOTO QUIT 
   
   RollBackTran:
   ROLLBACK TRAN rdt_940SwapUCCSP02 -- Only rollback change made here

   Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN rdt_940SwapUCCSP02
      
   END 
END  


GO
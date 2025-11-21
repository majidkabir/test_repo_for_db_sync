SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_940SwapUCCSP01                                  */  
/* Copyright      : LF                                                  */  
/*                                                                      */  
/* Purpose: Swap UCC between allocated UCC and (allocated &             */  
/*          unallocated UCC within replenishment)                       */  
/* Called by: UCC Replenishment From                                    */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author   Purposes                                    */  
/* 2015-05-20 1.0  ChewKP   Created. SOS#342071                         */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_940SwapUCCSP01] (  
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
   SAVE TRAN rdt_940SwapUCCSP01
   
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
            SELECT  Top 1 --@cPickDetailKey= UCC.PickDetailKey,  
                          --@cStatus       = UCC.Status,  
                          --@cWaveKey      = UCC.WaveKey,  
                          --@cLoadKey      = UCC.Userdefined01 , 
                          --@cOrderKey     = UCC.OrderKey,
                          --@cOrderLineNumber = UCC.OrderLineNumber,
                          @cOriginalUCC  = RP.RefNo,
                          @cToLoc        = RP.ToLoc,
                          @cLoc          = RP.FromLoc
            FROM dbo.Replenishment RP WITH (NOLOCK) 
--            INNER JOIN dbo.Replenishment RP WITH (NOLOCK) ON 
--                          RP.ID      = UCC.ID
--                     AND  RP.FromLoc = UCC.Loc
--                     AND  RP.SKU     = UCC.SKU
--                     AND  RP.Lot     = UCC.Lot
            --INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = RP.ToLoc  
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
                  IF @cToLoc = 'PICK' 
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
            
    
            
--            INSERT INTO TRACEINFO (TracEName , TimeIN , Col1, Col2, Col3 , col4, col5 ) 
--            VALUES ( 'UCCTBL', Getdate() , @cUCC , @cOriginalUCC , @cPickDetailKey , @cOrderKey , '1')

            IF ISNULL(RTRIM(@cOriginalUCC),'')  <> ISNULL(RTRIM(@cUCC),'') 
            BEGIN
                
                --validate ucc to check whether the status ='1' or status ='3'  
                  
--                IF NOT EXISTS(SELECT 1  
--                   FROM dbo.UCC WITH (NOLOCK)  
--                   WHERE UCCNo = @cUCC  
--                      AND StorerKey = @cStorerKey     
--                      AND Status = '1'
--                      AND Lot <> '')  
--                BEGIN  
--                   SET @nErrNo = 93451  
--                   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Invalid UCC  
--                   GOTO RollBackTran    
--                END  
    
         
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

               SELECT  Top 1 --@cPickDetailKey= UCC.PickDetailKey,  
--                                         --@cStatus       = UCC.Status,  
--                                         @cWaveKey      = UCC.WaveKey,  
--                                         @cLoadKey      = UCC.Userdefined01 , 
--                                         @cOrderKey     = UCC.OrderKey,
--                                         @cOrderLineNumber = UCC.OrderLineNumber,
                                         @cOriginalUCC  = RP.RefNo,
                                         @cToLoc        = RP.ToLoc,
                                         @cLoc          = RP.FromLoc
--                                         @cOriginalStatus = UCC.Status
               FROM dbo.Replenishment RP WITH (NOLOCK) 
--               INNER JOIN dbo.Replenishment RP WITH (NOLOCK) ON 
--                             RP.ID      = UCC.ID
--                        AND  RP.FromLoc = UCC.Loc
--                        AND  RP.SKU     = UCC.SKU
--                        AND  RP.Lot     = UCC.Lot  
               --INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = RP.ToLoc                          
               WHERE RP.StorerKey = @cStorerKey
               AND RP.SKU = @cSKU
               AND RP.Lot = @cLot
               AND RP.Qty = @nQty
               AND RP.FromLoc = @cUCCLoc
               AND RP.ID  = @cID
               AND RP.RefNo <> @cUCC
               --AND UCC.Status = '1'
               AND RP.ReplenishmentGroup = @cReplenGroup
               AND RP.Confirmed = 'N'
               ORDER BY RP.RefNo

        

               IF ISNULL(RTRIM(@cOriginalUCC),'')  = ''
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
                     IF @cToLoc = 'PICK' 
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
     
--            INSERT INTO TRACEINFO (TracEName , TimeIN , Col1, Col2, Col3 , col4, col5 ) 
--            VALUES ( 'UCCTBL', Getdate() , @cUCC , @cOriginalUCC , @cPickDetailKey , @cOrderKey , '2')

            -- Check if scanned UCC (sku, qty, lot, loc, id) exists in our replenishmentgroup  
            IF NOT EXISTS (SELECT 1   
                           FROM dbo.Replenishment RP WITH (NOLOCK)  
                           JOIN dbo.Lotattribute LA WITH (NOLOCK)  
                                ON RP.Lot = LA.Lot    
                           WHERE RP.StorerKey = @cStorerKey   
                           AND RP.SKU = @cSku  
                           AND RP.ReplenishmentGroup = @cReplenGroup   
--                           AND (RP.Confirmed = 'W' OR   
--                               (RP.Confirmed = 'Y' AND DropID = '') OR   
--                               (RP.Confirmed = 'Y' AND DropID = 'L') OR   
--                               (RP.Confirmed = 'L' AND DropID = '') )  
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
     
            --get the swap ucc with same information  
            --SET @cNewUCC = ''  
     
--            SET ROWCOUNT 1  
--              
--            SELECT @cNewUCC = UCC.UCCNo,  
--                   @cNewPickDetailKey = UCC.PickDetailKey,  
--                   @cNewStatus  = UCC.Status,  
--                   @cNewWaveKey = UCC.WaveKey,  
--                   @cNewLoadKey = UCC.Userdefined01   
--            FROM dbo.UCC UCC WITH (NOLOCK)  
--            JOIN dbo.LotAttribute LOT WITH (NOLOCK)  
--                  ON UCC.Lot = LOT.Lot AND UCC.StorerKey = LOT.StorerKey AND UCC.Sku = LOT.Sku   
--            JOIN dbo.Replenishment RP WITH (NOLOCK)   
--                  ON RP.StorerKey = RP.StorerKey AND RP.SKU = UCC.SKU AND RP.RefNo = UCC.UCCNo   
--            WHERE UCC.StorerKey = @cStorerKey  
--               AND UCC.Sku = @cSku  
--               AND UCC.Qty = @nQty  
--               AND UCC.LOT = @cLOT  
--               AND UCC.Loc = @cUCCLoc  
--               AND UCC.ID  = @cID  
--               AND UCC.UCCNo <> @cUCC  
--               AND UCC.Status in ('1')  
--               AND RP.ReplenishmentGroup = @cReplenGroup   
----               AND (RP.Confirmed = 'W' OR   
----                   (RP.Confirmed = 'Y' AND DropID = '') OR   
----                   (RP.Confirmed = 'Y' AND DropID = 'L') OR   
----                   (RP.Confirmed = 'L' AND DropID = '') )  
--     
--            SET ROWCOUNT 0  
--     
--            IF @cNewUCC = '' OR @cNewUCC IS NULL  
--            BEGIN  
--               SET @nErrNo = 93453  
--               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --No UCC to swap  
--               GOTO RollBackTran   
--            END  
     
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
                     RP.RefNo = @cUCC
                  FROM dbo.Replenishment RP  
                  WHERE RP.RefNo IN (@cUCC, @cOriginalUCC)  
                     AND StorerKey = @cStorerKey  
                     AND SKU = @cSKU  
--                     AND (RP.Confirmed = 'W' OR   
--                         (RP.Confirmed = 'Y' AND DropID = '') OR   
--                         (RP.Confirmed = 'Y' AND DropID = 'L') OR   
--                         (RP.Confirmed = 'L' AND DropID = '') )  
     
                  SELECT @nError = @@ERROR, @nRowCount = @@ROWCOUNT  
               END  
               ELSE  
               BEGIN  
                  UPDATE RP WITH (ROWLOCK) SET  
                     RP.RefNo = @cUCC
                  FROM dbo.Replenishment RP  
                  WHERE RP.RefNo IN (@cUCC, @cOriginalUCC)  
                     AND StorerKey = @cStorerKey  
                     AND SKU = @cSKU  
                     AND FromLoc = @cLOC  
--                     AND (RP.Confirmed = 'W' OR   
--                         (RP.Confirmed = 'Y' AND DropID = '') OR   
--                         (RP.Confirmed = 'Y' AND DropID = 'L') OR   
--                         (RP.Confirmed = 'L' AND DropID = ''))  
     
     
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
               
--               INSERT INTO TRACEINFO (TracEName , TimeIN , Col1, Col2, Col3 , col4, col5 ) 
--               VALUES ( 'UCCTBL', Getdate() , @cUCC , @cOrderKey , @cPickDetailKey , RIGHT ( @cUCC ,8 )  , '3')

               -- Update PickDetail CartonGroup to new UCC
               UPDATE dbo.PickDetail 
                  SET CartonGroup = RIGHT ( @cUCC ,8 ) 
                     , EditWho     = suser_sname()
                     , EditDate    = Getdate()
                     , Trafficcop  = NULL
               WHERE StorerKey   = @cStorerKey
               AND OrderKey      = @cOrderKey
               AND PickDetailKey = @cPickDetailKey 

--               INSERT INTO TRACEINFO (TracEName , TimeIN , Col1, Col2, Col3 , col4, col5 ) 
--               VALUES ( 'UCCTBL', Getdate() , @cUCC , @@ROWCOUNT , @cPickDetailKey , RIGHT ( @cUCC ,8 )  , '4')
--               
               IF @@ERROR <> 0 
               BEGIN
                  SET @nErrNo = 93458
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --UpdPDFail  
                  GOTO RollBackTran  
               END
               
--               UPDATE UCC WITH (ROWLOCK) SET  
--                  UCC.Status =   
--                     CASE WHEN UCC.Status = @cNewStatus THEN @cStatus  
--                          WHEN UCC.Status = @cStatus THEN @cNewStatus END,  
--                  UCC.WaveKey =   
--                     CASE WHEN UCC.WaveKey = @cNewWaveKey THEN @cWaveKey  
--                          WHEN UCC.WaveKey = @cWaveKey THEN @cNewWaveKey END,   
--                  UCC.Userdefined01 =   
--                     CASE WHEN UCC.Userdefined01 = @cNewLoadKey THEN @cLoadKey  
--                          WHEN UCC.Userdefined01 = @cLoadKey THEN @cNewLoadKey END  
--                  UCC.OrderKey =   
--                     CASE WHEN UCC.OrderKey = @cNewLoadKey THEN @cLoadKey  
--                          WHEN UCC.OrderKey = @cLoadKey THEN @cNewLoadKey END  
--                  UCC.OrderLineNumber =   
--                     CASE WHEN UCC.OrderLineNumber = @cNewLoadKey THEN @cLoadKey  
--                          WHEN UCC.OrderLineNumber = @cLoadKey THEN @cNewLoadKey END  
--                  UCC.PickDetailKey =   
--                     CASE WHEN UCC.PickDetailKey = @cNewLoadKey THEN @cLoadKey  
--                          WHEN UCC.PickDetailKey = @cLoadKey THEN @cNewLoadKey END          
--               FROM dbo.UCC UCC  
--               WHERE UCC.UCCNo IN (@cUCC, @cNewUCC)  
--                  AND StorerKey = @cStorerKey  
--                  AND SKU = @cSKU  
     
  
            END  
      
      END -- Step 4 
      
   GOTO QUIT 
   
   RollBackTran:
   ROLLBACK TRAN rdt_940SwapUCCSP01 -- Only rollback change made here

   Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN rdt_940SwapUCCSP01
      
   END 
END  

GO
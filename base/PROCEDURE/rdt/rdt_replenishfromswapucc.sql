SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_ReplenishFromSwapUCC                            */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Swap UCC between allocated UCC and (allocated &             */  
/*          unallocated UCC within replenishment)                       */  
/* Called by: UCC Replenishment From                                    */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author   Purposes                                    */  
/* 2008-06-08 1.0  jwong    Created                                     */  
/* 2008-08-07 1.1  jwong    Remove checking on confirmed = 'L'          */  
/* 2008-08-20 1.2  Shong    Update LoadKey UCC.UserDefined01            */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_ReplenishFromSwapUCC] (  
   @nFunc        INT,  
   @nMobile      INT,  
   @cLangCode    NVARCHAR( 3),   
   @nErrNo       INT          OUTPUT,  
   @cErrMsg      NVARCHAR( 20) OUTPUT, -- screen limitation, 20 char max  
   @cUCC         NVARCHAR( 20),  
   @cStorerKey   NVARCHAR( 15),  
   @cReplenGroup NVARCHAR( 10),  
   @cNewUCC      NVARCHAR( 20)    OUTPUT  
) AS   
  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
  
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
      @cLoadKey            NVARCHAR( 15),   
      @cNewLoadKey         NVARCHAR( 15)  
        
      --validate ucc to check whether the status ='1' or status ='3'  
      IF NOT EXISTS(SELECT 1  
         FROM dbo.UCC WITH (NOLOCK)  
         WHERE UCCNo = @cUCC  
            AND StorerKey = @cStorerKey     
            AND (Status = '1' or Status = '3'))  
      BEGIN  
         SET @nErrNo = 63658  
         SET @cErrMsg = rdt.rdtgetmessage( 63658, @cLangCode,'DSP') --Invalid UCC  
         GOTO Fail    
      END  
  
  
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
                @cStatus = ''  
  
           
         SELECT   @cSku          = UCC.Sku,  
                  @nQty          = UCC.Qty,  
                  @cLOT          = UCC.LOT,  
                  @cUCCLoc       = UCC.Loc,  
                  @cID           = UCC.ID,  
                  @cPickDetailKey= UCC.PickDetailKey,  
                  @cStatus       = UCC.Status,  
                  @cWaveKey      = UCC.WaveKey,  
                  @cLoadKey      = UCC.Userdefined01  
         FROM dbo.UCC UCC WITH (NOLOCK)  
         JOIN dbo.Lotattribute LOT WITH (NOLOCK)              ON UCC.Lot = LOT.Lot AND UCC.StorerKey = LOT.StorerKey  
         WHERE UCC.UCCNo = @cUCC  
           AND UCC.StorerKey = @cStorerKey  
  
         -- Check if scanned UCC (sku, qty, lot, loc, id) exists in our replenishmentgroup  
         IF NOT EXISTS (SELECT 1   
                        FROM dbo.Replenishment RP WITH (NOLOCK)  
                        JOIN dbo.Lotattribute LA WITH (NOLOCK)  
                             ON RP.Lot = LA.Lot    
                        WHERE RP.StorerKey = @cStorerKey   
                        AND RP.SKU = @cSku  
                        AND RP.ReplenishmentGroup = @cReplenGroup   
                        AND (RP.Confirmed = 'W' OR   
                            (RP.Confirmed = 'Y' AND DropID = '') OR   
                            (RP.Confirmed = 'Y' AND DropID = 'L') OR   
                            (RP.Confirmed = 'L' AND DropID = '') )  
                        AND RP.QTY = @nQty  
                        AND RP.FromLOC = @cUCCLoc  
                        AND RP.ID = @cID  
                        AND LA.StorerKey = @cStorerKey   
                        AND LA.SKU = @cSku  
                        AND LA.LOT = @cLOT)  
         BEGIN  
            SET @nErrNo = 63677  
            SET @cErrMsg = rdt.rdtgetmessage( 63677, @cLangCode,'DSP') --Invalid UCC  
            GOTO Fail    
         END  
  
         --get the swap ucc with same information  
         SET @cNewUCC = ''  
  
         SET ROWCOUNT 1  
           
         SELECT @cNewUCC = UCC.UCCNo,  
                @cNewPickDetailKey = UCC.PickDetailKey,  
                @cNewStatus  = UCC.Status,  
                @cNewWaveKey = UCC.WaveKey,  
                @cNewLoadKey = UCC.Userdefined01   
         FROM dbo.UCC UCC WITH (NOLOCK)  
         JOIN dbo.LotAttribute LOT WITH (NOLOCK)  
               ON UCC.Lot = LOT.Lot AND UCC.StorerKey = LOT.StorerKey AND UCC.Sku = LOT.Sku   
         JOIN dbo.Replenishment RP WITH (NOLOCK)   
               ON RP.StorerKey = RP.StorerKey AND RP.SKU = UCC.SKU AND RP.RefNo = UCC.UCCNo   
         WHERE UCC.StorerKey = @cStorerKey  
            AND UCC.Sku = @cSku  
            AND UCC.Qty = @nQty  
            AND UCC.LOT = @cLOT  
            AND UCC.Loc = @cUCCLoc  
            AND UCC.ID  = @cID  
            AND UCC.UCCNo <> @cUCC  
            AND UCC.Status in ('1', '3')  
            AND RP.ReplenishmentGroup = @cReplenGroup   
            AND (RP.Confirmed = 'W' OR   
                (RP.Confirmed = 'Y' AND DropID = '') OR   
                (RP.Confirmed = 'Y' AND DropID = 'L') OR   
                (RP.Confirmed = 'L' AND DropID = '') )  
  
         SET ROWCOUNT 0  
  
         IF @cNewUCC = '' OR @cNewUCC IS NULL  
         BEGIN  
            SET @nErrNo = 63659  
            SET @cErrMsg = rdt.rdtgetmessage( 63659, @cLangCode,'DSP') --No UCC to swap  
            GOTO Fail   
         END  
  
         -- Swap Begin  
         BEGIN  
            INSERT INTO rdt.SwapUCC (Func, UCC, NewUCC, ReplenGroup, UCCStatus, NewUCCStatus)  
            VALUES (@nFunc, @cUCC, @cNewUCC, @cReplenGroup, @cStatus, @cNewStatus)   
  
            BEGIN TRAN  
  
            IF EXISTS(SELECT 1 FROM dbo.PackDetail WITH (NOLOCK, INDEX(IX_PackDetail_StorerKey_RefNo))   
                      WHERE StorerKey = @cStorerKey  
                        AND RefNo IN (@cUCC, @cNewUCC))  
            BEGIN   
               --Update packDetail  
               UPDATE PD WITH (ROWLOCK) SET  
                  PD.RefNo =   
                     CASE WHEN PD.RefNo = @cUCC THEN @cNewUCC   
                          WHEN PD.RefNo = @cNewUCC THEN @cUCC END,  
                  PD.ArchiveCop = NULL,   
                  PD.EditDate = GETDATE(),  
                  PD.EditWho = 'rdt.' + sUSER_sNAME()    
               FROM dbo.PackDetail PD  
               WHERE PD.RefNo IN (@cUCC, @cNewUCC)  
                  AND StorerKey = @cStorerKey  
                  AND SKU = @cSKU  
  
               SELECT @nError = @@ERROR, @nRowCount = @@ROWCOUNT                 
  
  
               IF @nError <> 0   
               BEGIN  
                  SET @nErrNo = 63662  
                  SET @cErrMsg = rdt.rdtgetmessage( 63662, @cLangCode,'DSP') --Upd PKDtl fail  
                  ROLLBACK TRAN  
                  GOTO Fail   
               END  
            END  
  
            --update Replenishment.RefNo  
            IF @cLOC = '' OR @cLOC IS NULL  
            BEGIN  
               UPDATE RP WITH (ROWLOCK) SET  
                  RP.RefNo =   
                     CASE WHEN RP.RefNo = @cUCC THEN @cNewUCC   
                          WHEN RP.RefNo = @cNewUCC THEN @cUCC END  
               FROM dbo.Replenishment RP  
               WHERE RP.RefNo IN (@cUCC, @cNewUCC)  
                  AND StorerKey = @cStorerKey  
                  AND SKU = @cSKU  
                  AND (RP.Confirmed = 'W' OR   
                      (RP.Confirmed = 'Y' AND DropID = '') OR   
                      (RP.Confirmed = 'Y' AND DropID = 'L') OR   
                      (RP.Confirmed = 'L' AND DropID = '') )  
  
               SELECT @nError = @@ERROR, @nRowCount = @@ROWCOUNT  
            END  
            ELSE  
            BEGIN  
               UPDATE RP WITH (ROWLOCK) SET  
                  RP.RefNo =   
                     CASE WHEN RP.RefNo = @cUCC THEN @cNewUCC   
                          WHEN RP.RefNo = @cNewUCC THEN @cUCC END  
               FROM dbo.Replenishment RP  
               WHERE RP.RefNo IN (@cUCC, @cNewUCC)  
                  AND StorerKey = @cStorerKey  
                  AND SKU = @cSKU  
                  AND FromLoc = @cLOC  
                  AND (RP.Confirmed = 'W' OR   
                      (RP.Confirmed = 'Y' AND DropID = '') OR   
                      (RP.Confirmed = 'Y' AND DropID = 'L') OR   
                      (RP.Confirmed = 'L' AND DropID = ''))  
  
  
               SELECT @nError = @@ERROR, @nRowCount = @@ROWCOUNT  
            END  
  
            IF @nError <> 0   
            BEGIN  
               SET @nErrNo = 63664  
               SET @cErrMsg = rdt.rdtgetmessage( 63664, @cLangCode,'DSP') --UpdReplenfail  
               ROLLBACK TRAN  
               GOTO Fail   
            END  
  
  
            --update new ucc.pickdetailkey and status  
            UPDATE UCC WITH (ROWLOCK) SET  
               UCC.Status =   
                  CASE WHEN UCC.Status = @cNewStatus THEN @cStatus  
                       WHEN UCC.Status = @cStatus THEN @cNewStatus END,  
               UCC.WaveKey =   
                  CASE WHEN UCC.WaveKey = @cNewWaveKey THEN @cWaveKey  
                       WHEN UCC.WaveKey = @cWaveKey THEN @cNewWaveKey END,   
               UCC.Userdefined01 =   
                  CASE WHEN UCC.Userdefined01 = @cNewLoadKey THEN @cLoadKey  
                       WHEN UCC.Userdefined01 = @cLoadKey THEN @cNewLoadKey END  
            FROM dbo.UCC UCC  
            WHERE UCC.UCCNo IN (@cUCC, @cNewUCC)  
               AND StorerKey = @cStorerKey  
               AND SKU = @cSKU  
  
            SELECT @nError = @@ERROR, @nRowCount = @@ROWCOUNT  
  
            IF @@ERROR <> 0   
            BEGIN  
               SET @nErrNo = 63668  
               SET @cErrMsg = rdt.rdtgetmessage( 63668, @cLangCode,'DSP') --UpdNewUCCfail  
               ROLLBACK TRAN  
               GOTO Fail   
            END  
  
                
            COMMIT TRAN  
         END  
      END -- Status  
  
   Fail:  
END  

GO
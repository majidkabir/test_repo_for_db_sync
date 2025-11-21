SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/******************************************************************************/  
/* Store procedure: rdt_UCCReceiveAudit_Confirm                               */  
/* Copyright      : LF Logistics                                              */  
/* Modifications log:                                                         */  
/*                                                                            */  
/* Date        Rev   Author      Purposes                                     */  
/* 10-Dec-2019  1.0  Chermaine   WMS-11357 - Created                          */  
/* 04-Aug-2020  1.2  Chermaine   Tuning                                       */  
/******************************************************************************/  
  
CREATE PROC [RDT].[rdt_UCCReceiveAudit_Confirm] (  
   @nMobile       INT,  
   @nFunc         INT,   
   @cLangCode     NVARCHAR( 3),  
   @cUserName     NVARCHAR( 15),   
   @cFacility     NVARCHAR( 5),   
   @cStorerKey    NVARCHAR( 15),   
   @cReceiptKey   NVARCHAR( 20),   
   @nMixSKU       INT,  
   @cUCCNo        NVARCHAR( 20),   
   @cSKU          NVARCHAR( 20),  
   @nQTY          INT,   
   @cType         NVARCHAR( 20) = '' ,  
   @nErrNo        INT           OUTPUT,   
   @cErrMsg       NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max   
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @nTranCount INT  
   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  -- Begin our own transaction  
   SAVE TRAN rdt_UCCReceiveAudit_Confirm -- For rollback or commit only our own transaction  
  
   -- Get info  
   DECLARE   
   @nRowRef    INT  
   ,@nPQTY     INT  
   ,@cPosition NVARCHAR ( 20)  
     
   SELECT TOP 1  
      @nRowRef = RowRef  
   FROM rdt.RDTReceiveAudit WITH (NOLOCK)  
   WHERE UCCNo = @cUCCNo  
      AND StorerKey = @cStorerKey  
      AND SKU = @cSKU  
        
   IF @cType ='Variance'  
   BEGIN  
    DECLARE @tMissingSKU TABLE (SKU  NVARCHAR( 30))  
      
    INSERT INTO @tMissingSKU (SKU)  
    SELECT SKU  
      FROM RECEIPTdetail  (NOLOCK)  
      WHERE StorerKey = @cStorerKey  
      AND userDefine01 = @cUCCNo  
      AND ReceiptKey = @cReceiptKey  
      EXCEPT  
      SELECT SKU  
      FROM rdt.RDTReceiveAudit (NOLOCK)  
      WHERE StorerKey = @cStorerKey  
      AND uccno = @cUCCNo  
      AND ReceiptKey = @cReceiptKey  
        
    --INSERT INTO traceInfo (tracename,col1)  
    --VALUES('ccAudit',@cMissingSKU)  
      
    INSERT INTO rdt.RDTReceiveAudit (ReceiptKey,UCCNo, StorerKey, SKU, cQty, PQty)   
      SELECT ReceiptKey,UserDefine01, StorerKey, RD.SKU,-SUM(QtyReceived),SUM(QtyReceived)  
      FROM RECEIPTdetail  RD (NOLOCK)  
      JOIN @tMissingSKU M ON RD.SKU =  M.SKU  
      WHERE StorerKey = @cStorerKey  
      AND userDefine01 = @cUCCNo  
      AND ReceiptKey = @cReceiptKey  
      GROUP BY ReceiptKey,UserDefine01, StorerKey, RD.SKU  
      --AND SKU = @cMissingSKU  
        
      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 147064  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS Log Fail  
         GOTO RollBackTran  
      END  
   END  
   ELSE  
   BEGIN  
   IF @nRowRef IS NULL  
   BEGIN  
      SELECT @nPQTY = SUM(QtyReceived)   
      FROM RECEIPTDETAIL (nolock)   
      WHERE Storerkey = @cStorerKey   
         AND receiptKey = @cReceiptKey  
         AND sku = @cSKU         
         AND userdefine01 = @cUCCNo  
       
      -- Get Position  
      IF @nMixSKU>1  
      BEGIN  
         IF EXISTS (SELECT TOP 1 1   
                     FROM CODELKUP C (NOLOCK)  
                        JOIN SKU S(NOLOCK)   
                     ON s.busr7 = c.Code  
                        AND s.StorerKey = c.Storerkey  
                     WHERE s.sku = @cSKU  
                        AND s.StorerKey = @cStorerKey  
                        AND c.listname = 'SDCPOSIT'  
                        AND c.UDF01 =1 )   
         BEGIN  
         DECLARE  
         @cLottable01      NVARCHAR( 30),  
         @cLoc             NVARCHAR( 30),  
         @cDeviceID        NVARCHAR( 30),  
         --@cDevicePosition  NVARCHAR( 30),  
         @cAuditPosition   NVARCHAR( 30),  
         @nShort           INT,  
         @nDeviceCount     INT,  
         @nPQTYMix         INT  
                
         SELECT @nPQTYMix = SUM(QtyReceived)  
         FROM (  
            SELECT userdefine01,COUNT(sku) AS mix  
            FROM RECEIPTDETAIL (NOLOCK)   
            WHERE Storerkey = @cStorerKey   
               AND receiptKey = @cReceiptKey   
            GROUP BY userdefine01  
            )aa  
         JOIN RECEIPTDETAIL r (NOLOCK)  
         ON aa.userdefine01 = r.UserDefine01  
         WHERE r.Storerkey = @cStorerKey   
         AND r.receiptKey = @cReceiptKey  
         AND r.sku = @cSKU  
         AND aa.mix > 1  
         GROUP BY r.sku  
    
         SELECT   
            @nShort = c.short,   
            @cDeviceID = UDF02  
         FROM CODELKUP C (NOLOCK)  
         JOIN SKU S(NOLOCK)   
         ON s.busr7 = c.Code  
            AND s.StorerKey = c.Storerkey  
         WHERE s.sku = @cSKU  
            AND s.StorerKey = @cStorerKey  
            AND c.listname = 'SDCPOSIT'  
                   
         SELECT @nDeviceCount = COUNT(devicePosition)  
         FROM DeviceProfile (NOLOCK)   
         WHERE deviceID =@cDeviceID  
                
         SELECT TOP 1 @cLottable01 = CASE WHEN Lottable01 = 'A' THEN '3' WHEN Lottable01 = 'B' THEN '4' END   
         FROM RECEIPTDetail (NOLOCK)   
         WHERE ReceiptKey = @cReceiptKey  
            AND StorerKey = @cStorerKey  
            AND SKU = @cSKU  
                          
      
         SELECT @cLoc = loc.PutawayZone+'-'+loc.LocAisle   
         FROM SKUXLOC s (NOLOCK)  
         --JOIN LOTXLOCXID l (NOLOCK)  
         --ON s.StorerKey=l.StorerKey  
         --   AND s.sku = l.Sku  
         --   AND s.loc = l.loc  
         --JOIN LOTATTRIBUTE lot (NOLOCK)   
         --ON lot.StorerKey=l.StorerKey  
         --   AND lot.sku = l.Sku  
         --   AND l.lot=lot.Lot  
         JOIN LOC  (NOLOCK)  
         ON loc.loc = s.loc  
         WHERE s.StorerKey = @cStorerKey  
            AND s.sku = @cSKU  
            AND s.locationtype='PICK'  
            --AND lot.Lottable01 = @cLottable01  
            AND loc.Facility = @cFacility   
            AND loc.LocationHandling = @cLottable01  
        
         IF @nPQTYMix > @nShort  
         BEGIN  
            IF @nDeviceCount < @nMixSKU  
            BEGIN  
               SET @nErrNo = 147073  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- LessPosition  
               GOTO RollBackTran  
            END  
            ELSE  
            BEGIN  
               SELECT @cAuditPosition = position   
               FROM rdt.RDTReceiveAudit (NOLOCK)   
               WHERE storerKey = @cStorerKey  
               AND receiptkey = @creceiptKey  
               AND sku = @cSku  
                  
               IF ISNULL(@cAuditPosition,'') = ''  
               BEGIN  
               SELECT   
                  TOP 1 @cPosition =  d.devicePosition  
               FROM (  
                  SELECT devicePosition  
                     FROM DeviceProfile (NOLOCK)   
                     WHERE deviceID = @cDeviceID  
                     EXCEPT  
                     SELECT position   
                     FROM rdt.RDTReceiveAudit (NOLOCK)  
                     WHERE ReceiptKey= @cReceiptKey  
                     )d  
               END  
               ELSE  
               BEGIN  
               SET @cPosition = @cAuditPosition  
               END              
                    
            END  
         END  
      
         IF @nPQTYMix <= @nShort  
         BEGIN  
         SET @cPosition = @cLoc  
         END  
         END  
      END  
     
      INSERT INTO rdt.RDTReceiveAudit (ReceiptKey,UCCNo, StorerKey, SKU, cQty, PQty, Position)  
      VALUES (@cReceiptKey,@cUCCNo, @cStorerKey, @cSKU, @nQTY, @nPQTY, @cPosition)  
      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 147064  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS Log Fail  
         GOTO RollBackTran  
      END  
   END  
      ELSE  
      BEGIN  
         -- Update  
         UPDATE rdt.RDTReceiveAudit WITH (ROWLOCK) SET  
            CQty = CQty + @nQTY  
         WHERE RowRef = @nRowRef  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 147065  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD Log Fail  
            GOTO RollBackTran  
         END  
      END  
   END  
   -- Insert   
     
     
   COMMIT TRAN rdt_UCCReceiveAudit_Confirm  
  
   -- EventLog  
   EXEC RDT.rdt_STD_EventLog  
      @cActionType   = '3', -- Picking  
      @cUserID       = @cUserName,  
      @nMobileNo     = @nMobile,  
      @nFunctionID   = @nFunc,  
      @cFacility     = @cFacility,  
      @cStorerKey    = @cStorerkey,  
      @cUCC          = @cUCCNo,  
      @cReceiptKey   = @cReceiptKey,  
      @cSKU          = @cSKU,   
      @nQTY          = @nQTY  
  
   GOTO Quit  
  
RollBackTran:  
   ROLLBACK TRAN rdt_UCCReceiveAudit_Confirm  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  
END  


GO
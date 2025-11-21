SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_CPVAdjustment_Confirm                           */  
/* Copyright      : LFLogistics                                         */  
/*                                                                      */  
/* Date        Rev  Author    Purposes                                  */  
/* 14-Sep-2018 1.0  Ung        WMS-6149 Created                         */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_CPVAdjustment_Confirm] (  
   @nMobile       INT,  
   @nFunc         INT,  
   @cLangCode     NVARCHAR( 3),  
   @nStep         INT,  
   @nInputKey     INT,  
   @cStorerKey    NVARCHAR( 15),   
   @cFacility     NVARCHAR( 5),   
   @cType         NVARCHAR( 10), -- PARENT/CHILD   
   @cADJKey       NVARCHAR( 10) = '',   
   @cParentSKU    NVARCHAR( 20) = '',   
   @nParentCaseCnt INT          = 0,   
   @cChildSKU     NVARCHAR( 20) = '',   
   @nChildCaseCnt INT           = 0,   
   @nChildQTY     INT           = 0,   
   @cLottable07   NVARCHAR( 30) = '',   
   @cLottable08   NVARCHAR( 30) = '',   
   @nParentQTY    INT           = 0  OUTPUT,   
   @cScan         NVARCHAR( 5)  = '' OUTPUT,   
   @cTotal        NVARCHAR( 5)  = '' OUTPUT,   
   @nErrNo        INT           = 0  OUTPUT,  
   @cErrMsg       NVARCHAR( 20) = '' OUTPUT  
) AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @nRowRef INT  
   DECLARE @dLottable04 DATETIME  
   DECLARE @dLottable05 DATETIME  
  
   -- Handling transaction  
   DECLARE @nTranCount INT  
   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  -- Begin our own transaction  
   SAVE TRAN rdtfnc_Confirm -- For rollback or commit only our own transaction  
  
   IF @cType = 'PARENT'  
   BEGIN  
      IF EXISTS( SELECT TOP 1 1   
         FROM rdt.rdtCPVAdjustmentLog WITH (NOLOCK)  
         WHERE Mobile = @nMobile  
            AND ADJKey = @cADJKey)  
      BEGIN  
         SELECT TOP 1 @nRowRef = RowRef FROM rdt.rdtCPVAdjustmentLog WITH (NOLOCK) WHERE Mobile = @nMobile AND ADJKey = @cADJKey  
         WHILE @@ROWCOUNT > 0  
         BEGIN  
            DELETE rdt.rdtCPVAdjustmentLog WHERE RowRef = @nRowRef  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 129351  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL LOG Fail  
               GOTO RollbackTran  
            END  
            SELECT TOP 1 @nRowRef = RowRef FROM rdt.rdtCPVAdjustmentLog WITH (NOLOCK) WHERE Mobile = @nMobile AND ADJKey = @cADJKey  
         END  
      END  
           
      INSERT INTO rdt.rdtCPVAdjustmentLog   
         (Mobile, ADJKey, Type, StorerKey, SKU, QTY, Lottable07, Lottable08)  
      VALUES  
         (@nMobile, @cADJKey, 'PARENT', @cStorerKey, @cParentSKU, 1, @cLottable07, @cLottable08)  
      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 129352  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS LOG Fail  
         GOTO RollbackTran  
      END  
        
      SET @nParentQTY = 1  
   END  
     
   IF @cType = 'CHILD'  
   BEGIN  
      -- Lookup child  
      SET @nRowRef = 0  
      SELECT @nRowRef = RowRef  
      FROM rdt.rdtCPVAdjustmentLog WITH (NOLOCK)  
      WHERE ADJKey = @cADJKey  
         AND StorerKey = @cStorerKey  
         AND SKU = @cChildSKU  
         AND Lottable07 = @cLottable07  
         AND Lottable08 = @cLottable08  
           
      IF @nRowRef = 0  
      BEGIN  
         INSERT INTO rdt.rdtCPVAdjustmentLog   
            (Mobile, ADJKey, Type, StorerKey, SKU, QTY, Lottable07, Lottable08)  
         VALUES  
            (@nMobile, @cADJKey, 'CHILD', @cStorerKey, @cChildSKU, @nChildQTY, @cLottable07, @cLottable08)  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 129353  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS LOG Fail  
            GOTO RollbackTran  
         END  
 END  
      ELSE  
      BEGIN  
         UPDATE rdt.rdtCPVAdjustmentLog SET  
            QTY = QTY + @nChildQTY,   
            EditWho = SUSER_SNAME(),   
            EditDate = GETDATE()  
         WHERE RowRef = @nRowRef  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 129354  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD LOG Fail  
            GOTO RollbackTran  
         END  
      END  
        
      SET @cScan = CAST( @cScan AS INT) + @nChildQTY  
   END  
     
   IF @cType = 'POSTING'  
   BEGIN  
      DECLARE @cADType       NVARCHAR( 10)  
      DECLARE @cSKU          NVARCHAR( 20)  
      DECLARE @cSerialNo     NVARCHAR( 50)  
      DECLARE @cADJLineNo    NVARCHAR( 5)  
      DECLARE @cNewADJLineNo NVARCHAR( 5)  
      DECLARE @cPackKey      NVARCHAR( 10)  
      DECLARE @cUOM          NVARCHAR( 10)  
      DECLARE @cReasonCode   NVARCHAR( 20)  
      DECLARE @cChildLOC     NVARCHAR( 10)  
      DECLARE @cParentL07    NVARCHAR( 30)  
      DECLARE @cParentL08    NVARCHAR( 30)  
      DECLARE @cMasterLOT    NVARCHAR( 60)  
      DECLARE @dExternL04    DATETIME  
      DECLARE @nQTY          INT        
      DECLARE @nGroupKey     BIGINT  
  
      SET @nGroupKey = 0  
      --SET @cChildLOC = 'CPV-STAGE'  
  
      -- Get adjustment info  
      -- (ChewKPXX) 
      SELECT TOP 1   
         @cReasonCode = UserDefine01   
      FROM Adjustment WITH (NOLOCK)   
      WHERE AdjustmentKey = @cADJKey  
      --ORDER BY AdjustmentLineNumber  
      
      
  
      -- Loop log  
      DECLARE @curLog CURSOR  
      SET @curLog = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR  
         SELECT RowRef, Type, SKU, QTY, Lottable07, Lottable08  
         FROM rdt.rdtCPVAdjustmentLog WITH (NOLOCK)   
         WHERE Mobile = @nMobile  
            AND ADJKey = @cADJKey  
         ORDER BY RowRef -- Parent come first, follow by child  
      OPEN @curLog   
      FETCH NEXT FROM @curLog INTO @nRowRef, @cADType, @cSKU, @nQTY, @cLottable07, @cLottable08  
      WHILE @@FETCH_STATUS = 0  
      BEGIN  
         -- Get parent info  
         IF @cADType = 'PARENT'   
         BEGIN   
            SET @cParentL07 = @cLottable07  
            SET @cParentL08 = @cLottable08   
  
            -- Get master LOT info  
            SET @cMasterLOT = @cParentL07 + @cParentL08  
            SELECT @dExternL04 = ExternLottable04  
            FROM ExternLotAttribute WITH (NOLOCK)  
            WHERE StorerKey = @cStorerKey  
               AND SKU = @cParentSKU  
               AND ExternLOT = @cMasterLOT  
         END  
           
         -- Get exact match  
         SET @cADJLineNo = ''  
         SELECT @cADJLineNo = AdjustmentLineNumber  
         FROM AdjustmentDetail WITH (NOLOCK)  
         WHERE AdjustmentKey = @cADJKey  
            AND StorerKey = @cStorerKey  
            AND SKU = @cSKU  
            AND Lottable07 = @cLottable07  
            AND Lottable08 = @cLottable08  
  
         -- Get blank line  
         IF @cADJLineNo = ''  
            SELECT @cADJLineNo = AdjustmentLineNumber  
            FROM AdjustmentDetail WITH (NOLOCK)  
            WHERE AdjustmentKey = @cADJKey  
               AND StorerKey = @cStorerKey  
               AND SKU = @cSKU  
               AND Lottable07 = ''  
               AND Lottable08 = ''  
      
         IF @cADJLineNo = ''  
         BEGIN  
            -- Get SKU info  
            SELECT   
               @cPackKey = Pack.PackKey,   
               @cUOM = PackUOM3, 
               @cChildLOC = ReceiptLoc
            FROM SKU WITH (NOLOCK)  
               JOIN Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)  
            WHERE StorerKey = @cStorerKey  
               AND SKU = @cSKU  
              
            -- Get new AdjustmentLineNumber  
            SELECT @cNewADJLineNo = RIGHT( '00000' + CAST( CAST( MAX( AdjustmentLineNumber) AS INT) + 1 AS NVARCHAR(5)), 5)  
            FROM AdjustmentDetail WITH (NOLOCK)  
            WHERE AdjustmentKey = @cADJKey  
  
            IF @cADType = 'PARENT'   
               INSERT INTO AdjustmentDetail (AdjustmentKey, AdjustmentLineNumber,   
                  StorerKey, SKU, LOT, ID, UOM, PackKey, Lottable07, Lottable08, ReasonCode, LOC, QTY)  
               SELECT @cADJKey, @cNewADJLineNo,   
                  @cStorerKey, @cSKU, '', '', @cUOM, @cPackKey, @cLottable07, @cLottable08, @cReasonCode,   
                  @cChildLOC,   
                  -@nQTY * @nParentCaseCnt  -- Negative QTY, for withdraw stock  
            ELSE  
               INSERT INTO AdjustmentDetail (AdjustmentKey, AdjustmentLineNumber,   
                  StorerKey, SKU, LOT, ID, UOM, PackKey, Lottable07, Lottable08, ReasonCode, LOC, QTY, Lottable04, Lottable09, Lottable10, UserDefine01)  
               SELECT @cADJKey, @cNewADJLineNo,   
                  @cStorerKey, @cSKU, '', '', @cUOM, @cPackKey, @cLottable07, @cLottable08, @cReasonCode,   
                  @cChildLOC,   
                  @nQTY * @nChildCaseCnt,   
                  @dExternL04,   
                  @cParentL07,   
                  @cParentL08,   
                  @cParentSKU  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 129355  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS ADDTL Fail  
               GOTO RollbackTran  
            END  
         END  
         ELSE  
         BEGIN  
            -- Update AdjustmentDetail  
            UPDATE AdjustmentDetail SET  
               QTY = QTY +   
                     CASE WHEN @cADType = 'PARENT'   
                        THEN -@nQTY * @nParentCaseCnt  
                        ELSE @nQTY * @nChildCaseCnt  
                     END,   
               Lottable04 = CASE WHEN @cADType = 'PARENT' THEN Lottable04 ELSE @dExternL04 END,   
               Lottable07 = @cLottable07,   
               Lottable08 = @cLottable08,   
               EditDate = GETDATE(),   
               EditWho = SUSER_SNAME()  
            WHERE AdjustmentKey = @cADJKey  
               AND AdjustmentLineNumber = @cADJLineNo  
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 129356  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD ADDTL Fail  
               GOTO RollbackTran  
            END  
         END  
  
         -- Delete rdtCPVAdjustmentLog  
         DELETE rdt.rdtCPVAdjustmentLog WHERE RowRef = @nRowRef  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 129357  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL ADLOG Fail  
            GOTO RollbackTran  
         END  
  
         FETCH NEXT FROM @curLog INTO @nRowRef, @cADType, @cSKU, @nQTY, @cLottable07, @cLottable08  
      END  
   END  
     
   COMMIT TRAN rdtfnc_Confirm -- Only commit change made here  
   GOTO Quit  
  
RollBackTran:  
   ROLLBACK TRAN rdtfnc_Confirm -- Only rollback change made here  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  
END  


GO
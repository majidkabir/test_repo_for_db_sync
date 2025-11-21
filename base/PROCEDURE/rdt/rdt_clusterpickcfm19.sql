SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_ClusterPickCfm19                                */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Purpose: Swapt Lot and Comfirm Pick                                  */    
/*                                                                      */    
/* Called from: rdtfnc_Cluster_Pick                                     */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date        Rev  Author      Purposes                                */    
/* 2021-05-31  1.0  James       WMS-16580. Created                      */   
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_ClusterPickCfm19] (    
   @nMobile                   INT,    
   @nFunc                     INT,    
   @cLangCode                 NVARCHAR( 3),    
   @nStep                     INT,    
   @nInputKey                 INT,    
   @cFacility                 NVARCHAR( 5),    
   @cStorerkey                NVARCHAR( 15),    
   @cWaveKey                  NVARCHAR( 10),    
   @cLoadKey                  NVARCHAR( 10),    
   @cOrderKey                 NVARCHAR( 10),    
   @cPutAwayZone              NVARCHAR( 10),    
   @cPickZone                 NVARCHAR( 10),    
   @cSKU                      NVARCHAR( 20),    
   @cPickSlipNo               NVARCHAR( 10),    
   @cLOT                      NVARCHAR( 10),    
   @cLOC                      NVARCHAR( 10),    
   @cDropID                   NVARCHAR( 20),    
   @cStatus                   NVARCHAR( 1),    
   @cCartonType               NVARCHAR( 10),    
   @nErrNo                    INT           OUTPUT,    
   @cErrMsg                   NVARCHAR( 20) OUTPUT    
)    
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
    
   DECLARE @bSuccess            INT,    
           @cPickDetailKey      NVARCHAR( 10),    
           @nPickQty            INT,    
           @nQTY_PD             INT,    
           @nRowRef             INT,    
           @nTranCount          INT,    
           @nPackQty            INT,    
           @nCartonNo           INT,    
           @cLabelNo            NVARCHAR( 20),    
           @cLabelLine          NVARCHAR( 5),    
           @cConsigneeKey       NVARCHAR( 15),    
           @cUOM                NVARCHAR( 10),     
           @cLoadDefaultPickMethod NVARCHAR( 1),      
           @nTotalPickedQty     INT,       
           @nTotalPackedQty     INT,       
           @nPickPackQty        INT,       
           @cRoute              NVARCHAR( 20),      
           @cOrderRefNo         NVARCHAR( 18),    
           @cUserName           NVARCHAR( 18),    
           @cClusterPickUpdLabelNoToCaseID   NVARCHAR( 1),    
           @cClusterPickGenLabelNo_SP        NVARCHAR( 1),    
           @cClusterPickInsPackDt            NVARCHAR( 1),    
           @cClusterPickAllowReuseDropID     NVARCHAR( 1),    
           @cClusterPickPromtOpenDropID      NVARCHAR( 1),    
           @cSQLStatement                    NVARCHAR(2000),    
           @cSQLParms                        NVARCHAR(2000)    
               
   DECLARE @cLottable02          NVARCHAR( 18)         
   DECLARE @cTargetOrderKey      NVARCHAR( 10)            
   DECLARE @cTargetLOC           NVARCHAR( 10)      
   DECLARE @cTargetID            NVARCHAR( 18)      
   DECLARE @cTargetLot           NVARCHAR( 10)      
   DECLARE @cTargetPickDetailKey NVARCHAR( 10)      
   DECLARE @cNewLOT              NVARCHAR( 10)    
   DECLARE @cNewID               NVARCHAR( 18)    
   DECLARE @cNewLoc              NVARCHAR( 10)    
   DECLARE @cCMD                 NVARCHAR( 1000)    
   DECLARE @cPortNo              NVARCHAR( 5)    
   DECLARE @cIPAddress           NVARCHAR( 20)    
   DECLARE @cLabelPrinter        NVARCHAR( 10)    
   DECLARE @cSpoolerGroup   NVARCHAR( 20)      
   DECLARE @cIniFilePath         NVARCHAR( 200)      
   DECLARE @cDataReceived        NVARCHAR( 4000)      
   DECLARE @nSwapLot             INT    
   DECLARE @nQueueID             INT    
   DECLARE @curPD                CURSOR    
   DECLARE @cClusterPickLockQtyToPick  NVARCHAR( 1)    
   DECLARE @cBarcode             NVARCHAR( 60)    
   DECLARE @cLottable03          NVARCHAR( 18)    
   DECLARE @ctest NVARCHAR( 10)    
   SET @nSwapLot = 1     
       
   IF @nStep = 9  -- Short pick no need swap lot    
      SET @nSwapLot = 0    
    
   SET @cClusterPickGenLabelNo_SP = rdt.RDTGetConfig( @nFunc, 'ClusterPickGenLabelNo_SP', @cStorerKey)     
   SET @cClusterPickUpdLabelNoToCaseID = rdt.RDTGetConfig( @nFunc, 'ClusterPickUpdLabelNoToCaseID', @cStorerKey)     
   SET @cClusterPickInsPackDt = rdt.RDTGetConfig( @nFunc, 'ClusterPickInsPackDt', @cStorerKey)     
   SET @cClusterPickAllowReuseDropID = rdt.RDTGetConfig( @nFunc, 'ClusterPickAllowReuseDropID', @cStorerKey)     
   SET @cClusterPickPromtOpenDropID = rdt.RDTGetConfig( @nFunc, 'ClusterPickPromtOpenDropID', @cStorerKey)     
   SET @cClusterPickLockQtyToPick = rdt.RDTGetConfig( @nFunc, 'ClusterPickLockQtyToPick', @cStorerKey)    
   IF @cClusterPickLockQtyToPick = '1'    
   BEGIN    
      SELECT @cUserName = UserName,     
             @cBarcode = I_Field04,    
             @cLabelPrinter = Printer    
      FROM RDT.RDTMOBREC WITH (NOLOCK)    
      WHERE Mobile = @nMobile    
    
      SET @cLottable02 = SUBSTRING( RTRIM( @cBarcode), 16, 12) -- Lottable02      
      SET @cLottable02 = RTRIM( @cLottable02) + '-' -- Lottable02      
      SET @cLottable02 = RTRIM( @cLottable02) + SUBSTRING( RTRIM( @cBarcode), 28, 2) -- Lottable02      
   END    
   ELSE    
      SELECT @cUserName = UserName,    
             @cLottable02 = V_Lottable02,    
             @cLabelPrinter = Printer    
      FROM RDT.RDTMOBREC WITH (NOLOCK)    
      WHERE Mobile = @nMobile    
    
   SELECT TOP 1 @cLottable03 = Lottable03       
   FROM dbo.OrderDetail WITH (NOLOCK)       
   WHERE StorerKey = @cStorerKey      
   AND   OrderKey = @cOrderkey      
   AND   SKU = @cSKU      
   ORDER BY 1    
       
   IF OBJECT_ID('tempdb..#ShortPickPickDetail') IS NOT NULL      
      DROP TABLE #ShortPickPickDetail    
    
   CREATE TABLE #ShortPickPickDetail  (      
      RowRef            BIGINT IDENTITY(1,1)  Primary Key,      
      PickDetailKey     NVARCHAR( 10))      
    
   SET @nTranCount = @@TRANCOUNT    
    
   BEGIN TRAN    
   SAVE TRAN rdt_ClusterPickCfm19    
    
   SELECT @cLoadKey = LoadKey, @cWaveKey = UserDefine09        -- ZG01  
   FROM dbo.Orders WITH (NOLOCK)    
   WHERE OrderKey = @cOrderKey    
    
   SELECT @cLoadDefaultPickMethod = LoadPickMethod     
   FROM dbo.LoadPlan WITH (NOLOCK)    
   WHERE LoadKey = @cLoadKey    
       
   SET @cPickSlipNo = ''      
   SELECT @cPickSlipNo = PickHeaderKey FROM PickHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey      
    
   IF @cPickSlipNo = ''      
      SELECT TOP 1 @cPickSlipNo = PickHeaderKey FROM PickHeader WITH (NOLOCK) WHERE ExternOrderKey = @cLoadkey      
    
   IF ISNULL( @cPickSlipNo, '') = ''    
   BEGIN    
      SET @nErrNo = 168951    
      SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode,'DSP') --PickSlip req    
      GOTO RollBackTran      
   END    
       
   IF ISNULL( @cLottable02, '') = ''       
   BEGIN      
      SET @nErrNo = 168952          
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Need Lottable02'          
      GOTO RollBackTran      
   END      
      
   IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)       
               WHERE StorerKey = @cStorerkey      
                   AND   OrderKey = @cOrderKey      
                   AND   SKU = @cSKU      
                   AND   [Status] < '9')      
   BEGIN      
      SET @nErrNo = 168953          
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SKU NOT IN ORD'          
      GOTO RollBackTran      
   END    
    
   -- If it is not Sales type order then no need swap lot. Check validity of 2D barcode      
   IF NOT EXISTS ( SELECT 1 FROM dbo.CODELKUP C WITH (NOLOCK)       
                   JOIN dbo.Orders O WITH (NOLOCK) ON (C.Code = O.Type AND C.StorerKey = O.StorerKey)      
                   WHERE C.ListName = 'HMORDTYPE'      
                   AND   C.Short = 'S'      
                   AND   O.OrderKey = @cOrderkey      
                   AND   O.StorerKey = @cStorerKey)      
   BEGIN      
      SET @nSwapLot = 0      
            
      -- SKU + Lottable02 must match pickdetail for this orders      
      IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK)       
                      JOIN dbo.LotAttribute LA WITH (NOLOCK) ON PD.LOT = LA.LOT      
                      WHERE PD.StorerKey = @cStorerkey      
                      AND   PD.OrderKey = @cOrderKey      
                      AND   PD.SKU = @cSKU      
                      AND   PD.Status < '9'      
                      AND   PD.QtyMoved < PD.QTY      
                      AND   LA.Lottable02 = @cLottable02)      
      BEGIN      
         SET @nErrNo = 168954          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'L02 Not Match'          
         GOTO RollBackTran      
      END       
   END      
    
   IF @nSwapLot = 1      
   BEGIN      
      SET @cTargetOrderKey = ''      
           
      INSERT TraceInfo (TraceName, TimeIn, Step1, Step2, Step3, Step4)
      VALUES ('PickCfm15_217', GETDATE(), @cOrderKey, @cLottable02, @cLottable03, SUSER_SNAME())

      -- 1.1 Exact match      
      SELECT TOP 1 @cTargetOrderKey = PD.OrderKey      
      FROM dbo.PickDetail PD WITH (NOLOCK)         
      JOIN dbo.LotAttribute LA WITH (NOLOCK) ON PD.LOT = LA.LOT        
      JOIN dbo.Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey      
      WHERE PD.StorerKey = @cStorerkey        
      AND   PD.SKU = @cSKU        
      AND   PD.Status < '9'        
      AND   PD.QtyMoved < PD.QTY        
      AND   LA.Lottable02 = @cLottable02     
      AND   LA.Lottable03 = @cLottable03    
      AND   O.OrderKey = @cOrderKey        
      
      INSERT TraceInfo (TraceName, TimeIn, Step1, Step2, Step3, Step4)
      VALUES ('PickCfm15_233', GETDATE(), @cTargetOrderKey, @cWaveKey, @cSKU, SUSER_SNAME())

      -- 2. Swap with other loadkey      
      IF ISNULL( @cTargetOrderKey, '') = ''      
      BEGIN      
         SELECT TOP 1       
            @cTargetOrderKey = PD.OrderKey,      
            @cTargetLOC =  PD.LOC,      
            @cTargetID = PD.ID,      
            @cTargetLot = PD.LOT,      
            @cTargetPickDetailKey = PD.PickDetailkey      
         FROM dbo.PickDetail PD WITH (NOLOCK)         
         JOIN dbo.LotAttribute LA WITH (NOLOCK) ON PD.LOT = LA.LOT        
         JOIN dbo.Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey      
         WHERE PD.StorerKey = @cStorerkey        
         AND   PD.SKU = @cSKU        
         AND   PD.Status < '9'        
         AND   PD.Qty = 1      
         AND   PD.QtyMoved < PD.QTY        
         AND   LA.Lottable02 = @cLottable02      
         AND   LA.Lottable03 = @cLottable03    
         --AND   O.LoadKey <> @cLoadKey         -- ZG01  
         AND   O.UserDefine09 <> @cWaveKey      -- ZG01  
         AND   PD.LOC IN (      
               SELECT DISTINCT PD.LOC      
               FROM dbo.PickDetail PD WITH (NOLOCK)         
               JOIN dbo.LotAttribute LA WITH (NOLOCK) ON PD.LOT = LA.LOT        
               JOIN dbo.Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey      
               WHERE PD.StorerKey = @cStorerkey        
               AND   PD.SKU = @cSKU        
               AND   PD.Status < '9'        
               AND   PD.QtyMoved < PD.QTY        
               --AND   O.LoadKey = @cLoadKey)         -- ZG01  
               AND   O.UserDefine09 = @cWaveKey)      -- ZG01  
         
         INSERT TraceInfo (TraceName, TimeIn, Step1, Step2, Step3, Step4, Step5, Col1)
         VALUES ('PickCfm15_269', GETDATE(), @cOrderKey, @cTargetOrderKey, @cTargetPickDetailKey, @cWaveKey, @cTargetLOC, @cTargetID)

         IF ISNULL(  @cTargetOrderKey, '') <> ''       
         BEGIN      
            SELECT TOP 1       
               @cLot = PD.LOT,      
               @cPickDetailKey = PD.PickDetailkey      
            FROM dbo.PickDetail PD WITH (NOLOCK)         
            JOIN dbo.LotAttribute LA WITH (NOLOCK) ON PD.LOT = LA.LOT        
            JOIN dbo.Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey      
            WHERE PD.StorerKey = @cStorerkey        
            AND   PD.SKU = @cSKU        
            AND   PD.Status < '9'        
            AND   PD.Qty = 1      
            AND   PD.QtyMoved < PD.QTY        
            AND   PD.LOC = @cTargetLOC      
            AND   PD.ID = @cTargetID      
            AND   O.OrderKey = @cOrderKey        
      
            INSERT TraceInfo (TraceName, TimeIn, Step1, Step2, Step3)
            VALUES ('PickCfm15_289', GETDATE(), @cOrderKey, @cPickDetailKey, @cLot)

            IF @cLot <> ''      
            BEGIN      
               -- Swap original lot         
               UPDATE PickDetail WITH (ROWLOCK) SET         
                  EditDate = GETDATE(),            
                  EditWho = 'rdt.' + sUser_sName(),       
                  Lot = @cTargetLot,         
                  QtyMoved = 1,         
                  Trafficcop = NULL        
               WHERE PickDetailKey = @cPickDetailKey        
           
               IF @@ERROR <> 0        
               BEGIN        
                  SET @nErrNo = 168955        
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Swap Lot Fail        
                  GOTO RollBackTran        
               END      
                                
               -- Swap target lot        
               UPDATE PickDetail WITH (ROWLOCK) SET         
                  EditDate = GETDATE(),            
                  EditWho = 'rdt.' + sUser_sName(),            
                  Lot = @cLot,         
                  Trafficcop = NULL        
               WHERE PickDetailKey = @cTargetPickDetailKey        
           
               IF @@ERROR <> 0        
               BEGIN        
                  SET @nErrNo = 168956        
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Swap Lot Fail        
                  GOTO RollBackTran        
               END    
    
               DECLARE curRPL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
               SELECT RowRef    
               FROM RDT.RDTPickLock WITH (NOLOCK)    
               WHERE StorerKey = @cStorerKey    
                  AND OrderKey = @cOrderKey    
                  AND SKU = @cSKU    
                  AND LOT = @cLOT    
                  AND LOC = @cLOC    
                  AND Status = '1'    
                  AND AddWho = @cUserName    
                  AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( PutAwayZone = @cPutAwayZone))    
                  AND (( ISNULL( @cPickZone, '') = '') OR ( PickZone = @cPickZone))    
               Order By RowRef    
               OPEN curRPL    
               FETCH NEXT FROM curRPL INTO @nRowRef    
               WHILE @@FETCH_STATUS <> -1    
               BEGIN    
                  UPDATE RDT.RDTPickLock SET LOT = @cTargetLot WHERE RowRef = @nRowRef    
    
                  IF @@ERROR <> 0        
                  BEGIN        
                     SET @nErrNo = 152031        
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd PickLot Er        
                     GOTO RollBackTran        
                  END    
                   
                  FETCH NEXT FROM curRPL INTO @nRowRef    
               END    
               CLOSE curRPL    
               DEALLOCATE curRPL    
                   
               SET @cLOT = @cTargetLot    
            END      
         END      
      END      
      ELSE            
      BEGIN      
         UPDATE TOP (1) dbo.PickDetail SET       
            QTYMoved = QTYMoved + 1      
         FROM dbo.PickDetail PD WITH (NOLOCK)       
            JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)      
         WHERE PD.StorerKey = @cStorerkey      
            AND PD.OrderKey = @cOrderKey      
            AND PD.SKU = @cSKU      
            AND PD.Status < '9'      
            AND PD.QtyMoved < PD.QTY      
            AND LA.Lottable02 = @cLottable02      
            AND LA.Lottable03 = @cLottable03    
      
         IF @@ERROR <> 0          
         BEGIN          
            SET @nErrNo = 168957          
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') ----'UPDPKDET Fail'       
            GOTO RollBackTran          
         END       
      END      
      
      INSERT TraceInfo (TraceName, TimeIn, Step1, Step2, Step3, Step4)
      VALUES ('PickCfm15_382', GETDATE(), @cTargetOrderKey, @cWaveKey, @cSKU, SUSER_SNAME())

      -- 3. Swap with available inventory         
      IF ISNULL( @cTargetOrderKey, '') = ''      
      BEGIN      
         SELECT TOP 1 @cNewLOT  = LLI.LOT, @cNewID = ID, @cNewLoc = LLI.LOC      
         FROM dbo.LotxLocxID LLI WITH (NOLOCK)         
         JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)        
         WHERE LLI.StorerKey = @cStorerkey        
         AND   LLI.SKU = @cSKU        
         AND  (LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked) > 0        
         AND   LA.Lottable02 = @cLottable02         
         AND   LA.Lottable03 = @cLottable03    
         AND LOC IN (      
            SELECT DISTINCT PD.LOC      
            FROM dbo.PickDetail PD WITH (NOLOCK)         
            JOIN dbo.LotAttribute LA WITH (NOLOCK) ON PD.LOT = LA.LOT          
            JOIN dbo.Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey                    
            WHERE PD.StorerKey = @cStorerkey        
            AND   PD.SKU = @cSKU        
            AND   PD.Status < '9'        
            AND   PD.QtyMoved < PD.QTY        
            --AND   O.LoadKey = @cLoadKey  )       -- ZG01  
            AND   O.UserDefine09 = @cWaveKey)      -- ZG01  
    
         IF @@ROWCOUNT = 0    
         BEGIN        
            SET @nErrNo = 152030        
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Lot To Swap        
            GOTO RollBackTran        
         END       
         
         INSERT TraceInfo (TraceName, TimeIn, Step1, Step2, Step3, Step4, Step5, Col1)
         VALUES ('PickCfm15_415', GETDATE(), @cTargetOrderKey, @cWaveKey, @cSKU, @cNewLoc, @cNewID, SUSER_SNAME())

         SELECT TOP 1       
            @cTargetOrderKey = PD.OrderKey,  -- only get the orderkey here to show swap successful      
            @cLot = PD.LOT,      
            @cPickDetailKey = PD.PickDetailkey      
         FROM dbo.PickDetail PD WITH (NOLOCK)         
         JOIN dbo.LotAttribute LA WITH (NOLOCK) ON PD.LOT = LA.LOT        
         JOIN dbo.Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey      
         WHERE PD.StorerKey = @cStorerkey        
         AND   PD.SKU = @cSKU        
         AND   PD.Status < '9'        
         AND   PD.Qty = 1      
         AND   PD.QtyMoved < PD.QTY        
         AND   PD.LOC = @cNewLoc      
         AND   PD.ID = @cNewID      
         --AND   O.LoadKey = @cLoadKey   
         AND   O.UserDefine09 = @cWaveKey          -- ZG01  
      
         INSERT TraceInfo (TraceName, TimeIn, Step1, Step2, Step3, Step4, Step5, Col1)
         VALUES ('PickCfm15_435', GETDATE(), @cTargetOrderKey, @cPickDetailKey, @cSKU, @cNewLoc, @cNewID, SUSER_SNAME())

         UPDATE dbo.PickDetail WITH (ROWLOCK) SET         
            EditDate = GETDATE(),            
            EditWho = 'rdt.' + sUser_sName(),            
            Lot = @cNewLOT,         
            ID = @cNewID,         
            QtyMoved = 1         
         WHERE PickDetailKey = @cPickDetailKey        
      
         IF @@ERROR <> 0        
            BEGIN        
            SET @nErrNo = 168958        
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Swap Lot Fail        
            GOTO RollBackTran        
         END       
    
         DECLARE curRPL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
         SELECT RowRef    
         FROM RDT.RDTPickLock WITH (NOLOCK)    
         WHERE StorerKey = @cStorerKey    
            AND OrderKey = @cOrderKey    
            AND SKU = @cSKU    
            AND LOT = @cLOT    
            AND LOC = @cLOC    
            AND Status = '1'    
            AND AddWho = @cUserName    
            AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( PutAwayZone = @cPutAwayZone))    
            AND (( ISNULL( @cPickZone, '') = '') OR ( PickZone = @cPickZone))    
         Order By RowRef    
         OPEN curRPL    
         FETCH NEXT FROM curRPL INTO @nRowRef    
         WHILE @@FETCH_STATUS <> -1    
       BEGIN    
            UPDATE RDT.RDTPickLock SET LOT = @cNewLOT WHERE RowRef = @nRowRef    
    
            IF @@ERROR <> 0        
            BEGIN        
               SET @nErrNo = 152032        
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd PickLot Er        
               GOTO RollBackTran        
            END    
                      
            FETCH NEXT FROM curRPL INTO @nRowRef    
         END    
         CLOSE curRPL    
         DEALLOCATE curRPL    
             
         SET @cLOT = @cNewLOT    
      END      
      
      IF ISNULL( @cTargetOrderKey, '') = ''      
      BEGIN        
         SET @nErrNo = 168959        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Swap Lot Fail        
         GOTO RollBackTran        
      END       
   END   -- End of @n_Swap = 1      
    
   SELECT @cUOM = RTRIM(PACK.PACKUOM3)    
   FROM dbo.PACK PACK WITH (NOLOCK)    
   JOIN dbo.SKU SKU WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)    
   WHERE SKU.Storerkey = @cStorerKey    
   AND   SKU.SKU = @cSKU    
    
   -- Get RDT.RDTPickLock candidate to offset    
   DECLARE curRPL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT RowRef, DropID, PickQty, ID    
   FROM RDT.RDTPickLock WITH (NOLOCK)    
   WHERE StorerKey = @cStorerKey    
      AND OrderKey = @cOrderKey    
      AND SKU = @cSKU    
      AND LOT = @cLOT    
      AND LOC = @cLOC    
      AND Status = '1'    
      AND AddWho = @cUserName    
      AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( PutAwayZone = @cPutAwayZone))    
      AND (( ISNULL( @cPickZone, '') = '') OR ( PickZone = @cPickZone))    
   Order By RowRef    
   OPEN curRPL    
   FETCH NEXT FROM curRPL INTO @nRowRef, @cDropID, @nPickQty, @nCartonNo    
   WHILE @@FETCH_STATUS <> -1    
   BEGIN    
      -- Get PickDetail candidate to offset based on RPL's candidate    
      DECLARE curPD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
      SELECT PickDetailKey, QTY    
      FROM dbo.PickDetail WITH (NOLOCK)    
      WHERE OrderKey  = @cOrderKey    
         AND StorerKey  = @cStorerKey    
         AND SKU = @cSKU    
         AND LOT = @cLOT    
         AND LOC = @cLOC    
         AND Status = '0'    
      ORDER BY PickDetailKey    
      OPEN curPD    
      FETCH NEXT FROM curPD INTO @cPickDetailKey, @nQTY_PD    
      WHILE @@FETCH_STATUS <> -1    
      BEGIN    
         SET @nPickPackQty = @nQTY_PD     
         SET @ctest = @cPickDetailKey    
         IF @nPickQty = 0    
         BEGIN    
            -- Confirm PickDetail    
            IF ISNULL(@cLoadDefaultPickMethod, '') = 'C' AND @cStatus = '4'    
            BEGIN    
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET    
                  EditWho = SUSER_SNAME(),    
                  EditDate = GETDATE(),    
                  DropID = '',    
                  Status = @cStatus    
               WHERE PickDetailKey = @cPickDetailKey    
               SET @nErrNo = @@ERROR    
            END    
            ELSE    
            BEGIN    
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET    
                  EditWho = SUSER_SNAME(),    
                  EditDate = GETDATE(),    
                  DropID = @cDropID,    
                  Status = @cStatus    
               WHERE PickDetailKey = @cPickDetailKey    
               SET @nErrNo = @@ERROR    
            END    
    
            IF @nErrNo <> 0    
            BEGIN    
               SET @nErrNo = 168600    
               SET @cErrMsg = rdt.rdtgetmessage( 66026, @cLangCode, 'DSP') --'OffSetPDtlFail'    
               GOTO RollBackTran    
            END    
            ELSE    
            BEGIN    
               INSERT INTO #ShortPickPickDetail(PickDetailKey) VALUES (@cPickDetailKey)    
               -- EventLog - QTY    
               EXEC RDT.rdt_STD_EventLog    
                 @cActionType   = '3', -- Picking    
                 @cUserID       = @cUserName,    
                 @nMobileNo     = @nMobile,    
                 @nFunctionID   = @nFunc,    
                 @cFacility     = @cFacility,    
                 @cStorerKey    = @cStorerkey,    
                 @cLocation     = @cLOC,    
                 @cID           = @cDropID,    
                 @cSKU          = @cSKU,    
                 @cUOM          = @cUOM,    
                 @nQTY          = 0,                     
                 @cLot          = @cLOT,    
                 @cRefNo1       = @cPutAwayZone,    
                 @cRefNo2       = @cPickZone,    
                 @cRefNo3       = @cOrderKey,    
                 @cRefNo4       = @cPickSlipNo    
            END    
         END    
         ELSE     
         -- Exact match    
         IF @nQTY_PD = @nPickQty    
         BEGIN    
            -- Confirm PickDetail    
            IF ISNULL(@cLoadDefaultPickMethod, '') = 'C' AND @cStatus = '4'    
            BEGIN    
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET    
                  EditWho = SUSER_SNAME(),    
                  EditDate = GETDATE(),    
                  DropID = '',    
                  Status = '5',  
                  QtyMoved = 1    
               WHERE PickDetailKey = @cPickDetailKey    
               SET @nErrNo = @@ERROR    
            END    
            ELSE    
            BEGIN    
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET    
                  EditWho = SUSER_SNAME(),    
                  EditDate = GETDATE(),    
                  DropID = @cDropID,    
                  Status = '5',  
                  QtyMoved = 1    
               WHERE PickDetailKey = @cPickDetailKey    
               SET @nErrNo = @@ERROR    
            END    
    
            IF @nErrNo <> 0    
            BEGIN    
               SET @nErrNo = 168601    
               SET @cErrMsg = rdt.rdtgetmessage( 66027, @cLangCode, 'DSP') --'OffSetPDtlFail'    
               GOTO RollBackTran    
            END    
            ELSE    
            BEGIN    
               -- EventLog - QTY    
               EXEC RDT.rdt_STD_EventLog    
                 @cActionType   = '3', -- Picking    
                 @cUserID       = @cUserName,    
                 @nMobileNo     = @nMobile,    
                 @nFunctionID   = @nFunc,    
                 @cFacility     = @cFacility,    
                 @cStorerKey    = @cStorerkey,    
                 @cLocation     = @cLOC,    
                 @cID           = @cDropID,    
                 @cSKU          = @cSKU,    
                 @cUOM          = @cUOM,    
                 @nQTY          = @nPickQty,    
                 @cLot          = @cLOT,    
                 @cRefNo1       = @cPutAwayZone,    
                 @cRefNo2       = @cPickZone,    
                 @cRefNo3       = @cOrderKey,    
                 @cRefNo4       = @cPickSlipNo    
            END    
            SET @nPickQty = @nPickQty - @nQTY_PD -- Reduce balance    
         END    
         -- PickDetail have less    
         ELSE IF @nQTY_PD < @nPickQty    
         BEGIN    
            -- Confirm PickDetail    
            IF ISNULL(@cLoadDefaultPickMethod, '') = 'C' AND @cStatus = '4'    
            BEGIN    
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET    
                  EditWho = SUSER_SNAME(),    
                  EditDate = GETDATE(),    
                  DropID = '',    
                  Status = '5',  
                  QtyMoved = 1      
               WHERE PickDetailKey = @cPickDetailKey    
               SET @nErrNo = @@ERROR    
               INSERT INTO #ShortPickPickDetail(PickDetailKey) VALUES (@cPickDetailKey)    
            END    
            ELSE    
            BEGIN    
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET    
                  EditWho = SUSER_SNAME(),    
                  EditDate = GETDATE(),    
                  DropID = @cDropID,    
                  Status = '5',  
                  QtyMoved = 1      
               WHERE PickDetailKey = @cPickDetailKey    
               SET @nErrNo = @@ERROR    
            END    
    
            IF @nErrNo <> 0    
            BEGIN    
               SET @nErrNo = 168602    
               SET @cErrMsg = rdt.rdtgetmessage( 66028, @cLangCode, 'DSP') --'OffSetPDtlFail'    
               GOTO RollBackTran    
            END    
            ELSE    
            BEGIN    
               EXEC RDT.rdt_STD_EventLog    
                 @cActionType   = '3', -- Picking    
                 @cUserID       = @cUserName,    
                 @nMobileNo     = @nMobile,    
                 @nFunctionID   = @nFunc,    
                 @cFacility     = @cFacility,    
                 @cStorerKey    = @cStorerkey,    
                 @cLocation     = @cLOC,    
                 @cID           = @cDropID,    
                 @cSKU          = @cSKU,    
                 @cUOM          = @cUOM,    
                 @nQTY          = @nQTY_PD,                     
                 @cLot          = @cLOT,    
                 @cRefNo1       = @cPutAwayZone,    
                 @cRefNo2       = @cPickZone,    
                 @cRefNo3       = @cOrderKey,    
                 @cRefNo4       = @cPickSlipNo    
            END    
    
            SET @nPickQty = @nPickQty - @nQTY_PD -- Reduce balance    
         END    
         -- PickDetail have more, need to split    
         ELSE IF @nQTY_PD > @nPickQty    
         BEGIN    
            IF @nPickQty > 0     
            BEGIN    
               -- If Status = '5' (full pick), split line if neccessary    
               -- If Status = '4' (short pick), no need to split line if already last RPL line to update,    
               -- just have to update the pickdetail.qty = short pick qty    
               -- Get new PickDetailkey    
               DECLARE @cNewPickDetailKey NVARCHAR( 10)    
               EXECUTE dbo.nspg_GetKey    
                  @KeyName       = 'PICKDETAILKEY',    
                  @fieldlength   = 10 ,    
                  @keystring     = @cNewPickDetailKey OUTPUT,    
                  @b_Success     = @bSuccess         OUTPUT,    
                  @n_err         = @nErrNo             OUTPUT,    
                  @c_errmsg      = @cErrMsg          OUTPUT    
    
               IF @bSuccess <> 1    
               BEGIN    
                  SET @nErrNo = 168603    
                  SET @cErrMsg = rdt.rdtgetmessage( 66029, @cLangCode, 'DSP') -- 'GetDetKeyFail'    
                  GOTO RollBackTran    
               END    
    
               IF ISNULL(@cLoadDefaultPickMethod, '') = 'C'    
               BEGIN    
                  -- Create a new PickDetail to hold the balance    
                  INSERT INTO dbo.PICKDETAIL (    
                     CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM, UOMQTY, QTYMoved,    
                     Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,    
                     DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, PickDetailKey,    
                     QTY,    
                     TrafficCop,    
                     OptimizeCop)    
                  SELECT    
                     CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM, UOMQTY, QTYMoved,    
                     '4', DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,    
                     DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, @cNewPickDetailKey,    
                     @nQTY_PD - @nPickQty, -- QTY    
                     NULL, --TrafficCop,    
                     '1'  --OptimizeCop    
                  FROM dbo.PickDetail WITH (NOLOCK)    
                  WHERE PickDetailKey = @cPickDetailKey    
                  SET @nErrNo = @@ERROR    
               END    
               ELSE    
               BEGIN    
                  -- Create a new PickDetail to hold the balance    
                  INSERT INTO dbo.PICKDETAIL (    
                     CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM, UOMQTY, QTYMoved,    
                     Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,    
                     DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, PickDetailKey,    
                     QTY,    
                     TrafficCop,    
                     OptimizeCop)    
                  SELECT    
                     CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM, UOMQTY, QTYMoved,    
                     '0', DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,    
                     DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, @cNewPickDetailKey,    
                     @nQTY_PD - @nPickQty, -- QTY    
                     NULL, --TrafficCop,    
                     '1'  --OptimizeCop    
                  FROM dbo.PickDetail WITH (NOLOCK)    
                  WHERE PickDetailKey = @cPickDetailKey    
                  SET @nErrNo = @@ERROR    
               END    
    
               IF @nErrNo <> 0    
               BEGIN    
                  SET @nErrNo = 168604    
                  SET @cErrMsg = rdt.rdtgetmessage( 66030, @cLangCode, 'DSP') --'Ins PDtl Fail'    
                  GOTO RollBackTran    
               END    
    
               -- Split RefKeyLookup (james14)    
               IF EXISTS( SELECT 1 FROM RefKeyLookup WITH (NOLOCK) WHERE PickDetailKey = @cPickDetailKey)    
               BEGIN    
                  -- Insert into    
                  INSERT INTO dbo.RefKeyLookup (PickDetailkey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey)    
                  SELECT @cNewPickDetailKey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey    
                  FROM RefKeyLookup WITH (NOLOCK)     
                  WHERE PickDetailKey = @cPickDetailKey    
    
                  IF @@ERROR <> 0    
                  BEGIN    
                     SET @nErrNo = 168605    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS RefKeyFail    
                     GOTO RollBackTran    
                  END    
               END    
    
               -- If short pick & no split line needed. Update pickdetail.qty with no trafficcop    
               -- Change orginal PickDetail with exact QTY (with TrafficCop)    
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET    
                  EditWho = SUSER_SNAME(),    
                  EditDate = GETDATE(),    
                  QTY = @nPickQty,    
                  Trafficcop = NULL    
               WHERE PickDetailKey = @cPickDetailKey    
    
               IF @@ERROR <> 0    
               BEGIN    
                  SET @nErrNo = 168606    
                  SET @cErrMsg = rdt.rdtgetmessage( 66031, @cLangCode, 'DSP') --'OffSetPDtlFail'    
                  GOTO RollBackTran    
               END    
    
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET    
                  EditWho = SUSER_SNAME(),    
                  EditDate = GETDATE(),    
                  DropID = @cDropID,    
                  Status = '5',  
                  QtyMoved = 1      
               WHERE PickDetailKey = @cPickDetailKey    
    
               IF @@ERROR <> 0    
               BEGIN    
                  SET @nErrNo = 168607    
                  SET @cErrMsg = rdt.rdtgetmessage( 66032, @cLangCode, 'DSP') --'OffSetPDtlFail'    
                  GOTO RollBackTran    
               END    
               ELSE    
               BEGIN    
                  EXEC RDT.rdt_STD_EventLog    
                    @cActionType   = '3', -- Picking    
                    @cUserID       = @cUserName,    
                    @nMobileNo     = @nMobile,    
                    @nFunctionID   = @nFunc,    
                    @cFacility     = @cFacility,    
                    @cStorerKey    = @cStorerkey,    
                    @cLocation     = @cLOC,    
                    @cID           = @cDropID,    
                    @cSKU          = @cSKU,    
                    @cUOM          = @cUOM,    
                    @nQTY          = @nPickQty,    
                    @cLot          = @cLOT,    
                    @cRefNo1       = @cPutAwayZone,    
                    @cRefNo2       = @cPickZone,    
                    @cRefNo3       = @cOrderKey,    
                    @cRefNo4       = @cPickSlipNo    
               END    
    
               SET @nPickPackQty = @nPickQty     
               SET @nPickQty = 0 -- Reduce balance      
            END    
         END    
    
         -- Get total qty that need to be packed    
         SELECT @nPackQty =  ISNULL(SUM(PickQty), 0)    
         FROM RDT.RDTPickLock WITH (NOLOCK)    
         WHERE StorerKey = @cStorerKey    
            AND OrderKey = @cOrderKey    
            AND SKU = @cSKU    
            AND LOT = @cLOT    
            AND LOC = @cLOC    
            AND Status = '1'    
            AND AddWho = @cUserName    
            AND DropID = @cDropID     
            AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( PutAwayZone = @cPutAwayZone))    
            AND (( ISNULL( @cPickZone, '') = '') OR ( PickZone = @cPickZone))    
          
         IF @cClusterPickInsPackDt = '1' AND @nPackQty > 0    
         BEGIN    
            SET @nPackQty = @nPickPackQty     
    
            IF @cLoadDefaultPickMethod = 'C'     
            BEGIN    
               -- Prevent overpacked     
               SET @nTotalPickedQty = 0     
               SELECT @nTotalPickedQty = ISNULL(SUM(PD.QTY), 0)     
               FROM dbo.PickDetail PD WITH (NOLOCK)    
               JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)    
               JOIN dbo.Orders O WITH (NOLOCK) ON OD.OrderKey = O.OrderKey    
               WHERE PD.StorerKey = @cStorerKey    
                  AND O.LoadKey = @cLoadKey    
                  AND PD.SKU = @cSKU    
                  AND PD.Status = '5'     
    
               SET @nTotalPackedQty = 0     
               SELECT @nTotalPackedQty = ISNULL(SUM(QTY), 0) FROM dbo.PackDetail WITH (NOLOCK)    
               WHERE StorerKey = @cStorerKey    
                  AND PickSlipNo = @cPickSlipNo    
                  AND SKU = @cSKU    
            END    
            ELSE    
            BEGIN    
               -- Prevent overpacked     
               SET @nTotalPickedQty = 0     
               SELECT @nTotalPickedQty = ISNULL(SUM(QTY), 0) FROM dbo.PickDetail WITH (NOLOCK)    
               WHERE StorerKey = @cStorerKey    
                  AND OrderKey = @cOrderKey    
                  AND SKU = @cSKU    
                  AND Status = '5'     
    
               SET @nTotalPackedQty = 0     
               SELECT @nTotalPackedQty = ISNULL(SUM(QTY), 0) FROM dbo.PackDetail WITH (NOLOCK)    
               WHERE StorerKey = @cStorerKey    
                  AND PickSlipNo = @cPickSlipNo    
                  AND SKU = @cSKU    
            END    
                
            IF (@nTotalPackedQty + @nPackQty) > @nTotalPickedQty     
            BEGIN    
               SET @nErrNo = 168608    
               SET @cErrMsg = rdt.rdtgetmessage( 66039, @cLangCode, 'DSP') --'SKU Overpacked'    
               GOTO RollBackTran    
            END    
    
            -- Insert Pack here    
            -- Same DropID + PickSlipNo will group SKU into a carton. 1 carton could be multi sku    
            IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)     
               WHERE StorerKey = @cStorerKey    
                  AND PickSlipNo = @cPickSlipNo    
                  AND DropID = @cDropID)    
            BEGIN    
               IF NOT EXISTS (SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE Pickslipno = @cPickSlipNo)    
               BEGIN    
                  SELECT @cRoute = [Route],     
                         @cOrderRefNo = SUBSTRING(ExternOrderKey, 1, 18),     
                         @cConsigneekey = ConsigneeKey     
                  FROM dbo.Orders WITH (NOLOCK)     
                  WHERE OrderKey = @cOrderKey    
                  AND   StorerKey = @cStorerKey    
       
                  INSERT INTO dbo.PackHeader    
                  (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo)    
                  VALUES    
                  (@cRoute, @cOrderKey, @cOrderRefNo, @cLoadKey, @cConsigneekey, @cStorerKey, @cPickSlipNo)    
    
                  IF @@ERROR <> 0    
                  BEGIN    
                     SET @nErrNo = 168609    
                     SET @cErrMsg = rdt.rdtgetmessage( 66040, @cLangCode, 'DSP') --'InsPHdrFail'    
                     GOTO RollBackTran    
                  END     
               END    
    
               SET @nCartonNo = 0    
    
               SET @cLabelNo = ''    
    
               IF @cClusterPickGenLabelNo_SP NOT IN ('', '0') AND     
                  EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cClusterPickGenLabelNo_SP AND type = 'P')    
               BEGIN    
                  SET @nErrNo = 0    
                  SET @cSQLStatement = 'EXEC rdt.' + RTRIM( @cClusterPickGenLabelNo_SP) +         
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, ' +     
                     ' @cWaveKey, @cLoadKey, @cOrderKey, @cPutAwayZone, @cPickZone, @cPickSlipNo, @cSKU, ' +     
                     ' @nQty, @cDropID, @cLabelNo OUTPUT, @nCartonNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '        
    
                  SET @cSQLParms =        
                     '@nMobile                   INT,           ' +    
                     '@nFunc                     INT,           ' +    
                     '@cLangCode                 NVARCHAR( 3),  ' +    
                     '@nStep                     INT,           ' +    
                     '@nInputKey                 INT,           ' +    
                     '@cFacility                 NVARCHAR( 5),  ' +    
                     '@cStorerkey                NVARCHAR( 15), ' +    
                     '@cWaveKey                  NVARCHAR( 10), ' +    
                     '@cLoadKey                  NVARCHAR( 10), ' +    
                     '@cOrderKey                 NVARCHAR( 10), ' +    
                     '@cPutAwayZone              NVARCHAR( 10), ' +    
                     '@cPickZone                 NVARCHAR( 10), ' +    
                     '@cPickSlipNo               NVARCHAR( 10), ' +    
                     '@cSKU                      NVARCHAR( 20), ' +    
                     '@nQty                      INT, ' +    
                     '@cDropID                   NVARCHAR( 20), ' +    
                     '@cLabelNo                  NVARCHAR( 20) OUTPUT, ' +    
                     '@nCartonNo                 INT           OUTPUT, ' +    
                     '@nErrNo                    INT           OUTPUT, ' +    
                     '@cErrMsg                   NVARCHAR( 20) OUTPUT  '     
                   
                  EXEC sp_ExecuteSQL @cSQLStatement, @cSQLParms,         
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey,     
                     @cWaveKey, @cLoadKey, @cOrderKey, @cPutAwayZone, @cPickZone, @cPickSlipNo, @cSKU,     
                     @nPackQty, @cDropID, @cLabelNo OUTPUT, @nCartonNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT     
               END    
               ELSE    
               BEGIN    
                  EXECUTE dbo.nsp_GenLabelNo    
                     @c_orderkey    = '',    
                     @c_storerkey   = @cStorerKey,    
                     @c_labelno     = @cLabelNo    OUTPUT,    
                     @n_cartonno    = @nCartonNo   OUTPUT,    
                     @c_button      = '',    
                     @b_success     = @bSuccess    OUTPUT,    
                     @n_err         = @nErrNo      OUTPUT,    
                     @c_errmsg      = @cErrMsg     OUTPUT    
               END    
    
               IF @bSuccess <> 1    
               BEGIN    
                  SET @nErrNo = 168610    
                  SET @cErrMsg = rdt.rdtgetmessage( 66038, @cLangCode, 'DSP') --'GenLabelFail'    
                  GOTO RollBackTran    
               END    
    
               INSERT INTO dbo.PackDetail    
                  (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, AddWho, AddDate, EditWho, EditDate, DropID)    
               VALUES    
                  (@cPickSlipNo, 0, @cLabelNo, '00000', @cStorerKey, @cSku, @nPackQty,    
                  @cPickDetailKey, 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), @cDropID)    
    
               IF @@ERROR <> 0    
               BEGIN    
                  SET @nErrNo = 168611    
                  SET @cErrMsg = rdt.rdtgetmessage( 66035, @cLangCode, 'DSP') --'InsPackDtlFail'    
                  GOTO RollBackTran    
               END     
            END -- DropID not exists    
            ELSE    
            BEGIN    
               IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)     
                  WHERE StorerKey = @cStorerKey    
                     AND PickSlipNo = @cPickSlipNo    
                     AND DropID = @cDropID    
                     AND SKU = @cSKU)    
               BEGIN    
                  SET @nCartonNo = 0    
    
                  SET @cLabelNo = ''    
    
                  SELECT @nCartonNo = CartonNo, @cLabelNo = LabelNo     
                  FROM dbo.PackDetail WITH (NOLOCK)    
                  WHERE Pickslipno = @cPickSlipNo    
                     AND StorerKey = @cStorerKey    
                     AND DropID = @cDropID    
    
                  SELECT @cLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)    
                  FROM dbo.PackDetail WITH (NOLOCK)    
                  WHERE Pickslipno = @cPickSlipNo    
                     AND CartonNo = @nCartonNo    
                     AND DropID = @cDropID    
    
                  INSERT INTO dbo.PackDetail    
                     (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, AddWho, AddDate, EditWho, EditDate, DropID)    
                  VALUES    
                     (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSku, @nPackQty,    
                     @cPickDetailKey, 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), @cDropID)    
    
                  IF @@ERROR <> 0    
                  BEGIN    
                     SET @nErrNo = 168612    
                     SET @cErrMsg = rdt.rdtgetmessage( 66036, @cLangCode, 'DSP') --'InsPackDtlFail'    
                     GOTO RollBackTran    
                  END     
               END   -- DropID exists but SKU not exists (insert new line with same cartonno)    
               ELSE    
               BEGIN    
                  UPDATE dbo.PackDetail WITH (ROWLOCK) SET    
                     QTY = QTY + @nPackQty,    
                     EditWho = SUSER_SNAME(),    
                     EditDate = GETDATE()    
                  WHERE StorerKey = @cStorerKey    
                     AND PickSlipNo = @cPickSlipNo    
                     AND DropID = @cDropID    
                     AND SKU = @cSKU    
    
                  IF @@ERROR <> 0    
                  BEGIN    
                     SET @nErrNo = 168613    
                     SET @cErrMsg = rdt.rdtgetmessage( 66037, @cLangCode, 'DSP') --'UpdPackDtlFail'    
                     GOTO RollBackTran    
                  END    
               END   -- DropID exists and SKU exists (update qty only)    
            END    
         END     
    
         IF NOT EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK)     
                        WHERE DropID = @cDropID) OR     
            -- If dropid not exists then need create new dropid.      
   -- If exists dropid then check if allow reuse dropid. If allow then go on.    
            @cClusterPickAllowReuseDropID = '1'    
         BEGIN    
            -- Insert into DropID table       
            IF @cClusterPickPromtOpenDropID = '1'     
            BEGIN    
               SET @nErrNo = 0      
               EXECUTE rdt.rdt_Cluster_Pick_DropID      
                  @nMobile,     
                  @nFunc,        
                  @cStorerKey,      
                  @cUserName,      
                  @cFacility,      
                  @cLoadKey,    
                  @cPickSlipNo,      
                  @cOrderKey,     
                  @cDropID       OUTPUT,      
                  @cSKU,      
                  'I',      -- I = Insert    
                  @cLangCode,      
                  @nErrNo        OUTPUT,      
                  @cErrMsg       OUTPUT  -- screen limitation, 20 NVARCHAR max      
      
               IF @nErrNo <> 0      
                  GOTO RollBackTran    
            END    
         END    
    
         IF @cClusterPickUpdLabelNoToCaseID = '1' AND ISNULL( @cLabelNo, '') <> ''     
         BEGIN    
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET     
               CaseID = @cLabelNo,    
               EditWho = SUSER_SNAME(),    
               EditDate = GETDATE()    
            WHERE PickDetailKey = @cPickDetailKey    
    
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 168614    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdCaseID Fail'    
               GOTO RollBackTran    
            END    
         END    

         -- (james03)
         DECLARE @cTempPickDetailKey   NVARCHAR( 10)
         SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR             
         SELECT PickDetailKey    
         FROM dbo.PickDetail WITH (NOLOCK)    
         WHERE OrderKey  = @cOrderKey    
         AND   StorerKey  = @cStorerKey    
         AND   SKU = @cSKU    
         AND   Status = '0'
         AND   QtyMoved > 0    
         ORDER BY PickDetailKey    
         OPEN @curPD    
         FETCH NEXT FROM @curPD INTO @cTempPickDetailKey    
         WHILE @@FETCH_STATUS <> -1    
         BEGIN    
            UPDATE dbo.PickDetail SET 
               QtyMoved = 0, 
               TrafficCop = NULL
            WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 168624    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPickDtlFail'    
               GOTO RollBackTran    
            END    
            
            FETCH NEXT FROM @curPD INTO @cTempPickDetailKey
         END

         IF @nPickQty = 0     
         BEGIN    
            BREAK -- Exit       
         END    
    
         FETCH NEXT FROM curPD INTO @cPickDetailKey, @nQTY_PD    
      END    
      CLOSE curPD    
      DEALLOCATE curPD    
    
      -- Call backend process to perform unallocation    
      IF @cStatus = '4'    
      BEGIN    
         SELECT TOP 1 @cOrderKey = PD.OrderKey,     
                      @cLOC = PD.Loc,     
                      @cSKU = PD.Sku    
         FROM #ShortPickPickDetail SPD     
         JOIN dbo.PICKDETAIL PD WITH (NOLOCK) ON ( SPD.PickDetailKey = PD.PickDetailKey)    
         ORDER BY 1    
    
         SET @curPD = CURSOR FOR    
         SELECT PickDetailKey    
         FROM dbo.PICKDETAIL WITH (NOLOCK)    
         WHERE OrderKey = @cOrderKey    
         AND   LOC = @cLOC    
         AND   Sku = @cSKU    
         AND   [Status] < '4'    
         OPEN @curPD    
         FETCH NEXT FROM @curPD INTO @cPickDetailKey    
         WHILE @@FETCH_STATUS = 0    
         BEGIN    
            UPDATE dbo.PickDetail SET     
               [Status] = '4',    
               EditWho = SUSER_SNAME(),    
               EditDate = GETDATE()    
            WHERE PickDetailKey = @cPickDetailKey    
    
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 168616    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OffSetPDtlFail'    
               GOTO RollBackTran    
            END    
                
            INSERT INTO #ShortPickPickDetail(PickDetailKey) VALUES (@cPickDetailKey)    
    
            FETCH NEXT FROM @curPD INTO @cPickDetailKey    
         END    
         CLOSE @curPD    
         DEALLOCATE @curPD    
                     
         -- Get spooler info      
         SELECT      
            @cIPAddress = [IP],      
            @cPortNo = [PORT],      
            @cIniFilePath = IniFilePath      
         FROM   QCmd_TransmitlogConfig WITH (NOLOCK)      
         WHERE  TableName = 'ShortPickHold'      
         AND   [App_Name] = 'WMS'      
         AND    StorerKey = 'ALL'      
    
         -- Check valid      
         IF @@ROWCOUNT = 0 OR @cIPAddress = '' OR @cPortNo = ''      
         BEGIN      
            SET @nErrNo = 168617      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SpoolNot Setup      
            GOTO RollBackTran      
         END     
          
         SET @curPD = CURSOR FOR    
         SELECT PD.OrderKey, PD.Loc, PD.Sku, SPD.PickDetailKey    
         FROM #ShortPickPickDetail SPD     
         JOIN dbo.PICKDETAIL PD WITH (NOLOCK) ON ( SPD.PickDetailKey = PD.PickDetailKey)    
         OPEN @curPD    
         FETCH NEXT FROM @curPD INTO @cOrderKey, @cLOC, @cSKU, @cPickDetailKey    
         WHILE @@FETCH_STATUS = 0    
         BEGIN    
            -- Insert backend unallocate process here    
            SET @nErrNo = 0    
            EXEC [RDT].[rdt_ShortPickHold]     
               @nMobile          = @nMobile,    
               @nFunc            = @nFunc,    
               @cLangCode        = @cLangCode,    
               @cStorerKey       = @cStorerKey,    
               @cFacility        = @cFacility,    
               @cOrderkey        = @cOrderKey,    
               @cLOC             = @cLOC,    
               @cSKU             = @cSKU,    
               @nQty             = 0,    
               @cPickDetailKey   = @cPickDetailKey,    
               @nErrNo           = @nErrNo      OUTPUT,    
               @cErrMsg          = @cErrMsg     OUTPUT    
                   
            IF @nErrNo <> 0    
               GOTO RollBackTran    
    
            FETCH NEXT FROM @curPD INTO @cOrderKey, @cLOC, @cSKU, @cPickDetailKey    
         END    
      END    
    
      -- Stamp RPL's candidate to '5'    
      UPDATE RDT.RDTPickLock WITH (ROWLOCK) SET          
         Status = '5'   -- Picked    
      WHERE RowRef = @nRowRef    
    
      IF @@ERROR <> 0    
      BEGIN    
         SET @nErrNo = 168615    
         SET @cErrMsg = rdt.rdtgetmessage( 66033, @cLangCode, 'DSP') --'UPDPKLockFail'    
         GOTO RollBackTran    
      END    
    
      FETCH NEXT FROM curRPL INTO @nRowRef, @cDropID, @nPickQty, @nCartonNo    
   END    
   CLOSE curRPL    
   DEALLOCATE curRPL    

   -- (james03)
   SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR             
   SELECT PickDetailKey    
   FROM dbo.PickDetail WITH (NOLOCK)    
   WHERE OrderKey  = @cOrderKey    
   AND   StorerKey  = @cStorerKey    
   AND   QtyMoved > 0    
   ORDER BY PickDetailKey    
   OPEN @curPD    
   FETCH NEXT FROM @curPD INTO @cTempPickDetailKey    
   WHILE @@FETCH_STATUS <> -1    
   BEGIN    
      UPDATE dbo.PickDetail SET 
         QtyMoved = 0, 
         TrafficCop = NULL
      WHERE PickDetailKey = @cPickDetailKey

      IF @@ERROR <> 0    
      BEGIN    
         SET @nErrNo = 168625    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPickDtlFail'    
         GOTO RollBackTran    
      END    
            
      FETCH NEXT FROM @curPD INTO @cTempPickDetailKey
   END
       
   GOTO Quit    
    
   RollBackTran:    
      ROLLBACK TRAN rdt_ClusterPickCfm19    
    
   Quit:    
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
         COMMIT TRAN rdt_ClusterPickCfm19    
END    

GO
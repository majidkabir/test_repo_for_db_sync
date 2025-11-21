SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
 
/******************************************************************************/  
/* Store procedure: rdt_PTLCart_Assign_WaveTotes01                             */  
/* Copyright      : LFLogistics                                               */  
/*                                                                            */  
/* Date       Rev  Author   Purposes                                          */  
/* 10-05-2023 1.0  YeeKung  WMS-22211 Created                                 */  
/******************************************************************************/  
  
CREATE    PROC [RDT].[rdt_PTLCart_Assign_WaveTotes01] (  
   @nMobile          INT,  
   @nFunc            INT,  
   @cLangCode        NVARCHAR( 3),  
   @nStep            INT,  
   @nInputKey        INT,  
   @cFacility        NVARCHAR( 5),  
   @cStorerKey       NVARCHAR( 15),  
   @cCartID          NVARCHAR( 10),  
   @cPickZone        NVARCHAR( 10),  
   @cMethod          NVARCHAR( 1),  
   @cPickSeq         NVARCHAR( 1),  
   @cDPLKey          NVARCHAR( 10),  
   @cType            NVARCHAR( 15), --POPULATE-IN/POPULATE-OUT/CHECK  
   @cInField01       NVARCHAR( 60) OUTPUT,  @cOutField01 NVARCHAR( 60) OUTPUT,  @cFieldAttr01 NVARCHAR( 1) OUTPUT,  
   @cInField02       NVARCHAR( 60) OUTPUT,  @cOutField02 NVARCHAR( 60) OUTPUT,  @cFieldAttr02 NVARCHAR( 1) OUTPUT,  
   @cInField03       NVARCHAR( 60) OUTPUT,  @cOutField03 NVARCHAR( 60) OUTPUT,  @cFieldAttr03 NVARCHAR( 1) OUTPUT,  
   @cInField04       NVARCHAR( 60) OUTPUT,  @cOutField04 NVARCHAR( 60) OUTPUT,  @cFieldAttr04 NVARCHAR( 1) OUTPUT,  
   @cInField05       NVARCHAR( 60) OUTPUT,  @cOutField05 NVARCHAR( 60) OUTPUT,  @cFieldAttr05 NVARCHAR( 1) OUTPUT,  
   @cInField06       NVARCHAR( 60) OUTPUT,  @cOutField06 NVARCHAR( 60) OUTPUT,  @cFieldAttr06 NVARCHAR( 1) OUTPUT,  
   @cInField07       NVARCHAR( 60) OUTPUT,  @cOutField07 NVARCHAR( 60) OUTPUT,  @cFieldAttr07 NVARCHAR( 1) OUTPUT,  
   @cInField08       NVARCHAR( 60) OUTPUT,  @cOutField08 NVARCHAR( 60) OUTPUT,  @cFieldAttr08 NVARCHAR( 1) OUTPUT,  
   @cInField09       NVARCHAR( 60) OUTPUT,  @cOutField09 NVARCHAR( 60) OUTPUT,  @cFieldAttr09 NVARCHAR( 1) OUTPUT,  
   @cInField10       NVARCHAR( 60) OUTPUT,  @cOutField10 NVARCHAR( 60) OUTPUT,  @cFieldAttr10 NVARCHAR( 1) OUTPUT,  
   @cInField11       NVARCHAR( 60) OUTPUT,  @cOutField11 NVARCHAR( 60) OUTPUT,  @cFieldAttr11 NVARCHAR( 1) OUTPUT,  
   @cInField12       NVARCHAR( 60) OUTPUT,  @cOutField12 NVARCHAR( 60) OUTPUT,  @cFieldAttr12 NVARCHAR( 1) OUTPUT,  
   @cInField13       NVARCHAR( 60) OUTPUT,  @cOutField13 NVARCHAR( 60) OUTPUT,  @cFieldAttr13 NVARCHAR( 1) OUTPUT,  
   @cInField14       NVARCHAR( 60) OUTPUT,  @cOutField14 NVARCHAR( 60) OUTPUT,  @cFieldAttr14 NVARCHAR( 1) OUTPUT,  
   @cInField15       NVARCHAR( 60) OUTPUT,  @cOutField15 NVARCHAR( 60) OUTPUT,  @cFieldAttr15 NVARCHAR( 1) OUTPUT,  
   @nScn             INT           OUTPUT,  
   @nErrNo           INT           OUTPUT,  
   @cErrMsg          NVARCHAR( 20) OUTPUT  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @cWavePK              NVARCHAR(20)  
   DECLARE @nTotalOrder          INT  
   DECLARE @nTotalTote           INT  
   DECLARE @cDefaultToteIDAsPos  NVARCHAR(20)  
   DECLARE @cWavekey             NVARCHAR(20)  
   DECLARE @cCaseID              NVARCHAR(20)  
   DECLARE @cOrderKey            NVARCHAR(10)  
   DECLARE @cToteID              NVARCHAR(20)  
   DECLARE @nStorerQty           INT  
   DECLARE @nTranCount           INT  
   DECLARE @cPosition            NVARCHAR(20)  
   DECLARE @cIPAddress           NVARCHAR(20)  
  
   DECLARE @cErrMsg1 NVARCHAR(20),  
           @cErrMsg2 NVARCHAR(20)  
  
   SET @nTranCount = @@TRANCOUNT  
  
    /***********************************************************************************************  
                             POPULATE  
   ***********************************************************************************************/  
   IF @cType = 'POPULATE-IN'  
   BEGIN  
      -- Prepare next screen var  
      SET @cOutField01 = @cCartID  
      SET @cOutField02 = @cPickZone  
      SET @cOutField03 = @cWavePK  
      SET @cOutField04 = '' -- OrderKey  
      SET @cOutField05 = '' -- OrderKey  
  
      IF ISNULL(@cWavePK,'') = ''  
      BEGIN  
         -- Enable disable field  
         SET @cFieldAttr03 = ''  -- wavePK  
         SET @cFieldAttr05 = 'O' -- ToteID  
         EXEC rdt.rdtSetFocusField @nMobile, 3 -- wavePK  
      END  
      ELSE  
      BEGIN  
         -- Enable disable field  
         SET @cFieldAttr03 = 'O'  -- wavePK  
         SET @cFieldAttr05 = ' ' -- ToteID  
      END  
  
      -- Go to batch totes screen  
      SET @nScn = 5043  
      GOTO QUIT  
   END  
  
   IF @cType = 'POPULATE-OUT'  
   BEGIN  

  
      -- Enable field  
      SET @cFieldAttr03 = '' -- wavepk  
      SET @cFieldAttr04 = '' -- wavepk  
      SET @cFieldAttr05 = ' ' -- ToteID  
      GOTO QUIT  
  -- Go to cart screen  
   END  
  
   /***********************************************************************************************  
                                                 CHECK  
   ***********************************************************************************************/  
   IF @cType = 'CHECK'  
   BEGIN  
      DECLARE @cCheckBatchUsed NVARCHAR( 1)  
      DECLARE @cMultiPickerBatch NVARCHAR( 1)  
      DECLARE @cPickConfirmStatus NVARCHAR( 1)  
      DECLARE @cLOC NVARCHAR(10)  
      DECLARE @cSKU NVARCHAR(20)  
      DECLARE @nQTY INT  
      DECLARE @curPD CURSOR  
      declare @CcOrderkey NVARCHAR(20)  
      DECLARE @cUSername NVARCHAR(20)  
  
      -- Get storer config  
  
      -- Screen mapping  
      SET @cWavePK = CASE WHEN @cFieldAttr03 = '' THEN @cInField03 ELSE @cOutField03 END  
      SET @cToteID   = CASE WHEN @cFieldAttr05 = '' THEN @cInField05 ELSE @cOutField05 END  
  
      SELECT @cUSername = username  
      From rdt.rdtmobrec (nolock)  
      where mobile = @nMobile  
  
  
      SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)  
      IF @cPickConfirmStatus = '0'  
         SET @cPickConfirmStatus = '5'  
  
       -- WAVEPK field enabled  
      IF @cFieldAttr03 = ''  
      BEGIN  
         -- Check blank  
         IF @cWavePK = ''  
         BEGIN  
            SET @nErrNo = 201501  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need BatchKey  
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- BatchKey  
            GOTO Quit  
         END  
  
         SET @cWavekey = SUBSTRING(@cWavePK,1,10)  
         SET @cCaseID = SUBSTRING(@cWavePK,11,10)  
  
         IF NOT EXISTS( Select 1 From Pickdetail  PD JOIN WAVEDETAIL WD ON WD.OrderKey=PD.OrderKey Where PD.DropID = '' and WD.WaveKey = @cWavekey AND CASEID=@cCaseID)  
         BEGIN  
            SET @nErrNo = 201502  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Batch Assigned  
          SET @cErrMsg1 = 'WavekeyPK '  
            SET @cErrMsg2 = 'NotFound'  
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '156102', @cErrMsg1,@cErrMsg2  
            SET @cOutField03 = ''  
            GOTO Quit  
         END  
  
         IF EXISTS( Select 1 From Pickdetail  PD JOIN WAVEDETAIL WD  ON WD.OrderKey=PD.OrderKey Where PD.DropID <> ''  AND PD.caseid =@cCaseID and WD.WaveKey = @cWavekey)  
            AND Exists (Select 1 From Pickdetail  PD JOIN WAVEDETAIL WD ON WD.OrderKey=PD.OrderKey Where PD.DropID = ''  AND PD.caseid =@cCaseID and WD.WaveKey = @cWavekey)  
         BEGIN  
            SET @nErrNo = 201503  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Batch Assigned  
            SET @cErrMsg1 = 'Partial Assigned'  
            SET @cErrMsg2 = 'WavePK'  
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '156103', @cErrMsg1,@cErrMsg2  
            SET @cOutField03 = ''  
            GOTO Quit  
         END  
  
         IF NOT EXISTS (Select 1 From Pickdetail  PD  Where PD.DropID = '' and PD.WaveKey = @cWavekey AND PD.caseid =@cCaseID)  
         BEGIN  
            SET @nErrNo = 201504  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Batch Assigned  
            SET @cErrMsg1 = 'ToteId fully '  
            SET @cErrMsg2 = 'assigned'  
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '156103', @cErrMsg1,@cErrMsg2  
            SET @cOutField03 = ''  
            GOTO Quit  
         END  

           
  
         IF EXISTS (SELECT 1 from packheader PH(NOLOCK)  
                     JOIN pickdetail pdo (nolock) ON pdo.OrderKey=ph.OrderKey  
                     JOIN PackDetail pd (NOLOCK) ON pd.PickSlipNo=ph.PickSlipNo and pdo.sku=pd.sku  
                     WHERE pd.Qty>0  
                        and pdo.wavekey= @cWavekey  
                        and pdo.CaseID=@cCaseID  
                        and pd.storerkey=@cStorerKey)  
         BEGIN  
            SET @nErrNo = 201505  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Batch Assigned  
            SET @cErrMsg1 = 'Pack Started'  
            SET @cErrMsg2 = 'already'  
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '201505', @cErrMsg1,@cErrMsg2  
            SET @cOutField03 = ''  
            GOTO Quit  
         END  

         IF EXISTS (select 1 FROM rdt.rdtPTLCartLog WITH (NOLOCK)  
                        WHERE CartID = @cCartID  
                           AND wavekey = @cWavekey  
                           AND addwho <> @cUSername)  
         BEGIN  
            SET @nErrNo = 201516 
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --WavePKInUSed 
            SET @cErrMsg1 = 'Pack Started'  
            SET @cErrMsg2 = 'already'  
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '201516', @cErrMsg1,@cErrMsg2  
            SET @cOutField03 = ''  
            GOTO Quit
         END  
  
  
         IF EXISTS (select 1 FROM rdt.rdtPTLCartLog WITH (NOLOCK)  
                     WHERE CartID = @cCartID  
                        AND wavekey = @cWavekey  
                        AND addwho = @cUSername)  
         BEGIN  
            IF NOT EXISTS (select 1 FROM rdt.rdtPTLCartLog WITH (NOLOCK)  
                        WHERE CartID = @cCartID  
                           AND wavekey = @cWavekey  
                           and ToteID = ''  
                           AND addwho = @cUSername)  
  
            BEGIN  
               GOTO Quit  
            END 
            
            SET @cOutField03=@cWavepk  
            SET @cOutField04 = 0  
            SET @cFieldAttr03='O'  
            SET @cFieldAttr05=''  
            SET @nErrNo='-1'  
            GOTO QUIT  
         END  

  
         BEGIN TRAN  
         SAVE TRAN rdt_PTLCart_Assign_WaveTotes01  
  
         DECLARE @curWave CURSOR  
         SET @curWave = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT ORDERKEY  
         from pickdetail pdo (nolock)  
         WHERE  pdo.wavekey= @cWavekey  
            and pdo.CaseID=@cCaseID  
            and pdo.storerkey=@cStorerKey  
         GROUP BY ORDERKEY  
  
         OPEN @curWave  
         FETCH NEXT FROM @curWave INTO @CcOrderkey  
         WHILE @@FETCH_STATUS = 0  
         BEGIN  
            -- Get position not yet assign  
            SET @cPosition = ''  
            SELECT TOP 1  
               @cPosition = DP.DevicePosition  
            FROM dbo.DeviceProfile DP WITH (NOLOCK)  
            WHERE DP.DeviceType = 'CART'  
               AND DP.DeviceID = @cCartID  
               AND NOT EXISTS( SELECT 1  
                  FROM rdt.rdtPTLCartLog PCLog WITH (NOLOCK)  
                  WHERE CartID = @cCartID  
                     AND PCLog.Position = DP.DevicePosition)  
            ORDER BY DP.DevicePosition  
  
            -- Check position blank  
            IF @cPosition = ''  
            BEGIN  
               SET @nErrNo = 201506  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoMorePosition  
               GOTO RollBackTran  
            END  
  
            -- Save assign  
            INSERT INTO rdt.rdtPTLCartLog (CartID, Position, ToteID, DeviceProfileLogKey, Method, PickZone, PickSeq, wavekey, CaseID, StorerKey,Orderkey)  
            VALUES (@cCartID, @cPosition, '', '', @cMethod, @cPickZone, @cPickSeq, @cWavekey, @cCaseID, @cStorerKey,@CcOrderkey)  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 201507  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log Fail  
               GOTO RollBackTran  
            END  
            FETCH NEXT FROM @curWave INTO @CcOrderkey  
         END  
  
         SET @cOutField03=@cWavepk  
         SET @cOutField04 = 0  
         SET @cFieldAttr03='O'  
         SET @cFieldAttr05=''  
         SET @nErrNo='-1'  
         GOTO QUIT  
  
      END  
  
      IF @cFieldAttr05=''  
      BEGIN  
  
         SET @cWavekey = SUBSTRING(@cWavePK,1,10)  
         SET @cCaseID = SUBSTRING(@cWavePK,11,10)  
  
         SET @nTotalTote = CAST (@cOutField04 AS INT)  
  
          -- Check blank  
         IF ISNULL(@cToteID,'') = ''  
         BEGIN  
            SET @nErrNo = 201508  
            SET @cErrMsg =  rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need BatchKey  
            SET @cErrMsg1 = @cErrMsg  
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '201508', @cErrMsg1  
            SET @cOutField05=''  
            SET @cFieldAttr03 = 'O' -- wavepk  
            SET @cFieldAttr05 = '' -- ToteID  
            GOTO Quit  
         END  
  
         IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'DROPID', @cToteID) = 0  
         BEGIN  
            SET @nErrNo = 201509  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need BatchKey  
            SET @cErrMsg1 = 'Invalid Format Scanned:'  
            SET @cErrMsg2 = @cToteID  
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '201509', @cErrMsg1,@cErrMsg2  
            SET @cOutField05=''  
            SET @cFieldAttr03 = 'O' -- wavepk  
            SET @cFieldAttr05 = '' -- ToteID  
            GOTO Quit  
         END  
  
         IF EXISTS(SELECT 1  
                  From Pickdetail  PD (NOLOCK)   
                  Where pd.dropid=@cToteID  
                     and PD.WaveKey = @cWavekey  
                     and pd.caseid=@cCaseID  
                     AND PD.Status < @cPickConfirmStatus )  
         BEGIN  
            SET @nErrNo = 201510  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need BatchKey  
            SET @cErrMsg1 = 'Duplicate ToteID:'  
            SET @cErrMsg2 = @cToteID  
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '201510', @cErrMsg1,@cErrMsg2  
            SET @cOutField05=''  
            SET @cFieldAttr03 = 'O' -- wavepk  
            SET @cFieldAttr05 = '' -- ToteID  
            GOTO Quit  
         END  
  
      IF EXISTS(SELECT 1  
                   From Pickdetail  PD (NOLOCK)
                   JOIN ORDERS O (NOLOCK) ON PD.OrderKey = O.OrderKey
                   Where PD.DropID = @cToteID
                   And PD.StorerKey = @cStorerKey
                   And TRIM(O.UserDefine09)+TRIM(PD.CaseID) <> @cWavekey+@cCaseID
                   And O.Status <> '9'
                   And NOT Exists (SELECT 1 from PackHeader PH (NOLOCK)
							       Where PH.Orderkey = PD.Orderkey
                                   And PH.Status <> '9'))  

         BEGIN  
            SET @nErrNo = 201515  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need BatchKey  
            SET @cErrMsg1 = 'TOTEID IN USE:'  
            SET @cErrMsg2 = @cToteID  
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nErrNo, @cErrMsg1,@cErrMsg2  
            SET @cOutField05=''  
            SET @cFieldAttr03 = 'O' -- wavepk  
            SET @cFieldAttr05 = '' -- ToteID  
            GOTO Quit  
         END  

         IF EXISTS (select 1 FROM rdt.rdtPTLCartLog WITH (NOLOCK)  
                     WHERE CartID = @cCartID  
                        AND wavekey = @cWavekey  
                        and ToteID = @cToteID)  
  
         BEGIN  
            SET @nErrNo = 201514  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need BatchKey  
            SET @cErrMsg1 = 'ToteIDScanned:'  
            SET @cErrMsg2 = @cToteID  
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '201514', @cErrMsg1,@cErrMsg2  
            SET @cOutField05=''  
            SET @cFieldAttr03 = 'O' -- wavepk  
            SET @cFieldAttr05 = '' -- ToteID  
            GOTO Quit  
         END  
  
         BEGIN TRAN  
         SAVE TRAN rdt_PTLCart_Assign_WaveTotes01  
  
  
         SELECT TOP 1 @cCaseID = CaseID,  
                @cPosition = Position,  
                @cOrderKey = Orderkey  
         FROM rdt.rdtPTLCartLog WITH (NOLOCK)  
         WHERE CartID = @cCartID  
            AND wavekey = @cWavekey  
            AND toteid = ''  
         order by Position  
  
         -- Get position info  
         SELECT @cIPAddress = IPAddress  
         FROM DeviceProfile WITH (NOLOCK)  
         WHERE DeviceType = 'CART'  
            AND DeviceID = @cCartID  
            AND DevicePosition = @cPosition  
  
         -- Save assign  
         UPDATE rdt.rdtPTLCartLog SET  
            ToteID = @cToteID  
         WHERE CartID = @cCartID  
            AND Position = @cPosition  
            AND Storerkey = @cStorerKey  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 201512  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Log fail  
            GOTO RollBackTran  
         END  
  
  
  
         SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT LOC.LOC, PD.SKU, SUM( PD.QTY)  
            FROM dbo.PickDetail PD WITH (NOLOCK)  
               JOIN dbo.LOC LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)  
            WHERE PD.Wavekey = @cWavekey   
               AND PD.CaseID = @cCaseID  
               AND PD.Orderkey = @cOrderKey  
               AND PD.Status <> '4'  
               AND PD.Status < @cPickConfirmStatus  
               AND PD.QTY > 0  
            GROUP BY LOC.LOC, PD.SKU  
         OPEN @curPD  
         FETCH NEXT FROM @curPD INTO @cLOC, @cSKU, @nQTY  
         WHILE @@FETCH_STATUS = 0  
         BEGIN  
            INSERT INTO PTL.PTLTran (  
               IPAddress, DeviceID, DevicePosition, Status, PTLType,  
               DeviceProfileLogKey, DropID, OrderKey, Storerkey, SKU, LOC, ExpectedQTY, QTY, SourceKey, CaseID)  
            VALUES (  
               '', @cCartID, @cPosition, '0', 'CART',  
               @cDPLKey, @cToteID, @cOrderKey, @cStorerKey, @cSKU, @cLOC, @nQTY, 0, @cWavekey, @cCaseID)  
  
            IF @@ERROR <> ''  
            BEGIN  
               SET @nErrNo = 201513  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo ,@cLangCode ,'DSP') --INS PTL Fail  
               GOTO RollBackTran  
            END  
            FETCH NEXT FROM @curPD INTO @cLOC, @cSKU, @nQTY  
         END  
  
         COMMIT TRAN rdt_PTLCart_Assign_BatchTotes01  
  
         IF EXISTS (SELECT 1  
                        FROM rdt.rdtPTLCartLog WITH (NOLOCK)  
                        WHERE CartID = @cCartID  
                           AND wavekey = @cWavekey  
                           AND toteid = '')  
         BEGIN  
            SET @cToteID=''  
            SET @cOutField04=@nTotalTote+1  
            SET @nErrNo='-1'  
            GOTO QUIT  
         END  
      END  
  
      SET @cFieldAttr03 = ' ' -- wavepk  
      SET @cFieldAttr05 = '' -- ToteID  
        
      GOTO QUIT  
  
   END  
  
RollBackTran:  
   ROLLBACK TRAN rdt_PTLCart_Assign_WaveTotes01  
  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  
END 

GO
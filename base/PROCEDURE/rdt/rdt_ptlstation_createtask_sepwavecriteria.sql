SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdt_PTLStation_CreateTask_SepWaveCriteria           */  
/* Copyright      : LFLogistics                                         */  
/*                                                                      */  
/* Date        Rev  Author      Purposes                                */  
/* 2020-07-13  1.0  James       WMS-13639 Created                       */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_PTLStation_CreateTask_SepWaveCriteria] (  
    @nMobile      INT  
   ,@nFunc        INT  
   ,@cLangCode    NVARCHAR(3)  
   ,@nStep        INT  
   ,@nInputKey    INT  
   ,@cFacility    NVARCHAR(5)  
   ,@cStorerKey   NVARCHAR(15)  
   ,@cType        NVARCHAR(20)    
   ,@cLight       NVARCHAR(1)   -- 0 = no light, 1 = use light  
   ,@cStation1    NVARCHAR(10)    
   ,@cStation2    NVARCHAR(10)    
   ,@cStation3    NVARCHAR(10)    
   ,@cStation4    NVARCHAR(10)    
   ,@cStation5    NVARCHAR(10)    
   ,@cMethod      NVARCHAR(10)  
   ,@cScanID      NVARCHAR(20)      OUTPUT  
   ,@cCartonID    NVARCHAR(20)  
   ,@nErrNo       INT               OUTPUT  
   ,@cErrMsg      NVARCHAR(20)      OUTPUT  
   ,@cScanSKU     NVARCHAR(20) = '' OUTPUT  
   ,@cSKUDescr    NVARCHAR(60) = '' OUTPUT  
   ,@nQTY         INT          = 0  OUTPUT  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @nTranCount     INT  
   DECLARE @bSuccess       INT  
   DECLARE @cSQL           NVARCHAR( MAX)  
   DECLARE @cSQLParam      NVARCHAR( MAX)  
     
   DECLARE @cWaveKey       NVARCHAR( 10)  
   DECLARE @cCriteria1     NVARCHAR( 30)  
   DECLARE @cCriteria2     NVARCHAR( 30)  
   DECLARE @cOrderKey      NVARCHAR( 10)  
   DECLARE @cSKU           NVARCHAR( 20)  
   DECLARE @nPDQTY         INT  
   DECLARE @cDispatchPiecePickMethod   NVARCHAR( 10)
   DECLARE @curPD CURSOR
      
   DECLARE @tWaveCriteria TABLE  
   (  
      WaveKey        NVARCHAR(10) NOT NULL,   
      Criteria1      NVARCHAR(30) NOT NULL,   
      Criteria2      NVARCHAR(30) NOT NULL  
   )  
     
   /***********************************************************************************************  
                                              Generate PTLTran  
   ***********************************************************************************************/  
   -- Check order not yet assign carton ID (for Exceed continuous backend assign new orders)  
   IF EXISTS( SELECT 1   
      FROM rdt.rdtPTLStationLog WITH (NOLOCK)  
      WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)  
         AND CartonID = '')  
   BEGIN  
      SET @nErrNo = 157001  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --AssignCartonID  
      GOTO Quit  
   END  
  
   -- Check task   
   IF NOT EXISTS( SELECT 1   
      FROM Orders O WITH (NOLOCK)  
         JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)  
      WHERE PD.StorerKey = @cStorerKey  
         AND PD.DropID = @cScanID  
         AND PD.Status <= '5'  
         AND PD.CaseID = ''  
         AND PD.QTY > 0  
         AND PD.Status <> '4'  
         AND O.Status <> 'CANC'   
         AND O.SOStatus <> 'CANC')  
   BEGIN  
      SET @nErrNo = 157002  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No more task  
      GOTO Quit  
   END  
 
   SELECT TOP 1 @cWaveKey = WaveKey
   FROM rdt.rdtPTLStationLog WITH (NOLOCK)
   WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)  
   ORDER BY 1

   SELECT @cDispatchPiecePickMethod = DispatchPiecePickMethod
   FROM dbo.Wave WITH (NOLOCK)
   WHERE WaveKey = @cWaveKey

   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  
   SAVE TRAN rdt_PTLStation_CreateTask  
  
   DECLARE @nRowRef      INT  
   DECLARE @cIPAddress   NVARCHAR(40)  
   DECLARE @cPosition    NVARCHAR(10)  
   DECLARE @cStation     NVARCHAR(10)  
   DECLARE @cDropID      NVARCHAR(20)  
  
   SET @nPDQTY = 0  
   SET @nQTY = 0  

   -- Get wave criteria in station  
   IF @cDispatchPiecePickMethod = 'SEPB2BPTS'
   BEGIN
      INSERT INTO @tWaveCriteria (WaveKey, Criteria1, Criteria2)   
      SELECT WaveKey, LoadKey, UserDefine01  
      FROM rdt.rdtPTLStationLog WITH (NOLOCK)   
      WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)  
      AND   LoadKey <> ''  
      AND   UserDefine01 <> ''  

      SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT WD.WaveKey, O.LoadKey, SKU.BUSR4, O.OrderKey, PD.DropID, PD.SKU, SUM( PD.QTY)  
      FROM dbo.WaveDetail WD WITH (NOLOCK)   
      JOIN dbo.Orders O WITH (NOLOCK) ON ( WD.OrderKey = O.OrderKey)  
      JOIN dbo.PickDetail PD WITH (NOLOCK) ON ( PD.OrderKey = O.OrderKey)  
      JOIN dbo.SKU SKU WITH (NOLOCK) ON ( PD.SKU = SKU.SKU AND PD.Storerkey = SKU.StorerKey)
      JOIN @tWaveCriteria t ON ( t.WaveKey = WD.WaveKey AND t.Criteria1 = O.LoadKey AND t.Criteria2 = SKU.BUSR4)  
      WHERE PD.StorerKey = @cStorerKey  
      AND   PD.DropID = @cScanID  
      AND   PD.Status <= '5'  
      AND   PD.CaseID = ''  
      AND   PD.QTY > 0  
      AND   PD.Status <> '4'  
      AND   O.Status <> 'CANC'   
      AND  O.SOStatus <> 'CANC'  
      GROUP BY WD.WaveKey, O.LoadKey, SKU.BUSR4, O.OrderKey, PD.SKU, PD.DropID  
   END
   ELSE  -- SEPB2CPTS
   BEGIN
      INSERT INTO @tWaveCriteria (WaveKey, Criteria1, Criteria2)   
      SELECT WaveKey, OrderKey, ''  
      FROM rdt.rdtPTLStationLog WITH (NOLOCK)   
      WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)  
      AND  OrderKey <> ''

      SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT WD.WaveKey, O.OrderKey, '', O.OrderKey, PD.DropID, PD.SKU, SUM( PD.QTY)  
      FROM dbo.WaveDetail WD WITH (NOLOCK)   
      JOIN dbo.Orders O WITH (NOLOCK) ON ( WD.OrderKey = O.OrderKey)  
      JOIN dbo.PickDetail PD WITH (NOLOCK) ON ( PD.OrderKey = O.OrderKey)  
      JOIN @tWaveCriteria t ON ( t.WaveKey = WD.WaveKey AND t.Criteria1 = O.OrderKey)  
      WHERE PD.StorerKey = @cStorerKey  
         AND PD.DropID = @cScanID  
         AND PD.Status <= '5'  
         AND PD.CaseID = ''  
         AND PD.QTY > 0  
         AND PD.Status <> '4'  
         AND O.Status <> 'CANC'   
         AND O.SOStatus <> 'CANC'  
      GROUP BY WD.WaveKey, O.OrderKey, PD.SKU, PD.DropID  
   END

   OPEN @curPD  
   FETCH NEXT FROM @curPD INTO @cWaveKey, @cCriteria1, @cCriteria2, @cOrderKey, @cDropID, @cSKU, @nPDQTY  
   WHILE @@FETCH_STATUS = 0  
   BEGIN  
      IF @cDispatchPiecePickMethod = 'SEPB2BPTS'
      BEGIN
         -- Get station info  
         SET @nRowRef = 0  
         SELECT   
            @nRowRef = RowRef,   
            @cStation = Station,   
            @cIPAddress = IPAddress,   
            @cPosition = Position   
         FROM rdt.rdtPTLStationLog WITH (NOLOCK)  
         WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)  
         AND   WaveKey = @cWaveKey  
         AND   LoadKey = @cCriteria1   
         AND   UserDefine01 = @cCriteria2  
      END
      ELSE
      BEGIN
         -- Get station info  
         SET @nRowRef = 0  
         SELECT   
            @nRowRef = RowRef,   
            @cStation = Station,   
            @cIPAddress = IPAddress,   
            @cPosition = Position   
         FROM rdt.rdtPTLStationLog WITH (NOLOCK)  
         WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)  
         AND   WaveKey = @cWaveKey  
         AND   OrderKey = @cCriteria1   
      END
      
      IF @nRowRef > 0  
      BEGIN  
         -- Check PTLTran generated  
         IF NOT EXISTS( SELECT 1  
            FROM PTL.PTLTran WITH (NOLOCK)  
            WHERE DeviceID = @cStation  
               AND IPAddress = @cIPAddress   
               AND DevicePosition = @cPosition  
               AND GroupKey = @nRowRef  
               AND Func = @nFunc  
               AND DropID = @cScanID  
               AND OrderKey = @cOrderKey  
               AND Status < '9' )  
         BEGIN  
            -- Generate PTLTran  
            INSERT INTO PTL.PTLTran (  
               IPAddress, DevicePosition, DeviceID, PTLType,   
               OrderKey, StorerKey, SKU, ExpectedQTY, QTY, DropID, Func, GroupKey, SourceType)  
            VALUES (  
               @cIPAddress, @cPosition, @cStation, 'STATION',   
               @cOrderKey, @cStorerKey, @cSKU, @nPDQTY, 0, @cDropID, @nFunc, @nRowRef, 'rdt_PTLStation_CreateTask_SepWaveCriteria')  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 157003  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPTLTranFail  
               GOTO RollbackTran  
            END  
         END  
         
      END  
      FETCH NEXT FROM @curPD INTO @cWaveKey, @cCriteria1, @cCriteria2, @cOrderKey, @cDropID, @cSKU, @nPDQTY  
   END  
   COMMIT TRAN rdt_PTLStation_CreateTask  
  
  
   /***********************************************************************************************  
                                              Get task info  
   ***********************************************************************************************/  
   -- Get QTY  
   SELECT @nQTY = ISNULL( SUM( ExpectedQTY), 0)  
   FROM PTL.PTLTran WITH (NOLOCK)  
   WHERE DeviceID IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)  
      AND DropID = @cScanID  
      AND Status <> '9'  
  
   IF @nQTY = 0  
   BEGIN  
      SET @nErrNo = 157004  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Task (PTL)  
      GOTO Quit  
   END  

   -- Get SKU  
   IF @cDispatchPiecePickMethod = 'SEPB2BPTS'
   BEGIN
      SELECT TOP 1  
         @cScanSKU = PD.SKU  
      FROM dbo.WaveDetail WD WITH (NOLOCK)   
      JOIN dbo.Orders O WITH (NOLOCK) ON ( WD.OrderKey = O.OrderKey)  
      JOIN dbo.PickDetail PD WITH (NOLOCK) ON ( PD.OrderKey = O.OrderKey)  
      JOIN dbo.SKU SKU WITH (NOLOCK) ON ( PD.SKU = SKU.SKU AND PD.Storerkey = SKU.StorerKey)
      JOIN @tWaveCriteria t ON ( t.WaveKey = WD.WaveKey AND t.Criteria1 = O.LoadKey AND t.Criteria2 = SKU.BUSR4)  
      WHERE PD.DropID = @cScanID  
      AND   PD.Status <= '5'  
      AND   PD.CaseID = ''  
      AND   PD.QTY > 0  
      AND   PD.Status <> '4'  
      AND   O.Status <> 'CANC'   
      AND   O.SOStatus <> 'CANC'  
   END
   ELSE
   BEGIN
      SELECT TOP 1  
         @cScanSKU = PD.SKU  
      FROM dbo.WaveDetail WD WITH (NOLOCK)   
      JOIN dbo.Orders O WITH (NOLOCK) ON ( WD.OrderKey = O.OrderKey)  
      JOIN dbo.PickDetail PD WITH (NOLOCK) ON ( PD.OrderKey = O.OrderKey)  
      JOIN @tWaveCriteria t ON ( t.WaveKey = WD.WaveKey AND t.Criteria1 = O.OrderKey)  
      WHERE PD.DropID = @cScanID  
      AND   PD.Status <= '5'  
      AND   PD.CaseID = ''  
      AND   PD.QTY > 0  
      AND   PD.Status <> '4'  
      AND   O.Status <> 'CANC'   
      AND   O.SOStatus <> 'CANC'  
   END
     
   -- Get SKU description  
   DECLARE @cDispStyleColorSize  NVARCHAR( 20)  
   SET @cDispStyleColorSize = rdt.RDTGetConfig( @nFunc, 'DispStyleColorSize', @cStorerKey)  
     
   IF @cDispStyleColorSize = '0'  
      SELECT @cSKUDescr = Descr FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cScanSKU  
     
   ELSE IF @cDispStyleColorSize = '1'  
      SELECT @cSKUDescr =   
         CAST( Style AS NCHAR(20)) +   
         CAST( Color AS NCHAR(10)) +   
         CAST( Size  AS NCHAR(10))   
      FROM SKU WITH (NOLOCK)   
      WHERE StorerKey = @cStorerKey   
         AND SKU = @cScanSKU  
        
   ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDispStyleColorSize AND type = 'P')  
   BEGIN  
      SET @cSQL = 'EXEC rdt.' + RTRIM( @cDispStyleColorSize) +  
         ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +  
         ' @cType, @cLight, @cStation1, @cStation2, @cStation3, @cStation4, @cStation5, @cMethod, @cScanID, @cCartonID, @cSKU, ' +  
         ' @nErrNo OUTPUT, @cErrMsg OUTPUT, @cSKUDescr OUTPUT '  
      SET @cSQLParam =  
         ' @nMobile    INT,          ' +  
         ' @nFunc      INT,          ' +  
         ' @cLangCode  NVARCHAR( 3), ' +  
         ' @nStep      INT,          ' +  
         ' @nInputKey  INT,          ' +  
         ' @cFacility  NVARCHAR(5),  ' +  
         ' @cStorerKey NVARCHAR(15), ' +  
         ' @cType      NVARCHAR(20), ' +  
         ' @cLight     NVARCHAR(1),  ' +  
         ' @cStation1  NVARCHAR(10), ' +    
         ' @cStation2  NVARCHAR(10), ' +    
         ' @cStation3  NVARCHAR(10), ' +    
         ' @cStation4  NVARCHAR(10), ' +    
         ' @cStation5  NVARCHAR(10), ' +    
         ' @cMethod    NVARCHAR(10), ' +  
         ' @cScanID    NVARCHAR(20), ' +  
         ' @cSKU       NVARCHAR(20), ' +  
         ' @nErrNo     INT          OUTPUT, ' +  
         ' @cErrMsg    NVARCHAR(20) OUTPUT, ' +  
         ' @cSKUDescr  NVARCHAR(60) OUTPUT  '  
     
      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
         @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,   
         @cType, @cLight, @cStation1, @cStation2, @cStation3, @cStation4, @cStation5, @cMethod, @cScanID, @cCartonID, @cScanSKU,   
         @nErrNo OUTPUT, @cErrMsg OUTPUT, @cSKUDescr OUTPUT  
   END  
     
   GOTO Quit  
  
RollBackTran:  
   ROLLBACK TRAN rdt_PTLStation_CreateTask  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  
  
END  

GO
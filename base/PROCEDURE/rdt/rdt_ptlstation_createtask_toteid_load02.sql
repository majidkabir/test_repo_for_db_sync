SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store procedure: rdt_PTLStation_CreateTask_ToteID_Load02            */    
/* Copyright      : LFLogistics                                         */    
/*                                                                      */    
/* Date        Rev  Author      Purposes                                */    
/* 20-02-2021 1.0  yeekung     WMS-16300 Created                        */    
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_PTLStation_CreateTask_ToteID_Load02] (    
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
       
   DECLARE @cLoadKey       NVARCHAR( 10)    
   DECLARE @nPDQTY         INT    =0
       
   DECLARE @tLoads TABLE    
   (    
      LoadKey NVARCHAR(10) NOT NULL    
   )    
  
   DECLARE @tOrder TABLE    
   (    
      orderkey NVARCHAR(20) NOT NULL    
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
      SET @nErrNo = 168651    
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --AssignCartonID    
      GOTO Quit    
   END    
    
   -- Get load in station    
   INSERT INTO @tLoads (LoadKey)     
   SELECT LoadKey    
   FROM rdt.rdtPTLStationLog WITH (NOLOCK)     
   WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)    
      AND LoadKey <> ''    
  
   INSERT INTO @tOrder (orderkey)     
   SELECT orderkey    
   FROM rdt.rdtPTLStationLog WITH (NOLOCK)     
   WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)    
      AND OrderKey <> ''    
       
   -- Check task     
   IF NOT EXISTS( SELECT 1     
      FROM @tLoads L    
         JOIN LoadPlanDetail LPD WITH (NOLOCK) ON (L.LoadKey = LPD.LoadKey)     
         JOIN Orders O WITH (NOLOCK) ON (LPD.OrderKey = O.OrderKey )     
         JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)    
      WHERE PD.StorerKey = @cStorerKey    
         AND PD.DropID = @cScanID    
         AND PD.Status <= '5'    
         AND PD.CaseID = ''    
         AND PD.QTY > 0    
         AND PD.Status <> '4'    
         AND O.Status <> 'CANC'     
         AND O.SOStatus <> 'CANC')    
   BEGIN    
      IF NOT EXISTS( SELECT 1     
      FROM @tOrder t   
         JOIN Orders O WITH (NOLOCK)  ON (t.OrderKey = O.OrderKey)   
         JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)    
      WHERE PD.StorerKey = @cStorerKey    
         AND PD.DropID = @cScanID    
         AND PD.Status <= '5'    
         AND PD.CaseID = ''    
         AND PD.QTY > 0    
         AND PD.Status <> '4'    
         AND O.Status <> 'CANC'     
         AND O.SOStatus <> 'CANC')    
      BEGIn  
         SET @nErrNo = 168652    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No task    
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- UCC/ID    
         SET @nErrNo = -1 -- Remain in current screen    
         SET @cScanID = ''    
         SET @cScanSKU = ''    
         GOTO Quit    
      END  
   END    
  
    
   SET @nTranCount = @@TRANCOUNT    
   BEGIN TRAN    
   SAVE TRAN rdt_PTLStation_CreateTask    
    
   DECLARE @nRowRef      INT    
   DECLARE @cIPAddress   NVARCHAR(40)    
   DECLARE @cPosition    NVARCHAR(10)    
   DECLARE @cStation     NVARCHAR(10)    
   DECLARE @cOrderKey    NVARCHAR(10)    
   DECLARE @cSKU         NVARCHAR(20)    
   DECLARE @cDropID      NVARCHAR(20)    
    
   SET @nPDQTY = 0    
   SET @nQTY = 0    
     
   IF EXISTS (SELECT 1     
      FROM @tLoads L    
         JOIN LoadPlanDetail LPD WITH (NOLOCK) ON (L.LoadKey = LPD.LoadKey)     
         JOIN Orders O WITH (NOLOCK) ON (LPD.OrderKey = O.OrderKey )     
         JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)    
      WHERE PD.StorerKey = @cStorerKey    
         AND PD.DropID = @cScanID    
         AND PD.Status <= '5'    
         AND PD.CaseID = ''    
         AND PD.QTY > 0    
         AND PD.Status <> '4'    
         AND O.Status <> 'CANC'     
         AND O.SOStatus <> 'CANC')  
   BEGIN  
  
      DECLARE @curPD CURSOR    
      SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
         SELECT LPD.LoadKey, PD.SKU, SUM( PD.QTY)    
         FROM LoadPlanDetail LPD WITH (NOLOCK)     
            JOIN Orders O WITH (NOLOCK) ON (LPD.OrderKey = O.OrderKey)    
            JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)    
            JOIN @tLoads t ON (t.LoadKey = LPD.LoadKey)    
         WHERE PD.StorerKey = @cStorerKey     
            AND PD.DropID = @cScanID    
            AND PD.Status <= '5'    
            AND PD.CaseID = ''    
            AND PD.QTY > 0    
            AND PD.Status <> '4'    
            AND O.Status <> 'CANC'     
            AND O.SOStatus <> 'CANC'    
         GROUP BY LPD.LoadKey, PD.SKU    
      OPEN @curPD    
      FETCH NEXT FROM @curPD INTO @cLoadKey, @cSKU, @nPDQTY    
      WHILE @@FETCH_STATUS = 0    
      BEGIN    
         SET @cScanSKU = @cSKU     
    
         -- Get station info    
         SET @nRowRef = 0    
         SELECT     
            @nRowRef = RowRef,     
            @cStation = Station,     
            @cIPAddress = IPAddress,     
            @cPosition = Position     
         FROM rdt.rdtPTLStationLog WITH (NOLOCK)    
         WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)    
            AND LoadKey = @cLoadKey    
          
         IF @nRowRef > 0    
         BEGIN    
  
            IF ISNULL(@cloadkey,'')<>''  
            BEGIN  
               IF NOT EXISTS( SELECT 1    
               FROM PTL.PTLTran WITH (NOLOCK)    
               WHERE DeviceID = @cStation    
                  AND IPAddress = @cIPAddress     
                  AND DevicePosition = @cPosition    
                  AND GroupKey = @nRowRef    
                  AND Func = @nFunc    
                  AND SKU = @cSKU    
                  AND DropID = @cScanID    
                 -- AND OrderKey = @cOrderKey  
                  AND sourcekey=@cLoadKey)  
               BEGIN  
                  -- Generate PTLTran    
                  INSERT INTO PTL.PTLTran (    
                     IPAddress, DevicePosition, DeviceID, PTLType,     
                     sourcekey, StorerKey, SKU, ExpectedQTY, QTY, DropID, Func, GroupKey, SourceType)    
                  VALUES (    
                     @cIPAddress, @cPosition, @cStation, 'STATION',     
                     @cLoadKey, @cStorerKey, @cSKU, @nPDQTY, 0, @cScanID, @nFunc, @nRowRef, 'rdt_PTLStation_CreateTask_ToteID_Load02')  
                  
                  IF @@ERROR <>0
                  BEGIn  
                     SET @nErrNo = 168653    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPTlTranFail   
                     GOTO RollbackTran    
                  END  
               END   
            END  
         END    
         FETCH NEXT FROM @curPD INTO @cLoadKey, @cSKU, @nPDQTY    
      END    
   END  
   ELSE  
   BEGIN  
  
      DECLARE @curorder CURSOR    
      SET @curorder = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
         SELECT  PD.OrderKey, PD.SKU, SUM(PD.QTY)    
         FROM @tOrder t   
         JOIN Orders O WITH (NOLOCK)  ON (t.OrderKey = O.OrderKey)   
         JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)     
         WHERE PD.StorerKey = @cStorerKey     
            AND PD.DropID = @cScanID    
            AND PD.Status <= '5'    
            AND PD.CaseID = ''    
            AND PD.QTY > 0    
            AND PD.Status <> '4'    
            AND O.Status <> 'CANC'     
            AND O.SOStatus <> 'CANC'    
         GROUP BY  PD.OrderKey, PD.SKU    
      OPEN @curorder    
      FETCH NEXT FROM @curorder INTO  @cOrderKey, @cSKU, @nPDQTY    
      WHILE @@FETCH_STATUS = 0    
      BEGIN    
         SET @cScanSKU = @cSKU     
    
         -- Get station info    
         SET @nRowRef = 0    
         SELECT     
            @nRowRef = RowRef,     
            @cStation = Station,     
            @cIPAddress = IPAddress,     
            @cPosition = Position     
         FROM rdt.rdtPTLStationLog WITH (NOLOCK)    
         WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)    
            AND orderkey=@cOrderKey   

          
         IF @nRowRef > 0    
         BEGIN    
  
            IF NOT EXISTS( SELECT 1    
               FROM PTL.PTLTran WITH (NOLOCK)    
               WHERE DeviceID = @cStation    
                  AND IPAddress = @cIPAddress     
                  AND DevicePosition = @cPosition    
                  AND GroupKey = @nRowRef    
                  AND Func = @nFunc    
                  AND SKU = @cSKU    
                  AND DropID = @cScanID    
                  AND OrderKey = @cOrderKey)    
            BEGIN                
               -- Generate PTLTran    
               INSERT INTO PTL.PTLTran (    
                  IPAddress, DevicePosition, DeviceID, PTLType,     
                  OrderKey, StorerKey, SKU, ExpectedQTY, QTY, DropID, Func, GroupKey, SourceType)    
               VALUES (    
                  @cIPAddress, @cPosition, @cStation, 'STATION',     
                  @cOrderKey, @cStorerKey, @cSKU, @nPDQTY, 0, @cScanID, @nFunc, @nRowRef, 'rdt_PTLStation_CreateTask_ToteID_Load02')    
               IF @@ERROR <> 0    
               BEGIN    
                  SET @nErrNo = 168654    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPTLTranFail    
                  GOTO RollbackTran    
               END    
            END    
         END    
         FETCH NEXT FROM @curorder INTO  @cOrderKey, @cSKU, @nPDQTY    
      END    
   END  
       
   COMMIT TRAN rdt_PTLStation_CreateTask    
    
    
   /***********************************************************************************************    
                                              Get task info    
   ***********************************************************************************************/    
   -- Get QTY    
   -- SET @nQTY = @nQTY_PTL    
    
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
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
    
/******************************************************************************/    
/* Store procedure: rdt_PFLStation_Assign_CaseID                              */    
/* Copyright      : LFLogistics                                               */    
/*                                                                            */    
/* Date       Rev  Author   Purposes                                          */    
/* 05-11-2020 1.0  YeeKung  WMS-15125 Created                                 */    
/******************************************************************************/    
    
CREATE PROC [RDT].[rdt_PFLStation_Assign_CaseID] (    
   @nMobile          INT,     
   @nFunc            INT,     
   @cLangCode        NVARCHAR( 3),     
   @nStep            INT,     
   @nInputKey        INT,     
   @cFacility        NVARCHAR( 5),     
   @cStorerKey       NVARCHAR( 15),      
   @cStation1        NVARCHAR( 10),      
   @cStation2        NVARCHAR( 10),      
   @cStation3        NVARCHAR( 10),      
   @cStation4        NVARCHAR( 10),      
   @cStation5        NVARCHAR( 10),      
   @cMethod          NVARCHAR( 1),    
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
    
   DECLARE @nTranCount  INT    
   DECLARE @i           INT    
   DECLARE @nRowRef     INT    
       
   DECLARE @cOrderKey      NVARCHAR(10)    
   DECLARE @cStation       NVARCHAR(10)    
   DECLARE @cIPAddress     NVARCHAR(40)    
   DECLARE @cPosition      NVARCHAR(10)    
   DECLARE @cDropID        NVARCHAR(20)    
   DECLARE @cCaseID        NVARCHAR(20)    
   DECLARE @cSKU           NVARCHAR(20)    
   DECLARE @cLOC           NVARCHAR(10)        
   DECLARE @nPDQTY         INT    
   DECLARE @nTotalLoad     INT    
   DECLARE @nTotalCarton   INT    
   DECLARE @curPD          CURSOR    
    
   SET @nTranCount = @@TRANCOUNT    
    
   /***********************************************************************************************    
                                            POPULATE    
   ***********************************************************************************************/    
   -- Going in assign screen    
   IF @cType = 'POPULATE-IN'    
   BEGIN    
      -- From station screen    
      -- IF @nInputKey = 1 -- ENTER    
      -- BEGIN    
      -- END    
          
      -- From matrix screen    
      IF @nInputKey = 0 -- ESC    
      BEGIN    
         -- Handling transaction    
         SET @nTranCount = @@TRANCOUNT    
         BEGIN TRAN  -- Begin our own transaction    
         SAVE TRAN rdt_PFLStation_Assign_CaseID -- For rollback or commit only our own transaction    
    
         -- Loop stations    
         SET @i = 1    
         WHILE @i < 6    
         BEGIN    
            IF @i = 1 SELECT @cStation = @cStation1 ELSE    
            IF @i = 2 SELECT @cStation = @cStation2 ELSE    
            IF @i = 3 SELECT @cStation = @cStation3 ELSE    
            IF @i = 4 SELECT @cStation = @cStation4 ELSE    
            IF @i = 5 SELECT @cStation = @cStation5    
    
            IF @cStation <> ''    
            BEGIN    
               -- Get assigned    
               SET @nRowRef = 0    
               SELECT @nRowRef = RowRef    
               FROM rdt.rdtPFLStationLog WITH (NOLOCK)    
               WHERE Station = @cStation     
                  AND Method = @cMethod    
    
               -- Unassign (order)    
               IF @nRowRef > 0    
               BEGIN    
                  UPDATE rdt.rdtPFLStationLog SET    
                     OrderKey = '',     
                     EditDate = GETDATE(),     
                     EditWho = SUSER_SNAME()    
                  WHERE RowRef = @nRowRef    
                  IF @@ERROR <> 0    
                  BEGIN    
                     ROLLBACK TRAN rdt_PFLStation_Assign_CaseID -- Only rollback change made here    
                     WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
                        COMMIT TRAN    
    
                     SET @nErrNo = 160551    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Log Fail    
                     GOTO Quit    
                  END    
               END    
    
               -- Close PTLTran    
               DECLARE @nPTLKey BIGINT    
               DECLARE @curPTLTran CURSOR    
               SET @curPTLTran = CURSOR FOR    
                  SELECT T.PTLKey    
                  FROM PTL.PTLTran T WITH (NOLOCK)    
                     JOIN DeviceProfile DP WITH (NOLOCK) ON (DP.DeviceID = T.DeviceID and DP.DevicePosition = T.DevicePosition)    
                  WHERE DP.DeviceID = @cStation    
                     AND T.Status <> '9'    
               OPEN @curPTLTran    
               FETCH NEXT FROM @curPTLTran INTO @nPTLKey    
               WHILE @@FETCH_STATUS = 0    
               BEGIN    
                  -- Update    
                  UPDATE PTL.PTLTran SET    
                     Status = '9',    
                     EditWho = SUSER_SNAME(),    
                     EditDate = GETDATE(),    
                     TrafficCop = NULL    
                  WHERE PTLKey = @nPTLKey    
                  IF @@ERROR <> 0    
                  BEGIN    
                     ROLLBACK TRAN rdt_PFLStation_Assign_CaseID -- Only rollback change made here    
                     WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
                        COMMIT TRAN    
    
                     SET @nErrNo = 160552    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PTran Fail    
                     GOTO Quit    
                  END    
    
                  FETCH NEXT FROM @curPTLTran INTO @nPTLKey    
               END             
            END    
            SET @i = @i + 1    
         END    
             
         COMMIT TRAN rdt_PFLStation_Assign_CaseID -- Only rollback change made here    
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
            COMMIT TRAN    
      END    
          
      -- Get WaveKey    
      SET @cDropid = ''    
      SELECT @cDropid = dropid    
      FROM rdt.rdtPFLStationLog WITH (NOLOCK)     
      WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)    
          
    
     -- Prepare next screen var    
     SET @cOutField01 = ''    
    
      -- Go to Wave DropID screen    
      SET @nScn = 5511    
   END    
          
   -- Getting out assign screen    
   IF @cType = 'POPULATE-OUT'    
   BEGIN    
      -- Go to matrix screen    
      -- IF @nInputKey = 1 -- ENTER    
      -- BEGIN    
      -- END    
      
     -- Go to station screen    
     IF @nInputKey = 0 -- ESC    
     BEGIN    
            -- Handling transaction    
            SET @nTranCount = @@TRANCOUNT    
            BEGIN TRAN  -- Begin our own transaction    
            SAVE TRAN rdt_PFLStation_Assign_CaseID -- For rollback or commit only our own transaction    
         
            -- Loop stations    
            SET @i = 1    
            WHILE @i < 6    
            BEGIN    
               IF @i = 1 SELECT @cStation = @cStation1 ELSE    
               IF @i = 2 SELECT @cStation = @cStation2 ELSE    
               IF @i = 3 SELECT @cStation = @cStation3 ELSE    
               IF @i = 4 SELECT @cStation = @cStation4 ELSE    
               IF @i = 5 SELECT @cStation = @cStation5    
    
               IF @cStation <> ''    
               BEGIN    
                  -- Assigned    
                  IF EXISTS( SELECT 1 FROM rdt.rdtPFLStationLog WITH (NOLOCK) WHERE Station = @cStation AND Method = @cMethod)    
                  BEGIN    
                     -- Unassign    
                     DELETE rdt.rdtPFLStationLog     
                     WHERE Station = @cStation     
                        AND Method = @cMethod    
                     IF @@ERROR <> 0    
                     BEGIN    
                        ROLLBACK TRAN rdt_PFLStation_Assign_CaseID -- Only rollback change made here    
                        WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
                           COMMIT TRAN    
    
                        SET @nErrNo = 160553    
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL Log Fail    
                        GOTO Quit    
                     END    
                  END    
               END    
               SET @i = @i + 1    
            END    
             
            COMMIT TRAN rdt_PFLStation_Assign_CaseID -- Only rollback change made here    
            WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
               COMMIT TRAN    
         END    
    
      -- Enable field    
      SET @cFieldAttr01 = '' -- WaveKey    
      SET @cFieldAttr02 = '' -- DropID    
   END    
    
       
   /***********************************************************************************************    
                                                 CHECK    
   ***********************************************************************************************/    
   IF @cType = 'CHECK'    
   BEGIN    
      -- Screen mapping        
      SET @cDropID = CASE WHEN @cFieldAttr01 = '' THEN @cInField01 ELSE @cOutField01 END    
    
      -- Get storer config    
      DECLARE @cPickConfirmStatus NVARCHAR( 1)    
      SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)    
      IF @cPickConfirmStatus NOT IN ('3', '5')    
         SET @cPickConfirmStatus = '5'    
          
      --(cc01)       
      DECLARE @cExtendedValidateSP NVARCHAR( 20)    
      SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)    
      IF @cExtendedValidateSP = '0'    
         SET @cExtendedValidateSP = ''    
    
      -- WaveKey enabled    
      IF @cFieldAttr01 = ''    
      BEGIN    
         -- Check blank tote    
         IF @cDropID = ''    
         BEGIN    
            SET @nErrNo = 160554    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need DropID    
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- DropID    
            SET @cOutField02 = ''    
            GOTO Quit    
         END    
    
         -- Check DropID format    
         IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'DropID', @cDropID) = 0    
         BEGIN    
            SET @nErrNo = 160560    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format    
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- CartonID    
            SET @cOutField02 = ''    
            GOTO Quit    
         END   
    
         -- Check dropdi assigned    
         IF EXISTS( SELECT 1     
            FROM rdt.rdtPFLStationLog WITH (NOLOCK)     
            WHERE dropid = @cDropID     
               AND Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5))    
         BEGIN    
            SET @nErrNo = 160555   
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --dropid Assigned    
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- dropid    
            SET @cOutField01 = ''    
            GOTO Quit    
         END    
    
         -- Check dropid no task    
         IF NOT EXISTS( SELECT TOP 1 1     
            FROM Orders O WITH (NOLOCK)     
               JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
               JOIN DeviceProfile DP WITH (NOLOCK) ON (PD.LOC = DP.LOC)     
            WHERE  PD.caseid=@cdropid 
               AND O.StorerKey = @cStorerKey    
               AND O.Facility = @cFacility 
               AND DP.DeviceID IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)      
               AND O.Status <> 'CANC'     
               AND O.SOStatus <> 'CANC'     
               AND PD.Status < @cPickConfirmStatus    
               AND PD.Status <> '4'    
               AND PD.QTY > 0)    
         BEGIN    
            SET @nErrNo = 160556    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --no task    
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- dropid    
            SET @cOutField01 = ''    
            GOTO Quit    
         END   
         
         -- Get an order base on DropID    
         SET @cOrderKey = ''    
         SELECT TOP 1     
            @cOrderKey = OrderKey    
         FROM PickDetail PD WITH (NOLOCK)    
         WHERE StorerKey = @cStorerKey    
            AND DropID = @cDropID     
             
         -- Save assign    
         SET @i = 1    
         WHILE @i < 6    
         BEGIN    
            IF @i = 1 SELECT @cStation = @cStation1 ELSE    
            IF @i = 2 SELECT @cStation = @cStation2 ELSE    
            IF @i = 3 SELECT @cStation = @cStation3 ELSE    
            IF @i = 4 SELECT @cStation = @cStation4 ELSE    
            IF @i = 5 SELECT @cStation = @cStation5    
    
            IF @cStation <> ''    
            BEGIN    
               IF NOT EXISTS( SELECT 1 FROM rdt.rdtPFLStationLog WITH (NOLOCK) WHERE Station = @cStation AND dropid = @cdropid)    
               BEGIN    
                  INSERT INTO rdt.rdtPFLStationLog (StorerKey, Facility, Station, Method, dropid,OrderKey)    
                  VALUES (@cStorerKey, @cFacility, @cStation, @cMethod, @cdropid,@cOrderKey)    
                  IF @@ERROR <> 0    
                  BEGIN    
                     SET @nErrNo = 160557    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log Fail    
                     EXEC rdt.rdtSetFocusField @nMobile, 1 -- WaveKey    
                     SET @cOutField01 = ''    
                     GOTO Quit    
                  END    
               END    
            END    
            SET @i = @i + 1    
         END 
         
        DECLARE @nGroupKey INT    
         SET @nGroupKey = 0    
    
         -- Create PTLTran    
         SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
            SELECT DP.IPAddress, DP.DevicePosition, DP.DeviceID, PD.LOC, PD.SKU, SUM( PD.QTY)    
            FROM PickDetail PD WITH (NOLOCK)    
               JOIN DeviceProfile DP WITH (NOLOCK) ON (PD.LOC = DP.LOC)    
            WHERE PD.caseid = @cdropid    
               AND DP.DeviceType = 'STATION'    
               AND DP.DeviceID IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)    
               AND PD.DropID = ''    
               AND PD.Status < @cPickConfirmStatus    
               AND PD.Status <> '4'    
               AND PD.QTY > 0    
            GROUP BY DP.IPAddress, DP.DevicePosition, DP.DeviceID, PD.LOC, PD.SKU    
         OPEN @curPD    
         FETCH NEXT FROM @curPD INTO @cIPAddress, @cPosition, @cStation, @cLOC, @cSKU, @nPDQTY    
         WHILE @@FETCH_STATUS = 0    
         BEGIN    
            -- Check PTLTran generated    
            IF NOT EXISTS( SELECT 1    
               FROM PTL.PTLTran WITH (NOLOCK)    
               WHERE DeviceID = @cStation    
                  AND IPAddress = @cIPAddress     
                  AND DevicePosition = @cPosition    
                  AND OrderKey = @cOrderKey    
                  AND StorerKey = @cStorerKey    
                  AND SKU = @cSKU    
                  AND LOC = @cLOC    
                  AND Status = '0')    
            BEGIN    
               -- Generate PTLTran    
               INSERT INTO PTL.PTLTran (    
                  IPAddress, DevicePosition, DeviceID, PTLType, GroupKey,     
                  OrderKey, StorerKey, SKU, LOC, ExpectedQTY, QTY, Func, SourceType)    
               VALUES (    
                  @cIPAddress, @cPosition, @cStation, 'STATION', @nGroupKey,     
                  @cOrderKey, @cStorerKey, @cSKU, @cLOC, @nPDQTY, 0, @nFunc, 'rdt_PFLStation_Assign_CaseID')    
               IF @@ERROR <> 0    
               BEGIN    
                  SET @nErrNo = 160558    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPTLTranFail    
                  GOTO RollbackTran    
               END    
                   
               -- Update 1st record in a group    
               IF @nGroupKey = 0    
               BEGIN    
                  SET @nGroupKey = SCOPE_IDENTITY()    
                  UPDATE PTL.PTLTran SET    
                     GroupKey = @nGroupKey    
                  WHERE PTLKey = @nGroupKey    
                  IF @@ERROR <> 0    
                  BEGIN    
                     SET @nErrNo = 160559    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDPTLTranFail    
                     GOTO RollbackTran    
                  END    
               END    
            END    
            FETCH NEXT FROM @curPD INTO @cIPAddress, @cPosition, @cStation, @cLOC, @cSKU, @nPDQTY    
         END       
             
         -- Prepare current screen var    
         SET @cOutField01 = ''    
         SET @cOutField02 = '' -- @cDropID    
      
         GOTO Quit    
      END    
   END    
    
   GOTO Quit    
    
RollBackTran:    
   ROLLBACK TRAN rdt_PFLStation_Assign_CaseID    
    
Quit:    
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
      COMMIT TRAN    
END 

GO
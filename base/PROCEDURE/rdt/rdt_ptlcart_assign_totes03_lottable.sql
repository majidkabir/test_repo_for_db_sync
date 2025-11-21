SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
 
/******************************************************************************/    
/* Store procedure: rdt_PTLCart_Assign_Totes03_Lottable                       */    
/* Copyright      : LFLogistics                                               */    
/*                                                                            */    
/* Date       Rev  Author   Purposes                                          */    
/* 06-08-2019 1.0  Ung      WMS-18742 Based on rdt_PTLCart_Assign_Totes02     */    
/*                          change OrderKey to LoadKey                        */    
/* 10-06-2022 1.1  yeekung  WMS-19875 Add Validate for cartID(yeekung01)      */    
/* 16-12-2022 1.2  yeekung  WMS-21239 Add Validate for loadkey(yeekung02)      */ 
/* 29-05-2023 1.3  yeekung  JSM-152549 Performace Tune (yeekung03)            */
/******************************************************************************/    
    
CREATE   PROC [RDT].[rdt_PTLCart_Assign_Totes03_Lottable] (    
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
    
   DECLARE @nTranCount  INT    
   DECLARE @nTotalTote  INT    
    
   DECLARE @cLoadKey    NVARCHAR(10)    
   DECLARE @cPosition   NVARCHAR(10)    
   DECLARE @cToteID     NVARCHAR(20)    
   DECLARE @cTaskDetailKey NVARCHAR(10)    
       
   DECLARE @cLottableCode NVARCHAR( 30)    
   DECLARE @cLottable01   NVARCHAR( 18)    
   DECLARE @cLottable02   NVARCHAR( 18)    
   DECLARE @cLottable03   NVARCHAR( 18)    
   DECLARE @dLottable04   DATETIME    
   DECLARE @dLottable05   DATETIME    
   DECLARE @cLottable06 NVARCHAR( 30)    
   DECLARE @cLottable07   NVARCHAR( 30)    
   DECLARE @cLottable08   NVARCHAR( 30)    
   DECLARE @cLottable09   NVARCHAR( 30)    
   DECLARE @cLottable10   NVARCHAR( 30)    
   DECLARE @cLottable11   NVARCHAR( 30)    
   DECLARE @cLottable12   NVARCHAR( 30)    
   DECLARE @dLottable13   DATETIME    
   DECLARE @dLottable14   DATETIME    
   DECLARE @dLottable15   DATETIME    
       
   DECLARE @cSQL        NVARCHAR( MAX)    
   DECLARE @cSQLParam   NVARCHAR( MAX)    
   DECLARE @cSelect     NVARCHAR( MAX)    
   DECLARE @cFrom       NVARCHAR( MAX)    
   DECLARE @cWhere1     NVARCHAR( MAX)    
   DECLARE @cWhere2     NVARCHAR( MAX)    
   DECLARE @cGroupBy    NVARCHAR( MAX)    
   DECLARE @cOrderBy    NVARCHAR( MAX)    
   DECLARE @cLong       NVARCHAR( 60) --(yeekung01)    
    
   SET @nTranCount = @@TRANCOUNT    
          
   /***********************************************************************************************    
                                                POPULATE    
   ***********************************************************************************************/    
   IF @cType = 'POPULATE-IN'    
   BEGIN    
      -- Get total tote    
      SELECT @nTotalTote = COUNT(1) FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID    
    
  -- Prepare next screen var    
  SET @cOutField01 = @cCartID    
  SET @cOutField02 = @cPickZone    
  SET @cOutField03 = '' -- LoadKey    
  SET @cOutField04 = '' -- Position    
  SET @cOutField05 = '' -- ToteID    
  SET @cOutField06 = CAST( @nTotalTote AS NVARCHAR(5))    
    
    EXEC rdt.rdtSetFocusField @nMobile, 5 -- ToteID    
    
  -- Go to totes screen    
  SET @nScn = 4183    
   END    
          
   /*    
   IF @cType = 'POPULATE-OUT'    
   BEGIN    
      -- Assigned          
      IF EXISTS( SELECT 1 FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID)    
      BEGIN    
         BEGIN TRAN    
         SAVE TRAN rdt_PTLCart_Assign    
             
         -- Loop assigned    
         DECLARE @curLog CURSOR    
         SET @curLog = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
            SELECT LoadKey     
            FROM rdt.rdtPTLCartLog WITH (NOLOCK)     
            WHERE CartID = @cCartID    
         OPEN @curLog    
         FETCH NEXT FROM @curLog INTO @cLoadKey    
         WHILE @@FETCH_STATUS = 0    
         BEGIN    
            -- Get TaskDetail    
            SET @cTaskDetailKey = ''    
            SELECT @cTaskDetailKey = TD.TaskDetailKey    
            FROM TaskDetail TD WITH (NOLOCK)    
               JOIN LOC WITH (NOLOCK) ON (TD.FromLOC = LOC.LOC)    
            WHERE LOC.Facility = @cFacility    
               AND TD.StorerKey = @cStorerKey    
               AND TD.TaskType = 'CPK'    
               AND TD.Status = '3'    
               AND TD.LoadKey = @cLoadKey    
    
            -- Update TaskDetail    
            IF @cTaskDetailKey <> ''    
            BEGIN    
               UPDATE TaskDetail SET    
                  Status = '0',    
                  UserKey = '',     
                  EditWho = SUSER_SNAME(),     
                  EditDate = GETDATE(),     
                  TrafficCop = NULL    
               WHERE TaskDetailKey = @cTaskDetailKey     
               IF @@ERROR <> ''    
               BEGIN    
                  SET @nErrNo = 181758    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo ,@cLangCode ,'DSP') --UPD Task Fail    
                  GOTO RollBackTran    
               END    
            END    
                
            FETCH NEXT FROM @curLog INTO @cLoadKey    
         END    
    
         COMMIT TRAN rdt_PTLCart_Assign    
  END    
  -- Go to cart screen    
   END    
   */    
    
    
   /***********************************************************************************************    
                                                 CHECK    
   ***********************************************************************************************/    
   IF @cType = 'CHECK'    
   BEGIN    
      DECLARE @cPickConfirmStatus NVARCHAR( 1)    
      SET @cPickConfirmStatus = rdt.rdt_PTLCart_GetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey, @cMethod)    
      IF @cPickConfirmStatus = '0'    
         SET @cPickConfirmStatus = '5'    
    
      IF @cPickConfirmStatus NOT IN ('3', '5')    
         SET @cPickConfirmStatus = '5'    
    
      -- Screen mapping    
      SET @cLoadKey = @cInField05    
      SET @cToteID = @cInField05    
    
      -- Get total tote    
      SELECT @nTotalTote = COUNT(1) FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID    
    
      -- Check finish assign    
      IF @nTotalTote > 0 AND @cToteID = ''    
      BEGIN    
         GOTO Quit    
      END    
    
      -- Check blank tote    
      IF @cToteID = ''    
      BEGIN    
         SET @nErrNo = 181751    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ToteID    
         EXEC rdt.rdtSetFocusField @nMobile, 5 -- ToteID    
         SET @cOutField05 = ''    
         GOTO Quit    
      END    
    
      IF NOT EXISTS(SELECT 1    
               FROM CODELKUP (NOLOCK)    
               WHERE LISTNAME='cartmethod'    
               AND code = @cMethod    
               AND storerkey = @cstorerkey    
               AND @cToteID BETWEEN Substring (long,1,10) and Substring (long,PATINDEX('%[-]%',long)+1,10)) --(yeekung01)    
      BEGIN    
         SET @nErrNo = 181759    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ToteID    
         EXEC rdt.rdtSetFocusField @nMobile, 5 -- ToteID    
         SET @cOutField05 = ''    
         GOTO Quit    
      END    
    
      -- Check tote assigned    
      IF EXISTS( SELECT 1    
         FROM rdt.rdtPTLCartLog WITH (NOLOCK)    
         WHERE CartID = @cCartID    
            AND ToteID = @cToteID)    
      BEGIN    
         SET @nErrNo = 181752    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote Assigned    
         EXEC rdt.rdtSetFocusField @nMobile, 5 -- ToteID    
         SET @cOutField05 = ''    
         GOTO Quit    
      END    
    
      -- Get cart final LOC    
      DECLARE @cFinalLOC NVARCHAR(10) = ''    
      IF @nTotalTote > 0    
      BEGIN    
         SELECT TOP 1 @cLoadKey = LoadKey FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID    
         SELECT TOP 1     
            @cFinalLOC = FinalLOC     
         FROM TaskDetail TD WITH (NOLOCK)     
            JOIN LOC WITH (NOLOCK) ON (TD.FromLOC = LOC.LOC)    
         WHERE LOC.Facility = @cFacility    
            AND TD.StorerKey = @cStorerKey    
            AND TD.TaskType = 'CPK'    
            -- AND TD.Status = '0'    
            AND TD.LoadKey = @cLoadKey    
      END    
    
      -- Check tote have task    
      /*    
      IF @cPickZone = ''    
         SELECT TOP 1     
            @cLoadKey = O.LoadKey    
         FROM TaskDetail TD WITH (NOLOCK)    
            JOIN LOC WITH (NOLOCK) ON (TD.FromLOC = LOC.LOC)    
            JOIN Orders O WITH (NOLOCK) ON (TD.LoadKey = O.LoadKey)    
         WHERE LOC.Facility = @cFacility    
            AND TD.StorerKey = @cStorerKey    
            AND TD.TaskType = 'CPK'    
            AND TD.Status = '0'    
         ORDER BY TD.Priority    
      ELSE    
         SELECT TOP 1     
            @cLoadKey = O.LoadKey    
         FROM TaskDetail TD WITH (NOLOCK)    
            JOIN LOC WITH (NOLOCK) ON (TD.FromLOC = LOC.LOC)    
            JOIN Orders O WITH (NOLOCK) ON (TD.LoadKey = O.LoadKey)    
       WHERE LOC.Facility = @cFacility    
            AND LOC.PickZone = @cPickZone    
            AND TD.StorerKey = @cStorerKey    
            AND TD.TaskType = 'CPK'    
            AND TD.Status = '0'    
         ORDER BY TD.Priority    
      */    
      SET @cLoadKey = ''    
      SET @cSQL =     
         ' SELECT TOP 1 ' +     
            ' @cLoadKey = O.LoadKey ' +     
         ' FROM TaskDetail TD WITH (NOLOCK) ' +     
            ' JOIN LOC WITH (NOLOCK) ON (TD.FromLOC = LOC.LOC) ' +     
            ' JOIN Orders O WITH (NOLOCK) ON (TD.LoadKey = O.LoadKey) ' +     
            ' JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey) ' +     
         ' WHERE LOC.Facility = @cFacility ' +     
            ' AND TD.StorerKey = @cStorerKey ' +     
            ' AND TD.TaskType = ''CPK'' ' +     
            ' AND PD.Status <> ''4'' ' +     
            ' AND PD.Status < @cPickConfirmStatus ' +     
            ' AND PD.QTY > 0 ' +     
            ' AND NOT EXISTS( ' +    
               ' SELECT TOP 1 1 ' +     
               ' FROM rdt.rdtPTLCartLog L WITH (NOLOCK) ' +    
               ' WHERE L.StorerKey = @cStorerKey ' +    
                  ' AND L.Method = @cMethod ' +    
                  ' AND L.LoadKey = O.LoadKey)' +    
            CASE WHEN @cPickZone = '' THEN '' ELSE ' AND LOC.PickZone = @cPickZone ' END +     
            CASE WHEN @cFinalLOC = '' THEN '' ELSE ' AND TD.FinalLOC = @cFinalLOC ' END +     
         -- (CL01)
         ' Group By O.LoadKey ' +
         -- ' ORDER BY TD.TaskDetailKey '    
         ' ORDER BY Max(TD.TaskDetailKey) '  
          -- (CL01)
      SET @cSQLParam =     
         '@cFacility  NVARCHAR( 5),  ' +     
         '@cStorerKey NVARCHAR( 15), ' +     
         '@cMethod    NVARCHAR( 1),  ' +    
         '@cPickZone  NVARCHAR( 10), ' +     
         '@cFinalLOC  NVARCHAR( 10), ' +    
         '@cPickConfirmStatus NVARCHAR( 1), ' +     
         '@cLoadKey   NVARCHAR( 10) OUTPUT '      
    
      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
         @cFacility, @cStorerKey, @cMethod, @cPickZone, @cFinalLOC, @cPickConfirmStatus, @cLoadKey OUTPUT     
    
      IF @cLoadKey = ''    
      BEGIN    
         SET @nErrNo = 181753    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote no task    
         EXEC rdt.rdtSetFocusField @nMobile, 5 -- ToteID    
         SET @cOutField05 = ''    
         GOTO Quit    
      END    
    
      IF EXISTS (SELECT 1    
         FROM  pickdetail PD WITH (NOLOCK)     
            JOIN Orders O WITH (NOLOCK) ON (PD.Orderkey = O.Orderkey)    
         WHERE O.StorerKey = @cStorerKey     
               AND PD.Dropid= @cToteID    
               AND PD.status < '5')    
      BEGIN    
         IF EXISTS (SELECT 1    
         FROM  pickdetail PD WITH (NOLOCK)     
            JOIN Orders O WITH (NOLOCK) ON (PD.Orderkey = O.Orderkey)    
         WHERE O.StorerKey = @cStorerKey     
               AND PD.Dropid= @cToteID    
               AND PD.status < '5'    
               AND O.LoadKey <> @cLoadKey)    
         BEGIN    
    
            SET @nErrNo = 181760    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LoadNotSorted    
            EXEC rdt.rdtSetFocusField @nMobile, 5 -- ToteID    
            SET @cOutField05 = ''    
            GOTO Quit    
         END    
      END    
       
          
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
         SET @nErrNo = 181754    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoMorePosition    
         EXEC rdt.rdtSetFocusField @nMobile, 5 -- ToteID    
         SET @cOutField05 = ''    
         GOTO Quit    
      END    
    
      DECLARE @cIPAddress NVARCHAR(40)    
      DECLARE @cLOC NVARCHAR(10)    
      DECLARE @cSKU NVARCHAR(20)    
      DECLARE @nQTY INT    
          
      -- Get position info    
      SELECT @cIPAddress = IPAddress    
      FROM DeviceProfile WITH (NOLOCK)    
      WHERE DeviceType = 'CART'    
         AND DeviceID = @cCartID    
         AND DevicePosition = @cPosition    
    
      BEGIN TRAN    
      SAVE TRAN rdt_PTLCart_Assign    
          
      -- Save assign    
     INSERT INTO rdt.rdtPTLCartLog (CartID, Position, ToteID, DeviceProfileLogKey, Method, PickZone, PickSeq, StorerKey, LoadKey)    
      VALUES (@cCartID, @cPosition, @cToteID, @cDPLKey, @cMethod, @cPickZone, @cPickSeq, @cStorerKey, @cLoadKey)    
      IF @@ERROR <> 0    
      BEGIN    
         SET @nErrNo = 181755    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log Fail    
         GOTO RollBackTran    
      END    
    
      -- Insert PTLTran    
      DECLARE @curPD CURSOR    
      IF @cPickZone = ''    
         SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
            SELECT PD.LOC, PD.SKU, SUM( PD.QTY)    
            FROM Orders O WITH (NOLOCK)    
               JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)    
            WHERE O.LoadKey = @cLoadKey    
               AND PD.Status <> '4'    
               AND PD.Status < @cPickConfirmStatus    
               AND PD.QTY > 0    
            GROUP BY PD.LOC, PD.SKU    
      ELSE    
         SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
            SELECT LOC.LOC, PD.SKU, SUM( PD.QTY)    
            FROM Orders O WITH (NOLOCK)    
               JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)    
               JOIN LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)    
            WHERE O.LoadKey = @cLoadKey    
               AND PD.Status <> '4'    
               AND PD.Status < @cPickConfirmStatus    
               AND PD.QTY > 0    
               AND LOC.PickZone = @cPickZone    
            GROUP BY LOC.LOC, PD.SKU    
          
      OPEN @curPD    
      FETCH NEXT FROM @curPD INTO @cLOC, @cSKU, @nQTY    
      WHILE @@FETCH_STATUS = 0    
      BEGIN    
         -- Get SKU info    
         SELECT @cLottableCode = LottableCode FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU    
             
         SET @cSelect = ''    
             
         -- Dynamic lottable    
         IF @cLottableCode <> ''    
            EXEC rdt.rdt_Lottable_GetNextSQL @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 4, @cLottableCode, 'LA',     
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,    
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,    
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,    
               @cSelect  OUTPUT,    
               @cWhere1  OUTPUT,    
               @cWhere2  OUTPUT,    
               @cGroupBy OUTPUT,    
               @cOrderBy OUTPUT,    
               @nErrNo   OUTPUT,    
               @cErrMsg  OUTPUT    
                
         -- By lottables    
         IF @cSelect <> ''    
         BEGIN    
            SET @cSQL =     
               ' INSERT INTO PTL.PTLTran ( ' +     
                  ' IPAddress, DeviceID, DevicePosition, Status, PTLType, ' +     
                  ' DeviceProfileLogKey, DropID, SourceKey, Storerkey, SKU, LOC, ExpectedQTY, QTY, ' + @cGroupBy + ') ' +     
               ' SELECT ' +     
                  ' @cIPAddress, @cCartID, @cPosition, ''0'', ''CART'', ' +     
                  ' @cDPLKey, '''', @cLoadKey, @cStorerKey, @cSKU, @cLOC, ISNULL( SUM( PD.QTY), 0), 0, ' + @cGroupBy +     
                  ' FROM Orders O WITH (NOLOCK) ' +     
                     ' JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey) ' +     
                     ' JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +     
                  ' WHERE O.LoadKey = @cLoadKey ' +         
                     ' AND PD.LOC = @cLOC ' +     
                     ' AND PD.SKU = @cSKU ' +     
                     ' AND PD.Status < ''4''' +     
                     ' AND PD.QTY > 0' +     
                     ' AND O.Status <> ''CANC''' +     
                     ' AND O.SOStatus <> ''CANC''' +     
                  ' GROUP BY ' + @cGroupBy +     
                  ' ORDER BY ' + @cOrderBy     
    
            SET @cSQLParam =     
      '@cIPAddress  NVARCHAR( 40), ' +     
               '@cCartID     NVARCHAR( 10), ' +     
               '@cPosition   NVARCHAR( 10), ' +     
               '@cDPLKey     NVARCHAR( 10), ' +     
               '@cLoadKey    NVARCHAR( 10), ' +      
               '@cLOC        NVARCHAR( 10), ' +      
               '@cStorerKey  NVARCHAR( 15), ' +      
               '@cSKU        NVARCHAR( 20)  '    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
               @cIPAddress, @cCartID, @cPosition, @cDPLKey, @cLoadKey, @cLOC, @cStorerKey, @cSKU    
         END    
         ELSE    
         BEGIN    
            INSERT INTO PTL.PTLTran (    
               IPAddress, DeviceID, DevicePosition, Status, PTLType,     
               DeviceProfileLogKey, DropID, SourceKey, Storerkey, SKU, LOC, ExpectedQTY, QTY)    
            VALUES (    
               @cIPAddress, @cCartID, @cPosition, '0', 'CART',    
               @cDPLKey, '', @cLoadKey, @cStorerKey, @cSKU, @cLOC, @nQTY, 0)    
            IF @@ERROR <> ''    
            BEGIN    
               SET @nErrNo = 181756    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo ,@cLangCode ,'DSP') --INS PTL Fail    
               GOTO RollBackTran    
            END    
         END    
             
         FETCH NEXT FROM @curPD INTO @cLOC, @cSKU, @nQTY    
      END    
    
      /*    
      -- Update TaskDetail    
      DECLARE @curTD CURSOR    
      SET @curTD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
         SELECT TD.TaskDetailKey    
         FROM TaskDetail TD WITH (NOLOCK)    
            JOIN LOC WITH (NOLOCK) ON (TD.FromLOC = LOC.LOC)    
         WHERE LOC.Facility = @cFacility    
            AND TD.StorerKey = @cStorerKey    
            AND TD.TaskType = 'CPK'    
            AND TD.Status = '0'    
            AND TD.LoadKey = @cLoadKey    
      OPEN @curTD    
      FETCH NEXT FROM @curTD INTO @cTaskDetailKey    
      WHILE @@FETCH_STATUS = 0    
      BEGIN    
         UPDATE TaskDetail SET    
            Status = '3',    
            StartTime = GETDATE(),    
            UserKey = SUSER_SNAME(),     
            EditWho = SUSER_SNAME(),     
            EditDate = GETDATE(),     
            TrafficCop = NULL    
         WHERE TaskDetailKey  = @cTaskDetailKey     
         IF @@ERROR <> ''    
         BEGIN    
            SET @nErrNo = 181757    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo ,@cLangCode ,'DSP') --UPD Task Fail    
            GOTO RollBackTran    
         END    
         FETCH NEXT FROM @curTD INTO @cTaskDetailKey    
      END    
      */    
          
      COMMIT TRAN rdt_PTLCart_Assign    
    
      SET @nTotalTote = @nTotalTote + 1    
    
      -- Prepare current screen var    
      SET @cOutField03 = ''     
      SET @cOutField04 = @cPosition    
      SET @cOutField05 = '' -- ToteID    
      SET @cOutField06 = CAST( @nTotalTote AS NVARCHAR(5))    
          
      -- Stay in current page    
      SET @nErrNo = -1     
   END    
    
   GOTO Quit    
    
RollBackTran:    
   ROLLBACK TRAN rdt_PTLCart_Assign    
Quit:    
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
      COMMIT TRAN    
END 

GO
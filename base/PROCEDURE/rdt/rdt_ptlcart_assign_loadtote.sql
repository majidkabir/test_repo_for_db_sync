SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_PTLCart_Assign_LoadTote                               */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 19-10-2017 1.0  Ung      WMS-3250 Created                                  */
/* 26-01-2018 1.1  Ung      Change to PTL.Schema                              */
/* 01-06-2023 1.2  Ung      WMS-22464 Add dynamic lottable                    */
/*                          Add PickConfirmStatus                             */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_PTLCart_Assign_LoadTote] (
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

   DECLARE @cSQL        NVARCHAR( MAX)
   DECLARE @cSQLParam   NVARCHAR( MAX)
   DECLARE @nTranCount  INT
   DECLARE @nTotalTote  INT

   DECLARE @cLoadKey       NVARCHAR( 10)
   DECLARE @cPosition      NVARCHAR( 10)
   DECLARE @cToteID        NVARCHAR( 20)
   DECLARE @cPickConfirmStatus NVARCHAR( 1)  

   DECLARE @cLottableCode  NVARCHAR( 30)
   DECLARE @cLottable01    NVARCHAR( 18)
   DECLARE @cLottable02    NVARCHAR( 18)
   DECLARE @cLottable03    NVARCHAR( 18)
   DECLARE @dLottable04    DATETIME
   DECLARE @dLottable05    DATETIME
   DECLARE @cLottable06    NVARCHAR( 30)
   DECLARE @cLottable07    NVARCHAR( 30)
   DECLARE @cLottable08    NVARCHAR( 30)
   DECLARE @cLottable09    NVARCHAR( 30)
   DECLARE @cLottable10    NVARCHAR( 30)
   DECLARE @cLottable11    NVARCHAR( 30)
   DECLARE @cLottable12    NVARCHAR( 30)
   DECLARE @dLottable13    DATETIME
   DECLARE @dLottable14    DATETIME
   DECLARE @dLottable15    DATETIME
   
   DECLARE @cSelect        NVARCHAR( MAX)
   DECLARE @cFrom          NVARCHAR( MAX)
   DECLARE @cWhere1        NVARCHAR( MAX)
   DECLARE @cWhere2        NVARCHAR( MAX)
   DECLARE @cGroupBy       NVARCHAR( MAX)
   DECLARE @cOrderBy       NVARCHAR( MAX)

   SET @nTranCount = @@TRANCOUNT
      
   /***********************************************************************************************
                                                POPULATE
   ***********************************************************************************************/
   IF @cType = 'POPULATE-IN'
   BEGIN
      -- Get total
      SELECT @nTotalTote = COUNT(1) FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID

		-- Prepare next screen var
		SET @cOutField01 = @cCartID
		SET @cOutField02 = @cPickZone
		SET @cOutField03 = '' -- LoadKey
		SET @cOutField04 = '' -- Position
		SET @cOutField05 = '' -- ToteID
		SET @cOutField06 = CAST( @nTotalTote AS NVARCHAR(5)) --TotalTote

	   EXEC rdt.rdtSetFocusField @nMobile, 3 -- LoadKey

		-- Go to LoadKey, pos, tote screen
		SET @nScn = 5040
   END      

   /*   
   IF @cType = 'POPULATE-OUT'
   BEGIN
		-- Go to cart screen
   END
   */

   /***********************************************************************************************
                                                 CHECK
   ***********************************************************************************************/
   IF @cType = 'CHECK'
   BEGIN
      -- Screen mapping
      SET @cLoadKey = @cInField03
      SET @cPosition = @cOutField04
      SET @cToteID = @cInField05

      -- Get total
      SELECT @nTotalTote = COUNT(1) FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID

      -- Check finish assign
      IF @nTotalTote > 0 AND @cLoadKey = '' AND @cToteID = ''
      BEGIN
         GOTO Quit
      END
      
      -- Check blank
		IF @cLoadKey = '' 
      BEGIN
         SET @nErrNo = 115951
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need LoadKey
         EXEC rdt.rdtSetFocusField @nMobile, 3 -- LoadKey
         GOTO Quit
      END
      
      -- Check LoadKey valid
      IF NOT EXISTS( SELECT 1 FROM LoadPlanDetail WITH (NOLOCK) WHERE LoadKey = @cLoadKey)
      BEGIN
         SET @nErrNo = 115952
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad LoadKey
         EXEC rdt.rdtSetFocusField @nMobile, 3 -- LoadKey
         SET @cOutField03 = ''
         GOTO Quit
      END
      
      -- Check LoadKey assigned
      IF @cPickZone = ''
         SELECT @nErrNo = 1
         FROM rdt.rdtPTLCartLog WITH (NOLOCK)
         WHERE LoadKey = @cLoadKey
      ELSE
         SELECT @nErrNo = 1
         FROM rdt.rdtPTLCartLog WITH (NOLOCK)
         WHERE LoadKey = @cLoadKey
            AND (PickZone = @cPickZone OR PickZone = '')
      IF @nErrNo <> 0
      BEGIN
         SET @nErrNo = 115953
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Load Assigned
         EXEC rdt.rdtSetFocusField @nMobile, 3 -- LoadKey
         SET @cOutField03 = ''
         GOTO Quit
      END

      -- Storer configure (method level)
      SET @cPickConfirmStatus = rdt.rdt_PTLCart_GetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey, @cMethod)  
      IF @cPickConfirmStatus = '0'
         SET @cPickConfirmStatus = '5'

      -- Check load in Zone
      SET @nErrNo = 1
      IF @cPickZone = '' 
         SELECT TOP 1 @nErrNo = 0
         FROM LoadPlanDetail LPD WITH (NOLOCK) 
            JOIN Orders O WITH (NOLOCK) ON (LPD.OrderKey = O.OrderKey)
            JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
         WHERE LPD.Loadkey = @cLoadKey
            AND PD.Status <> '4'
            AND PD.Status < @cPickConfirmStatus
            AND PD.QTY > 0
            AND O.Status <> 'CANC' 
            AND O.SOStatus <> 'CANC'
      ELSE
         SELECT TOP 1 @nErrNo = 0
         FROM LoadPlanDetail LPD WITH (NOLOCK) 
            JOIN Orders O WITH (NOLOCK) ON (LPD.OrderKey = O.OrderKey)
            JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
            JOIN LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
         WHERE LPD.Loadkey = @cLoadKey
            AND PD.Status <> '4'
            AND PD.Status < @cPickConfirmStatus
            AND PD.QTY > 0
            AND O.Status <> 'CANC' 
            AND O.SOStatus <> 'CANC'
            AND LOC.PickZone = @cPickZone
      
      IF @nErrNo <> 0
      BEGIN
         SET @nErrNo = 115954
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LoadNoPickTask
         EXEC rdt.rdtSetFocusField @nMobile, 3 -- LoadKey
         SET @cOutField03 = ''
         GOTO Quit
      END
      SET @cOutField03 = @cLoadKey
      
      -- Get position not yet assign
      IF @cPosition = ''
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
         SET @nErrNo = 115955
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoMorePosition
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- Position
         SET @cOutField04 = ''
         GOTO Quit
      END
      SET @cOutField04 = @cPosition

      -- Check blank tote
      IF @cToteID = ''
      BEGIN
         SET @nErrNo = 115956
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ToteID
         EXEC rdt.rdtSetFocusField @nMobile, 5 -- ToteID
         SET @cOutField05 = ''
         GOTO Quit
      END
      
      -- Check format
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'ToteID', @cToteID) = 0
      BEGIN
         SET @nErrNo = 115960
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
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
         SET @nErrNo = 115957
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote Assigned
         EXEC rdt.rdtSetFocusField @nMobile, 5 -- ToteID
         SET @cOutField05 = ''
         GOTO Quit
      END
      SET @cOutField05 = @cToteID
      
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
      INSERT INTO rdt.rdtPTLCartLog (CartID, Position, ToteID, DeviceProfileLogKey, Method, PickZone, PickSeq, LoadKey, StorerKey)
      VALUES (@cCartID, @cPosition, @cToteID, @cDPLKey, @cMethod, @cPickZone, @cPickSeq, @cLoadKey, @cStorerKey)
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 115958
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log Fail
         GOTO RollBackTran
      END

      -- Insert PTLTran
      DECLARE @curPD CURSOR
      IF @cPickZone = ''
         SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT PD.LOC, PD.SKU, SUM( PD.QTY)
            FROM LoadPlanDetail LPD WITH (NOLOCK) 
               JOIN Orders O WITH (NOLOCK) ON (LPD.OrderKey = O.OrderKey)
               JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
            WHERE LPD.Loadkey = @cLoadKey
               AND PD.Status <> '4'
               AND PD.Status < @cPickConfirmStatus
               AND PD.QTY > 0
               AND O.Status <> 'CANC' 
               AND O.SOStatus <> 'CANC'
            GROUP BY PD.LOC, PD.SKU
      ELSE
         SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT LOC.LOC, PD.SKU, SUM( PD.QTY)
            FROM LoadPlanDetail LPD WITH (NOLOCK) 
               JOIN Orders O WITH (NOLOCK) ON (LPD.OrderKey = O.OrderKey)
               JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
               JOIN LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            WHERE LPD.Loadkey = @cLoadKey
               AND PD.Status <> '4'               
               AND PD.Status < @cPickConfirmStatus
               AND PD.QTY > 0
               AND O.Status <> 'CANC' 
               AND O.SOStatus <> 'CANC'
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
                  ' FROM LoadPlanDetail LPD WITH (NOLOCK) ' + 
                     ' JOIN Orders O WITH (NOLOCK) ON (LPD.OrderKey = O.OrderKey) ' + 
                     ' JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey) ' + 
                     ' JOIN LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC) ' + 
                     ' JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' + 
                  ' WHERE LPD.Loadkey = @cLoadKey ' + 
                     ' AND PD.LOC = @cLOC ' + 
                     ' AND PD.SKU = @cSKU ' + 
                     ' AND PD.Status <> ''4'' ' + 
                     ' AND PD.Status < @cPickConfirmStatus ' + 
                     ' AND PD.QTY > 0' + 
                     ' AND O.Status <> ''CANC''' + 
                     ' AND O.SOStatus <> ''CANC''' + 
                     CASE WHEN @cPickZone = '' THEN '' ELSE ' AND LOC.PickZone = @cPickZone ' END + 
                  ' GROUP BY ' + @cGroupBy + 
                  ' ORDER BY ' + @cOrderBy 

            SET @cSQLParam = 
               '@cIPAddress  NVARCHAR( 40),  ' + 
               '@cCartID     NVARCHAR( 10),  ' + 
               '@cPosition   NVARCHAR( 10),  ' + 
               '@cDPLKey     NVARCHAR( 10),  ' + 
               '@cPickZone   NVARCHAR( 10),  ' +  
               '@cLoadKey    NVARCHAR( 10),  ' +  
               '@cLOC        NVARCHAR( 10),  ' +  
               '@cStorerKey  NVARCHAR( 15),  ' +  
               '@cSKU        NVARCHAR( 20),  ' +
               '@cGroupBy    NVARCHAR( MAX), ' +
               '@cPickConfirmStatus NVARCHAR( 1) ' 

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 
               @cIPAddress, @cCartID, @cPosition, @cDPLKey, @cPickZone, @cLoadKey, @cLOC, @cStorerKey, @cSKU, @cGroupBy, @cPickConfirmStatus
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
               SET @nErrNo = 115959
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo ,@cLangCode ,'DSP') --INS PTL Fail
               GOTO RollBackTran
            END
         END

         FETCH NEXT FROM @curPD INTO @cLOC, @cSKU, @nQTY
      END

      COMMIT TRAN rdt_PTLCart_Assign

      SET @nTotalTote = @nTotalTote + 1

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
      
      -- Prepare current screen var
      SET @cOutField03 = '' -- LoadKey
      SET @cOutField04 = @cPosition
      SET @cOutField05 = '' -- ToteID
      SET @cOutField06 = CAST( @nTotalTote AS NVARCHAR(5)) --TotalTote
      
      EXEC rdt.rdtSetFocusField @nMobile, 3 -- LoadKey
      
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
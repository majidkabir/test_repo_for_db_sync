SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Store procedure: rdt_PTLPiece_Assign_Wave                                  */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 22-04-2021 1.0  yeekung  WMS-16875 Created                                 */
/* 20-07-2023 1.1  yeekung  WMS-23039 Add order by orderkey (yeekung01)       */
/* 25-09-2023 1.2  YeeKung  WMS-23257 Add assignextupd (yeekung02)            */  
/******************************************************************************/

CREATE   PROC [RDT].[rdt_PTLPiece_Assign_Wave] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT,
   @nInputKey        INT,
   @cFacility        NVARCHAR( 5),
   @cStorerKey       NVARCHAR( 15),
   @cStation         NVARCHAR( 10),
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

   DECLARE @cSQL           NVARCHAR(MAX)
   DECLARE @cSQLParam      NVARCHAR(MAX)
   DECLARE @nTranCount     INT
   DECLARE @cIPAddress     NVARCHAR(40)
   DECLARE @cPosition      NVARCHAR(10)
   DECLARE @tVar           VariableTable

   DECLARE @cDynamicSlot   NVARCHAR( 1)
   DECLARE @cWaveKey       NVARCHAR(10)
   DECLARE @cOrderKey      NVARCHAR(10)
   DECLARE @cCartonID      NVARCHAR(20)
   DECLARE @nTotalOrder    INT
   DECLARE @nTotalCarton   INT
   DECLARE @cCurrentSP NVARCHAR( 60)

   SET @nTranCount = @@TRANCOUNT

   -- Storer configure
   SET @cDynamicSlot = rdt.RDTGetConfig( @nFunc, 'DynamicSlot', @cStorerKey)
   DECLARE @cAssignExtUpdSP NVARCHAR( 20) --(yeekung01)
   SET @cAssignExtUpdSP = rdt.rdt_PTLPiece_GetConfig( @nFunc, 'AssignExtUpdSP', @cStorerKey, @cMethod)
   IF @cAssignExtUpdSP = '0'
      SET @cAssignExtUpdSP = ''

   /***********************************************************************************************
                                                POPULATE
   ***********************************************************************************************/
   IF @cType = 'POPULATE-IN'
   BEGIN
      IF @cAssignExtUpdSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = TRIM(@cAssignExtUpdSP) AND type = 'P')
         BEGIN
            SET @cCurrentSP = OBJECT_NAME( @@PROCID)

            INSERT INTO @tVar (Variable, Value) VALUES
               ('@cType',@cType),
               ('@cBatchKey',    @cWaveKey)

            SET @cSQL = 'EXEC rdt.' + TRIM( @cAssignExtUpdSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cStation, @cMethod, @cCurrentSP, @tVar, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               ' @nMobile     INT,           ' +
               ' @nFunc       INT,           ' +
               ' @cLangCode   NVARCHAR( 3),  ' +
               ' @nStep       INT,           ' +
               ' @nInputKey   INT,           ' +
               ' @cFacility   NVARCHAR( 5) , ' +
               ' @cStorerKey  NVARCHAR( 10), ' +
               ' @cStation    NVARCHAR( 10),  ' +
               ' @cMethod     NVARCHAR( 15), ' +
               ' @cCurrentSP  NVARCHAR( 60),  ' +
               ' @tVar        VariableTable READONLY, ' +
               ' @nErrNo      INT           OUTPUT, ' +
               ' @cErrMsg     NVARCHAR(250) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cStation, @cMethod, @cCurrentSP, @tVar,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Get assign info
      SET @cWaveKey = ''
      SELECT @cWaveKey = WaveKey
      FROM rdt.rdtPTLPieceLog WITH (NOLOCK)
      WHERE Station = @cStation

		-- Prepare next screen var
		SET @cOutField01 = @cWaveKey


      IF @cWaveKey = ''
      BEGIN
         -- Enable disable field
         SET @cFieldAttr01 = ''  -- WaveKey
         SET @cFieldAttr04 = 'O' -- CartonID

   	   EXEC rdt.rdtSetFocusField @nMobile, 1 -- WaveKey
      END


		-- Go to wave, carton screen
		SET @nScn = 4607
   END

   IF @cType = 'POPULATE-OUT'
   BEGIN
      SET @cFieldAttr01 = '' -- WaveKey
      IF @cAssignExtUpdSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = TRIM(@cAssignExtUpdSP) AND type = 'P')
         BEGIN
            SET @cCurrentSP = OBJECT_NAME( @@PROCID)

            INSERT INTO @tVar (Variable, Value) VALUES
               ('@cType',@cType),
               ('@cBatchKey',    @cWaveKey)

            SET @cSQL = 'EXEC rdt.' + TRIM( @cAssignExtUpdSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cStation, @cMethod, @cCurrentSP, @tVar, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               ' @nMobile     INT,           ' +
               ' @nFunc       INT,           ' +
               ' @cLangCode   NVARCHAR( 3),  ' +
               ' @nStep       INT,           ' +
               ' @nInputKey   INT,           ' +
               ' @cFacility   NVARCHAR( 5) , ' +
               ' @cStorerKey  NVARCHAR( 10), ' +
               ' @cStation    NVARCHAR( 10),  ' +
               ' @cMethod     NVARCHAR( 15), ' +
               ' @cCurrentSP  NVARCHAR( 60),  ' +
               ' @tVar        VariableTable READONLY, ' +
               ' @nErrNo      INT           OUTPUT, ' +
               ' @cErrMsg     NVARCHAR(250) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cStation, @cMethod, @cCurrentSP, @tVar,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END
   END

   /***********************************************************************************************
                                                 CHECK
   ***********************************************************************************************/
   IF @cType = 'CHECK'
   BEGIN
      -- Screen mapping
      SET @cWaveKey = CASE WHEN @cFieldAttr01 = '' THEN @cInField01 ELSE @cOutField01 END

      -- WaveKey enable
      IF @cFieldAttr01 = ''
      BEGIN
   		-- Check blank
   		IF @cWaveKey = ''
         BEGIN
            SET @nErrNo = 168101
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need WaveKey
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- WaveKey
            GOTO Quit
         END

         -- Check wave valid
         IF NOT EXISTS( SELECT 1 FROM WaveDetail WITH (NOLOCK) WHERE WaveKey = @cWaveKey)
         BEGIN
            SET @nErrNo = 168102
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Wave
            SET @cOutField01 = ''
            GOTO Quit
         END

         -- Check wave assigned
         IF EXISTS( SELECT 1
            FROM rdt.rdtPTLPieceLog WITH (NOLOCK)
            WHERE Station <> @cStation
               AND WaveKey = @cWaveKey)
         BEGIN
            SET @nErrNo = 168103
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Wave assigned
            SET @cOutField01 = ''
            GOTO Quit
         END

         -- Check wave belong to login storer
         IF EXISTS( SELECT 1
            FROM WaveDetail WD WITH (NOLOCK)
               JOIN Orders O WITH (NOLOCK) ON (O.OrderKey = WD.OrderKey)
            WHERE WD.WaveKey = @cWaveKey
               AND O.StorerKey <> @cStorerKey)
         BEGIN
            SET @nErrNo = 168104
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff Storer
            SET @cOutField01 = ''
            GOTO Quit
         END

         -- Check multi wave assigned
         DECLARE @cOtherWaveKey NVARCHAR( 10) = ''
         SELECT TOP 1 
            @cOtherWaveKey = WaveKey
         FROM rdt.rdtPTLPieceLog WITH (NOLOCK)
         WHERE Station = @cStation
            AND WaveKey <> ''
            AND WaveKey <> @cWaveKey
         IF @cOtherWaveKey <> ''
         BEGIN
            SET @nErrNo = 168109
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiWaveAssgn --AssgnedWav XXX
            SET @cOutField01 = ''
            GOTO Quit
         END

         -- Check pick not completed
         IF rdt.RDTGetConfig( @nFunc, 'CheckPickCompleted', @cStorerKey) = '1'
         BEGIN
            IF EXISTS( SELECT 1
               FROM WaveDetail WD WITH (NOLOCK)
                  JOIN Orders O WITH (NOLOCK) ON (O.OrderKey = WD.OrderKey)
                  JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
               WHERE WD.WaveKey = @cWaveKey
                  AND PD.Status IN ('0', '4')
                  AND PD.QTY > 0)
            BEGIN
               SET @nErrNo = 168105
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pick NotFinish
               SET @cOutField01 = ''
               GOTO Quit
            END
         END

         -- Save assign
         UPDATE rdt.rdtMobRec SET
            V_WaveKey = @cWaveKey,
            EditDate = GETDATE()
         WHERE Mobile = @nMobile
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 168106
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Log fail
            GOTO Quit
         END

         -- Get station info
         DECLARE @nTotalPos INT
         SELECT @nTotalPos = COUNT(1)
         FROM DeviceProfile WITH (NOLOCK)
         WHERE DeviceType = 'STATION'
            AND DeviceID = @cStation

         -- Get total orders
         SELECT @nTotalOrder = COUNT( DISTINCT O.OrderKey)
         FROM WaveDetail WD WITH (NOLOCK)
            JOIN Orders O WITH (NOLOCK) ON (O.OrderKey = WD.OrderKey)
            JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
         WHERE WD.WaveKey = @cWaveKey
            AND PD.QTY > 0
            AND PD.Status <> '4'
            AND O.Status <> 'CANC'
            AND O.SOStatus <> 'CANC'

         -- Check order fit in station
         IF @nTotalOrder > @nTotalPos
         BEGIN
            SET @nErrNo = 168107
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not enuf Pos
            SET @cOutField01 = ''
            GOTO Quit
         END

         -- Handling transaction
         BEGIN TRAN  -- Begin our own transaction
         SAVE TRAN rdt_PTLPiece_Assign -- For rollback or commit only our own transaction

         -- Loop orders
         DECLARE @cPreassignPos NVARCHAR(10)
         DECLARE @curOrder CURSOR
         SET @curOrder = CURSOR FOR
            SELECT DISTINCT O.OrderKey
            FROM WaveDetail WD WITH (NOLOCK)
               JOIN Orders O WITH (NOLOCK) ON (O.OrderKey = WD.OrderKey)
               JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
            WHERE WD.WaveKey = @cWaveKey
               AND PD.QTY > 0
               AND PD.Status <> '4'
               AND O.Status <> 'CANC'
               AND O.SOStatus <> 'CANC'
            ORDER BY O.OrderKey --(yeekung01)
         OPEN @curOrder
         FETCH NEXT FROM @curOrder INTO @cOrderKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            -- Order not yet assign
            IF NOT EXISTS( SELECT 1
               FROM rdt.rdtPTLPieceLog WITH (NOLOCK)
               WHERE OrderKey = @cOrderKey)
            BEGIN
               -- Get position not yet assign
               SET @cIPAddress = ''
               SET @cPosition = ''
               SELECT TOP 1
                  @cIPAddress = DP.IPAddress,
                  @cPosition = DP.DevicePosition
               FROM dbo.DeviceProfile DP WITH (NOLOCK)
               WHERE DP.DeviceType = 'STATION'
                  AND DP.DeviceID = @cStation
                  AND NOT EXISTS( SELECT 1
                     FROM rdt.rdtPTLPieceLog Log WITH (NOLOCK)
                     WHERE Log.Station = @cStation
                        AND Log.Position = DP.DevicePosition)
               ORDER BY DP.LogicalPos, DP.DevicePosition

               -- Save assign
               INSERT rdt.rdtPTLPieceLog (Station, IPAddress, Position, WaveKey, OrderKey)
               VALUES (@cStation, @cIPAddress, @cPosition, @cWaveKey, @cOrderKey)
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 168108
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log fail
                  GOTO RollBackTran
               END
            END

            FETCH NEXT FROM @curOrder INTO @cOrderKey
         END

         COMMIT TRAN rdt_PTLPiece_Assign

         -- Get carton not yet assign
         SET @cOrderKey = ''
         SET @cPosition = ''
         SELECT TOP 1
            @cOrderKey = OrderKey,
            @cPosition = Position,
            @cCartonID = ''
         FROM rdt.rdtPTLPieceLog WITH (NOLOCK)
         WHERE Station = @cStation
            AND CartonID = ''
         ORDER BY RowRef

         SET @cFieldAttr01 = '' -- BatchKey

         GOTO Quit
      END

      -- Enable field
      SET @cFieldAttr01 = '' -- WaveKey
   END
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_PTLPiece_Assign

Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN

END

GO
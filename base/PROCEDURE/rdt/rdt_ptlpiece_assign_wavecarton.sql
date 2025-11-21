SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_PTLPiece_Assign_WaveCarton                            */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 26-04-2016 1.0  Ung      SOS370123 Created                                 */
/* 29-11-2017 1.1  Ung      WMS-3568 Add assign order                         */
/* 05-03-2018 1.2  Ung      WMS-3788 Add AssignExtValSP                       */
/* 25-11-2020 1.3  YeeKung  WMS-15702 Add AssignExtValSP(yeekung01)           */
/* 08-09-2020 1.4  YeeKung  WMS-17823 Add AssignExtValSP(yeekung02)           */
/* 12-09-2023 1.5  Ung      WMS-23635 Add LOC                                 */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_PTLPiece_Assign_WaveCarton] (
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
   DECLARE @cLOC           NVARCHAR(10)
   DECLARE @tVar           VariableTable

   DECLARE @cDynamicSlot   NVARCHAR( 1)
   DECLARE @cWaveKey       NVARCHAR(10)
   DECLARE @cOrderKey      NVARCHAR(10)
   DECLARE @cCartonID      NVARCHAR(20)
   DECLARE @nTotalOrder    INT
   DECLARE @nTotalCarton   INT
   DECLARE @cCurrentSP NVARCHAR( 60)
   DECLARE @cExtendedinfo NVARCHAR(20)

   SET @nTranCount = @@TRANCOUNT

   -- Storer configure
   SET @cDynamicSlot = rdt.RDTGetConfig( @nFunc, 'DynamicSlot', @cStorerKey)

   DECLARE @cAssignExtValSP NVARCHAR( 20)
   SET @cAssignExtValSP = rdt.RDTGetConfig( @nFunc, 'AssignExtValSP', @cStorerKey)
   IF @cAssignExtValSP = '0'
      SET @cAssignExtValSP = ''

   DECLARE @cAssignExtinfoSP NVARCHAR( 20)
   SET @cAssignExtinfoSP = rdt.RDTGetConfig( @nFunc, 'AssignExtinfoSP', @cStorerKey)
   IF @cAssignExtinfoSP = '0'
      SET @cAssignExtinfoSP = ''

   /***********************************************************************************************
                                                POPULATE
   ***********************************************************************************************/
   IF @cType = 'POPULATE-IN'
   BEGIN
      -- Get assign info
      SET @cWaveKey = ''
      SELECT @cWaveKey = WaveKey
      FROM rdt.rdtPTLPieceLog WITH (NOLOCK)
      WHERE Station = @cStation

      SELECT @nTotalOrder = COUNT(1) FROM rdt.rdtPTLPieceLog WITH (NOLOCK) WHERE Station = @cStation
      SELECT @nTotalCarton = COUNT(1) FROM rdt.rdtPTLPieceLog WITH (NOLOCK) WHERE Station = @cStation AND CartonID <> ''

      -- Prepare next screen var
      SET @cOutField01 = @cWaveKey
      SET @cOutField02 = '' -- OrderKey
      SET @cOutField03 = '' -- Position
      SET @cOutField04 = '' -- CartonID
      SET @cOutField05 = CAST( @nTotalOrder AS NVARCHAR(5))
      SET @cOutField06 = CAST( @nTotalCarton AS NVARCHAR(5))

      IF @cWaveKey = ''
      BEGIN
         -- Enable disable field
         SET @cFieldAttr01 = ''  -- WaveKey
         SET @cFieldAttr04 = 'O' -- CartonID

       EXEC rdt.rdtSetFocusField @nMobile, 1 -- WaveKey
      END
      ELSE
      BEGIN
         SET @cFieldAttr01 = 'O' -- WaveKey
         SET @cFieldAttr04 = ''  -- CartonID

         IF @nTotalOrder > @nTotalCarton
         BEGIN
            -- Get carton not yet assign
            SELECT TOP 1
               @cOrderKey = OrderKey,
               @cPosition = Position
            FROM rdt.rdtPTLPieceLog WITH (NOLOCK)
            WHERE Station = @cStation
               AND CartonID = ''
            ORDER BY RowRef

        -- Prepare next screen var
        SET @cOutField02 = @cOrderKey
        SET @cOutField03 = @cPosition
         END
      END

      IF @cAssignExtinfoSP <> '' --(yeekung01)
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cAssignExtinfoSP AND type = 'P')
         BEGIN
            SET @cCurrentSP = OBJECT_NAME( @@PROCID)
            INSERT INTO @tVar (Variable, Value) VALUES
               ('@cWaveKey',     @cWaveKey),
               ('@cOrderKey',    @cOrderKey),
               ('@cPosition',    @cPosition),
               ('@cCartonID',    @cCartonID),
               ('@cOption'  ,    @cInField01)

            SET @cSQL = 'EXEC rdt.' + RTRIM( @cAssignExtinfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cStation, @cMethod, @cCurrentSP, @tVar,' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT,@cExtendedinfo OUTPUT,@cType  '
            SET @cSQLParam =
               ' @nMobile     INT,           ' +
               ' @nFunc       INT,           ' +
               ' @cLangCode   NVARCHAR( 3),  ' +
               ' @nStep       INT,           ' +
               ' @nInputKey   INT,           ' +
               ' @cFacility   NVARCHAR( 5) , ' +
               ' @cStorerKey  NVARCHAR( 10), ' +
               ' @cStation    NVARCHAR( 1),  ' +
               ' @cMethod     NVARCHAR( 15), ' +
               ' @cCurrentSP  NVARCHAR( 60),  ' +
               ' @tVar        VariableTable READONLY, ' +
               ' @nErrNo      INT           OUTPUT, ' +
               ' @cErrMsg     NVARCHAR(250) OUTPUT,  '+
               ' @cExtendedinfo NVARCHAR(20) OUTPUT,  '+
               ' @cType       NVARCHAR( 15)'

           EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cStation, @cMethod, @cCurrentSP, @tVar,
               @nErrNo OUTPUT, @cErrMsg OUTPUT,@cExtendedinfo OUTPUT,@cType

            IF @nErrNo <> 0
               GOTO Quit

            SET @cOutField07=@cExtendedinfo
         END
      END

      -- Go to wave, carton screen
      SET @nScn = 4601
   END

   IF @cType = 'POPULATE-OUT'
   BEGIN
      IF @cAssignExtValSP <> '' --(yeekung01)
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cAssignExtValSP AND type = 'P')
         BEGIN
            SET @cCurrentSP = OBJECT_NAME( @@PROCID)
            INSERT INTO @tVar (Variable, Value) VALUES
               ('@cWaveKey',     @cWaveKey),
               ('@cOrderKey',    @cOrderKey),
               ('@cPosition',    @cPosition),
               ('@cCartonID',    @cCartonID),
               ('@cOption'  ,    @cInField01)

            SET @cSQL = 'EXEC rdt.' + RTRIM( @cAssignExtValSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cStation, @cMethod, @cCurrentSP, @tVar,' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT,@cType  '
            SET @cSQLParam =
               ' @nMobile     INT,           ' +
               ' @nFunc       INT,           ' +
               ' @cLangCode   NVARCHAR( 3),  ' +
               ' @nStep       INT,           ' +
               ' @nInputKey   INT,           ' +
               ' @cFacility   NVARCHAR( 5) , ' +
               ' @cStorerKey  NVARCHAR( 10), ' +
               ' @cStation    NVARCHAR( 1),  ' +
               ' @cMethod     NVARCHAR( 15), ' +
               ' @cCurrentSP  NVARCHAR( 60),  ' +
               ' @tVar        VariableTable READONLY, ' +
               ' @nErrNo      INT           OUTPUT, ' +
               ' @cErrMsg     NVARCHAR(250) OUTPUT,  '+
               ' @cType       NVARCHAR( 15)'

           EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cStation, @cMethod, @cCurrentSP, @tVar,
               @nErrNo OUTPUT, @cErrMsg OUTPUT,@cType

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      SET @cFieldAttr01 = '' -- WaveKey
      SET @cFieldAttr04 = '' -- CartonID

  -- Go to station screen
   END

   /***********************************************************************************************
                                                 CHECK
   ***********************************************************************************************/
   IF @cType = 'CHECK'
   BEGIN
      -- Screen mapping
      SET @cWaveKey = CASE WHEN @cFieldAttr01 = '' THEN @cInField01 ELSE @cOutField01 END
      SET @cOrderKey = @cOutField02
      SET @cPosition = @cOutField03
      SET @cCartonID   = CASE WHEN @cFieldAttr04 = '' THEN @cInField04 ELSE @cOutField04 END

      -- WaveKey enable
      IF @cFieldAttr01 = ''
      BEGIN
         -- Check blank
         IF @cWaveKey = ''
         BEGIN
            SET @nErrNo = 101151
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need WaveKey
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- WaveKey
            GOTO Quit
         END

         -- Check wave valid
         IF NOT EXISTS( SELECT 1 FROM WaveDetail WITH (NOLOCK) WHERE WaveKey = @cWaveKey)
         BEGIN
            SET @nErrNo = 101152
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
            SET @nErrNo = 101153
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
            SET @nErrNo = 101154
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff Storerf
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
               SET @nErrNo = 101155
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pick NotFinish
               SET @cOutField01 = ''
               GOTO Quit
            END
         END

         IF @cAssignExtValSP <> '' --(yeekung01)
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cAssignExtValSP AND type = 'P')
            BEGIN
               SET @cCurrentSP = OBJECT_NAME( @@PROCID)
               INSERT INTO @tVar (Variable, Value) VALUES
                  ('@cWaveKey',     @cWaveKey),
                  ('@cOrderKey',    @cOrderKey),
                  ('@cPosition',    @cPosition),
                  ('@cCartonID',    @cCartonID),
                  ('@cOption'  ,    @cInField01)

               SET @cSQL = 'EXEC rdt.' + RTRIM( @cAssignExtValSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
                  ' @cStation, @cMethod, @cCurrentSP, @tVar,' +
                  ' @nErrNo OUTPUT, @cErrMsg OUTPUT,@cType  '
               SET @cSQLParam =
                  ' @nMobile     INT,           ' +
                  ' @nFunc       INT,           ' +
                  ' @cLangCode   NVARCHAR( 3),  ' +
                  ' @nStep       INT,           ' +
                  ' @nInputKey   INT,           ' +
                  ' @cFacility   NVARCHAR( 5) , ' +
                  ' @cStorerKey  NVARCHAR( 10), ' +
                  ' @cStation    NVARCHAR( 1),  ' +
                  ' @cMethod     NVARCHAR( 15), ' +
                  ' @cCurrentSP  NVARCHAR( 60),  ' +
                  ' @tVar        VariableTable READONLY, ' +
                  ' @nErrNo      INT           OUTPUT, ' +
                  ' @cErrMsg     NVARCHAR(250) OUTPUT,  '+
                  ' @cType       NVARCHAR( 15)'

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
                  @cStation, @cMethod, @cCurrentSP, @tVar,
                  @nErrNo OUTPUT, @cErrMsg OUTPUT,@cType

               IF @nErrNo <> 0
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
            SET @nErrNo = 101160
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD Log fail
            GOTO Quit
         END

         IF @cDynamicSlot <> '1'
         BEGIN
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
               SET @nErrNo = 101161
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
                  SET @cLOC = ''
                  SELECT TOP 1
                     @cIPAddress = DP.IPAddress,
                     @cPosition = DP.DevicePosition, 
                     @cLOC = DP.LOC
                  FROM dbo.DeviceProfile DP WITH (NOLOCK)
                  WHERE DP.DeviceType = 'STATION'
                     AND DP.DeviceID = @cStation
                     AND dp.LogicalName<>'PTL'
                     AND NOT EXISTS( SELECT 1
                        FROM rdt.rdtPTLPieceLog Log WITH (NOLOCK)
                        WHERE Log.Station = @cStation
                           AND Log.Position = DP.DevicePosition)
                  ORDER BY DP.LogicalPos, DP.DevicePosition

                  -- Save assign
                  INSERT rdt.rdtPTLPieceLog (Station, IPAddress, Position, WaveKey, OrderKey, LOC)
                  VALUES (@cStation, @cIPAddress, @cPosition, @cWaveKey, @cOrderKey, @cLOC)
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 99707
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log fail
                     GOTO RollBackTran
                  END
               END

               FETCH NEXT FROM @curOrder INTO @cOrderKey
            END

            COMMIT TRAN rdt_PTLPiece_Assign
         END

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

         -- Prepare current screen var
         SET @cOutField01 = @cWaveKey
         SET @cOutField02 = @cOrderKey
         SET @cOutField03 = @cPosition
         SET @cOutField04 = '' -- CartonID
         SET @cOutField05 = CAST( @nTotalOrder AS NVARCHAR(5))
         SET @cOutField06 = CAST( @nTotalCarton AS NVARCHAR(5))

         -- Enable / Disable field
         SET @cFieldAttr01 = 'O' -- BatchKey
         SET @cFieldAttr04 = ''  -- CartonID
                    -- Remain in current screen
         SET @nErrNo = -1
         GOTO Quit
      END

      -- CartonID enable
      IF @cFieldAttr04 = ''
      BEGIN
         IF @cOrderKey <> ''
         BEGIN
            -- Check blank carton
            IF @cCartonID = ''
            BEGIN
               SET @nErrNo = 101156
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need CartonID
               EXEC rdt.rdtSetFocusField @nMobile, 4 -- CartonID
               GOTO Quit
            END

            -- Check barcode format
            IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'CartonID', @cCartonID) = 0
            BEGIN
               SET @nErrNo = 101157
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
               EXEC rdt.rdtSetFocusField @nMobile, 4 -- CartonID
               SET @cOutField04 = ''
               GOTO Quit
            END

            -- Check carton assigned
            IF EXISTS( SELECT 1
               FROM rdt.rdtPTLPieceLog WITH (NOLOCK)
               WHERE Station = @cStation
                  AND CartonID = @cCartonID)
            BEGIN
               SET @nErrNo = 101158
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CartonAssigned
               EXEC rdt.rdtSetFocusField @nMobile, 4 -- CartonID
               SET @cOutField04 = ''
               GOTO Quit
            END

            IF @cAssignExtValSP <> '' --(yeekung01)
            BEGIN
               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cAssignExtValSP AND type = 'P')
               BEGIN
                  SET @cCurrentSP = OBJECT_NAME( @@PROCID)
                  INSERT INTO @tVar (Variable, Value) VALUES
                     ('@cWaveKey',     @cWaveKey),
                     ('@cOrderKey',    @cOrderKey),
                     ('@cPosition',    @cPosition),
                     ('@cCartonID',    @cCartonID),
                     ('@cOption'  ,    @cInField01)

                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cAssignExtValSP) +
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
                     ' @cStation, @cMethod, @cCurrentSP, @tVar,' +
                     ' @nErrNo OUTPUT, @cErrMsg OUTPUT,@cType  '
                  SET @cSQLParam =
                     ' @nMobile     INT,           ' +
                     ' @nFunc       INT,           ' +
                     ' @cLangCode   NVARCHAR( 3),  ' +
                     ' @nStep       INT,           ' +
                     ' @nInputKey   INT,           ' +
                     ' @cFacility   NVARCHAR( 5) , ' +
                     ' @cStorerKey  NVARCHAR( 10), ' +
                     ' @cStation    NVARCHAR( 1),  ' +
                     ' @cMethod     NVARCHAR( 15), ' +
                     ' @cCurrentSP  NVARCHAR( 60),  ' +
                     ' @tVar        VariableTable READONLY, ' +
                     ' @nErrNo      INT           OUTPUT, ' +
                     ' @cErrMsg     NVARCHAR(250) OUTPUT,  '+
                     ' @cType       NVARCHAR( 15)'

                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
                     @cStation, @cMethod, @cCurrentSP, @tVar,
                     @nErrNo OUTPUT, @cErrMsg OUTPUT,@cType

                  IF @nErrNo <> 0
                     GOTO Quit
               END
            END

            -- Save assign
            UPDATE rdt.rdtPTLPieceLog SET
               CartonID = @cCartonID
            WHERE Station = @cStation
               AND OrderKey = @cOrderKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 101159
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Log fail
               GOTO Quit
            END

            SELECT @nTotalOrder = COUNT(1) FROM rdt.rdtPTLPieceLog WITH (NOLOCK) WHERE Station = @cStation
            SELECT @nTotalCarton = COUNT(1) FROM rdt.rdtPTLPieceLog WITH (NOLOCK) WHERE Station = @cStation AND CartonID <> ''

            SET @cOrderKey = ''
            SET @cPosition = ''

            IF @cDynamicSlot <> '1'
            BEGIN
               -- Get carton not yet assign
               IF @nTotalOrder > @nTotalCarton
                  SELECT TOP 1
                     @cOrderKey = OrderKey,
                     @cPosition = Position
                  FROM rdt.rdtPTLPieceLog WITH (NOLOCK)
                  WHERE Station = @cStation
                     AND CartonID = ''
                  ORDER BY RowRef
            END

            -- Prepare current screen var
            SET @cOutField02 = @cOrderKey
            SET @cOutField03 = @cPosition
            SET @cOutField04 = '' -- CartonID
            SET @cOutField05 = CAST( @nTotalOrder AS NVARCHAR(5))
            SET @cOutField06 = CAST( @nTotalCarton AS NVARCHAR(5))

            -- Remain in current screen
            SET @nErrNo = -1
            GOTO Quit
         END
      END

      -- Enable field
      SET @cFieldAttr01 = '' -- WaveKey
      SET @cFieldAttr04 = '' -- CartonID
   END
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_PTLPiece_Assign

Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN

END

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Store procedure: rdt_PTLPiece_Assign_BatchDropID                           */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 20-05-2020 1.0  Ung      WMS-13431 Create                                  */
/* 29-11-2022 1.1  Ung      WMS-21170 Add DynamicSlot                         */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_PTLPiece_Assign_BatchDropID] (
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

   DECLARE @nTranCount     INT
   DECLARE @bSuccess       INT
   DECLARE @cSQL           NVARCHAR(MAX)
   DECLARE @cSQLParam      NVARCHAR(MAX)

   DECLARE @cDynamicSlot   NVARCHAR( 1)
   DECLARE @cLight         NVARCHAR( 1)
   DECLARE @cBatchKey      NVARCHAR(20)
   DECLARE @cOrderKey      NVARCHAR(10)
   DECLARE @cIPAddress     NVARCHAR(40)
   DECLARE @cPosition      NVARCHAR(10)
   DECLARE @cCartonID      NVARCHAR(20)
   DECLARE @tVar           VariableTable
   DECLARE @nTotalOrder    INT = 0
   DECLARE @nTotalCarton   INT = 0

   SET @nTranCount = @@TRANCOUNT

   -- Storer configure    
   SET @cDynamicSlot = rdt.RDTGetConfig( @nFunc, 'DynamicSlot', @cStorerKey)    

   /***********************************************************************************************
                                                POPULATE
   ***********************************************************************************************/
   IF @cType = 'POPULATE-IN'
   BEGIN
      -- Get batch
      SET @cBatchKey = ''
      SELECT @cBatchKey = BatchKey
      FROM rdt.rdtPTLPieceLog WITH (NOLOCK)
      WHERE Station = @cStation
         AND BatchKey <> ''

      SELECT @nTotalOrder = COUNT(1) FROM rdt.rdtPTLPieceLog WITH (NOLOCK) WHERE Station = @cStation
      SELECT @nTotalCarton = COUNT(1) FROM rdt.rdtPTLPieceLog WITH (NOLOCK) WHERE Station = @cStation AND CartonID <> ''

      IF @cDynamicSlot = '1'
      BEGIN
         IF @cBatchKey = '' AND 
            @nStep = 3 -- From SKU screen
            SELECT @cBatchKey = V_PickSlipNo FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile
      END
      
		-- Prepare next screen var
		SET @cOutField01 = @cBatchKey
		SET @cOutField02 = '' -- Position
		SET @cOutField03 = '' -- CartonID
		SET @cOutField04 = CAST( @nTotalOrder AS NVARCHAR(5))
		SET @cOutField05 = CAST( @nTotalCarton AS NVARCHAR(5))

      IF @cBatchKey = ''
      BEGIN
         -- Enable disable field
         SET @cFieldAttr01 = ''  -- BatchKey
         SET @cFieldAttr03 = 'O' -- CartonID

   	   EXEC rdt.rdtSetFocusField @nMobile, 1 -- BatchKey
      END
      ELSE
      BEGIN
         SET @cFieldAttr01 = 'O' -- BatchKey
         SET @cFieldAttr03 = CASE WHEN @cDynamicSlot = '1' THEN 'O' ELSE '' END  -- CartonID

         IF @nTotalOrder > @nTotalCarton
         BEGIN
            -- Get carton not yet assign
            SELECT TOP 1
               @cPosition = Position
            FROM rdt.rdtPTLPieceLog WITH (NOLOCK)
            WHERE Station = @cStation
               AND CartonID = ''
            ORDER BY RowRef

      		-- Prepare next screen var
      		SET @cOutField02 = @cPosition
      		SET @cOutField03 = '' -- CartonID
         END
      END

		-- Go to batch, drop ID screen
		SET @nScn = 4603
   END

   IF @cType = 'POPULATE-OUT'
   BEGIN
      SET @cFieldAttr01 = '' -- BatchKey
      SET @cFieldAttr03 = '' -- CartonID

		-- Go to station screen
   END

   /***********************************************************************************************
                                                 CHECK
   ***********************************************************************************************/
   IF @cType = 'CHECK'
   BEGIN
      -- Screen mapping
      SET @cBatchKey = CASE WHEN @cFieldAttr01 = '' THEN @cInField01 ELSE @cOutField01 END
      SET @cPosition = @cOutField02
      SET @cCartonID = CASE WHEN @cFieldAttr03 = '' THEN @cInField03 ELSE @cOutField03 END

      -- BatchKey enable
      IF @cFieldAttr01 = ''
      BEGIN
   		-- Check blank
   		IF @cBatchKey = ''
         BEGIN
            SET @nErrNo = 152651
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need BatchKey
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- BatchKey
            GOTO Quit
         END

         -- Check batch valid
         IF NOT EXISTS( SELECT 1 FROM PackTask WITH (NOLOCK) WHERE TaskBatchNo = @cBatchKey)
         BEGIN
            SET @nErrNo = 152652
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid batch
            SET @cOutField01 = ''
            GOTO Quit
         END

         -- Check batch assigned
         IF EXISTS( SELECT 1
            FROM rdt.rdtPTLPieceLog WITH (NOLOCK)
            WHERE Station <> @cStation
               AND BatchKey = @cBatchKey)
         BEGIN
            SET @nErrNo = 152653
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Batch assigned
            SET @cOutField01 = ''
            GOTO Quit
         END

         -- Check batch belong to login storer
         IF EXISTS( SELECT 1
            FROM PackTask T WITH (NOLOCK)
               JOIN Orders O WITH (NOLOCK) ON (O.OrderKey = T.OrderKey)
            WHERE T.TaskBatchNo = @cBatchKey
               AND O.StorerKey <> @cStorerKey)
         BEGIN
            SET @nErrNo = 152654
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff Storer
            SET @cOutField01 = ''
            GOTO Quit
         END

         -- Check pick not completed
         IF rdt.RDTGetConfig( @nFunc, 'CheckPickCompleted', @cStorerKey) = '1'
         BEGIN
            IF EXISTS( SELECT 1
               FROM PackTask T WITH (NOLOCK)
                  JOIN Orders O WITH (NOLOCK) ON (O.OrderKey = T.OrderKey)
                  JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
               WHERE T.TaskBatchNo = @cBatchKey
                  AND PD.Status IN ('0', '4')
                  AND PD.QTY > 0)
            BEGIN
               SET @nErrNo = 152655
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pick NotFinish
               SET @cOutField01 = ''
               GOTO Quit
            END
         END

         -- Save assign
         IF @cDynamicSlot = '1'    
         BEGIN
            UPDATE rdt.rdtMobRec SET
               V_PickSlipNo = @cBatchKey,
               EditDate = GETDATE()
            WHERE Mobile = @nMobile
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 152662
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD Log fail
               GOTO Quit
            END
         END
         ELSE
         BEGIN  
            -- Get station info
            DECLARE @nTotalPos INT
            SELECT @nTotalPos = COUNT(1)
            FROM DeviceProfile WITH (NOLOCK)
            WHERE DeviceType = 'STATION'
               AND DeviceID = @cStation

            -- Get total orders
            SELECT @nTotalOrder = COUNT(1) FROM PackTask WITH (NOLOCK) WHERE TaskBatchNo = @cBatchKey

            -- Check order fit in station
            IF @nTotalOrder > @nTotalPos
            BEGIN
               SET @nErrNo = 152656
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not enuf Pos
               SET @cOutField01 = ''
               GOTO Quit
            END

            -- Handling transaction
            BEGIN TRAN  -- Begin our own transaction
            SAVE TRAN rdt_PTLPiece_Assign -- For rollback or commit only our own transaction

            SET @cIPAddress = ''

            -- Loop orders
            DECLARE @cPreassignPos NVARCHAR(10)
            DECLARE @cLOC NVARCHAR(10)
            DECLARE @curOrder CURSOR
            SET @curOrder = CURSOR FOR
               SELECT OrderKey, DevicePosition
               FROM PackTask PT WITH (NOLOCK)
               WHERE TaskBatchNo = @cBatchKey
               ORDER BY OrderKey
            OPEN @curOrder
            FETCH NEXT FROM @curOrder INTO @cOrderKey, @cPreassignPos
            WHILE @@FETCH_STATUS = 0
            BEGIN
               -- Not pre-assign position
               IF @cPreassignPos = ''
               BEGIN
                  -- Get position not yet assign
                  SET @cPosition = ''
                  SELECT TOP 1
                     @cIPAddress = DP.IPAddress,
                     @cPosition = DP.DevicePosition, 
                     @cLOC = LOC
                  FROM dbo.DeviceProfile DP WITH (NOLOCK)
                  WHERE DP.DeviceType = 'STATION'
                     AND DP.DeviceID = @cStation
                     AND NOT EXISTS( SELECT 1
                        FROM rdt.rdtPTLPieceLog Log WITH (NOLOCK)
                        WHERE Log.Station = @cStation
                           AND Log.Position = DP.DevicePosition)
                  ORDER BY DP.LogicalPos, DP.DevicePosition
               END
               ELSE
               BEGIN
                  -- Use preassign position
                  SET @cPosition = @cPreassignPos

                  SELECT TOP 1
                     @cIPAddress = DP.IPAddress, 
                     @cLOC = LOC
                  FROM dbo.DeviceProfile DP WITH (NOLOCK)
                  WHERE DP.DeviceType = 'STATION'
                     AND DP.DeviceID = @cStation
                     AND DevicePosition = @cPosition
               END

               -- Save assign
               INSERT rdt.rdtPTLPieceLog (Station, IPAddress, Position, LOC, BatchKey, OrderKey)
               VALUES (@cStation, @cIPAddress, @cPosition, @cLOC, @cBatchKey, @cOrderKey)
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 152657
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log fail
                  GOTO RollBackTran
               END

               FETCH NEXT FROM @curOrder INTO @cOrderKey, @cPreassignPos
            END

            COMMIT TRAN rdt_PTLStation_Assign
         
            -- Get carton not yet assign
            SET @cPosition = ''
            SELECT TOP 1
               @cPosition = Position,
               @cCartonID = ''
            FROM rdt.rdtPTLPieceLog WITH (NOLOCK)
            WHERE Station = @cStation
               AND CartonID = ''
            ORDER BY RowRef

            -- Prepare current screen var
            SET @cOutField01 = @cBatchKey
            SET @cOutField02 = @cPosition
            SET @cOutField03 = '' -- CartonID
            SET @cOutField04 = CAST( @nTotalOrder AS NVARCHAR(5))
            SET @cOutField05 = CAST( @nTotalCarton AS NVARCHAR(5))

            -- Enable / Disable field
            SET @cFieldAttr01 = 'O' -- BatchKey
            SET @cFieldAttr03 = ''  -- CartonID

            -- Remain in current screen
            SET @nErrNo = -1
            GOTO Quit
         END
      END

      -- CartonID enable
      IF @cFieldAttr03 = ''
      BEGIN
         IF @cPosition <> ''
         BEGIN
            -- Check blank carton
            IF @cCartonID = ''
            BEGIN
               SET @nErrNo = 152658
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need CartonID
               GOTO Quit
            END

            -- Check barcode format
            IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'CartonID', @cCartonID) = 0
            BEGIN
               SET @nErrNo = 152659
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
               SET @cOutField03 = ''
               GOTO Quit
            END

            -- Check carton assigned
            IF EXISTS( SELECT 1
               FROM rdt.rdtPTLPieceLog WITH (NOLOCK)
               WHERE Station = @cStation
                  AND CartonID = @cCartonID)
            BEGIN
               SET @nErrNo = 152660
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CartonAssigned
               SET @cOutField03 = ''
               GOTO Quit
            END

            DECLARE @cAssignExtValSP NVARCHAR( 20)
            SET @cAssignExtValSP = rdt.RDTGetConfig( @nFunc, 'AssignExtValSP', @cStorerKey)
            IF @cAssignExtValSP = '0'
               SET @cAssignExtValSP = ''

            IF @cAssignExtValSP <> ''
            BEGIN
               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cAssignExtValSP AND type = 'P')
               BEGIN
                  DECLARE @cCurrentSP NVARCHAR( 60)
                  SET @cCurrentSP = OBJECT_NAME( @@PROCID)

                  INSERT INTO @tVar (Variable, Value) VALUES
                     ('@cBatchKey',    @cBatchKey),
                     ('@cOrderKey',    @cOrderKey),
                     ('@cPosition',    @cPosition),
                     ('@cCartonID',    @cCartonID)

                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cAssignExtValSP) +
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
                     ' @cStation    NVARCHAR( 1),  ' +
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

            -- Save assign
            UPDATE rdt.rdtPTLPieceLog SET
               CartonID = @cCartonID, 
               EditWho = SUSER_SNAME(), 
               EditDate = GETDATE()
            WHERE Station = @cStation
               AND Position = @cPosition
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 152661
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Log fail
               GOTO Quit
            END

            SET @cPosition = ''
            SELECT @nTotalOrder = COUNT(1) FROM rdt.rdtPTLPieceLog WITH (NOLOCK) WHERE Station = @cStation
            SELECT @nTotalCarton = COUNT(1) FROM rdt.rdtPTLPieceLog WITH (NOLOCK) WHERE Station = @cStation AND CartonID <> ''

            -- Get carton not yet assign
            IF @nTotalOrder > @nTotalCarton
               SELECT TOP 1
                  @cOrderKey = OrderKey,
                  @cPosition = Position
               FROM rdt.rdtPTLPieceLog WITH (NOLOCK)
               WHERE Station = @cStation
                  AND CartonID = ''
               ORDER BY RowRef

            -- Prepare current screen var
            SET @cOutField01 = @cBatchKey
            SET @cOutField02 = @cPosition
            SET @cOutField03 = '' -- CartonID
            SET @cOutField04 = CAST( @nTotalOrder AS NVARCHAR(5))
            SET @cOutField05 = CAST( @nTotalCarton AS NVARCHAR(5))

            -- Remain in current screen
            SET @nErrNo = -1
            GOTO Quit
         END
      END

      -- Enable field
      SET @cFieldAttr01 = '' -- BatchKey
      SET @cFieldAttr03 = '' -- CartonID
   END
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_PTLStation_Assign
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO
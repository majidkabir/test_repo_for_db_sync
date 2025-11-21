SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_PTLPiece_Assign_LoadCarton                            */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 02-10-2020 1.0  YeeKung  WMS-15181 Created                                 */
/* 26-11-2020 1.1  YeeKung  WMS-15702 Add Params (yeekung01)                  */
/* 15-11-2021 1.2  YeeKung  WMS-18376 Add order by (yeekung02)                */
/* 07-04-2022 1.3  YeeKung  Fix screen (yeekung02)  4603->4609                */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_PTLPiece_Assign_LoadCarton] (
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
   DECLARE @cLoadkey       NVARCHAR(10)
   DECLARE @cOrderKey      NVARCHAR(10)
   DECLARE @cCartonID      NVARCHAR(20)
   DECLARE @nTotalOrder    INT
   DECLARE @nTotalCarton   INT
   
   SET @nTranCount = @@TRANCOUNT
   
   -- Storer configure
   SET @cDynamicSlot = rdt.RDTGetConfig( @nFunc, 'DynamicSlot', @cStorerKey)
   
   /***********************************************************************************************
                                                POPULATE
   ***********************************************************************************************/
   IF @cType = 'POPULATE-IN'
   BEGIN
      -- Get assign info
      SET @cLoadkey = ''
      SELECT @cLoadkey = loadkey
      FROM rdt.rdtPTLPieceLog WITH (NOLOCK) 
      WHERE Station = @cStation

      SELECT @nTotalOrder = COUNT(1) FROM rdt.rdtPTLPieceLog WITH (NOLOCK) WHERE Station = @cStation
      SELECT @nTotalCarton = COUNT(1) FROM rdt.rdtPTLPieceLog WITH (NOLOCK) WHERE Station = @cStation AND CartonID <> ''
            
		-- Prepare next screen var
		SET @cOutField01 = @cLoadkey
		SET @cOutField02 = '' -- OrderKey
		SET @cOutField03 = '' -- Position
		SET @cOutField04 = '' -- CartonID
		SET @cOutField05 = CAST( @nTotalOrder AS NVARCHAR(5))
		SET @cOutField06 = CAST( @nTotalCarton AS NVARCHAR(5))

      IF @cLoadkey = ''
      BEGIN
         -- Enable disable field
         SET @cFieldAttr01 = ''  -- loadkey
         SET @cFieldAttr04 = 'O' -- CartonID

   	   EXEC rdt.rdtSetFocusField @nMobile, 1 -- loadkey
      END
      ELSE
      BEGIN
         SET @cFieldAttr01 = 'O' -- loadkey
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
		
		-- Go to loadkey, carton screen
		SET @nScn = 4609  --(yeekung03)
   END
      
   IF @cType = 'POPULATE-OUT'
   BEGIN
      SET @cFieldAttr01 = '' -- loadkey
      SET @cFieldAttr04 = '' -- CartonID
      
		-- Go to station screen
   END
   
   /***********************************************************************************************
                                                 CHECK
   ***********************************************************************************************/
   IF @cType = 'CHECK'
   BEGIN
      -- Screen mapping
      SET @cLoadkey = CASE WHEN @cFieldAttr01 = '' THEN @cInField01 ELSE @cOutField01 END
      SET @cOrderKey = @cOutField02
      SET @cPosition = @cOutField03
      SET @cCartonID   = CASE WHEN @cFieldAttr04 = '' THEN @cInField04 ELSE @cOutField04 END
      
      -- loadkey enable
      IF @cFieldAttr01 = ''
      BEGIN
   		-- Check blank
   		IF @cLoadkey = '' 
         BEGIN
            SET @nErrNo = 159551 
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need loadkey
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- loadkey
            GOTO Quit
         END
         
         -- Check loadkey valid
         IF NOT EXISTS( SELECT 1 FROM orders WITH (NOLOCK) WHERE loadkey = @cLoadkey)
         BEGIN
            SET @nErrNo = 159552
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid loadkey
            SET @cOutField01 = ''
            GOTO Quit
         END
   
         -- Check loadkey assigned
         IF EXISTS( SELECT 1
            FROM rdt.rdtPTLPieceLog WITH (NOLOCK)
            WHERE Station <> @cStation
               AND LoadKey = @cLoadkey)
         BEGIN
            SET @nErrNo = 159553
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --loadkey assigned
            GOTO Quit
         END
   
         -- Check loadkey belong to login storer
         IF EXISTS( SELECT 1 
            FROM Orders (NOLOCK)
            WHERE LoadKey = @cLoadkey
               AND StorerKey <> @cStorerKey)
         BEGIN
            SET @nErrNo = 159554
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff Storerf
            SET @cOutField01 = ''
            GOTO Quit
         END
         
         -- Check pick not completed
         IF rdt.RDTGetConfig( @nFunc, 'CheckPickCompleted', @cStorerKey) = '1'
         BEGIN
            IF EXISTS( SELECT 1 
               FROM Orders O WITH (NOLOCK) 
                  JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
               WHERE O.loadkey = @cLoadkey
                  AND PD.Status IN ('0', '4')
                  AND PD.QTY > 0)
            BEGIN
               SET @nErrNo = 159555
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pick NotFinish
               SET @cOutField01 = ''
               GOTO Quit
            END
         END

         -- Save assign
         UPDATE rdt.rdtMobRec SET 
            V_LoadKey = @cLoadkey, 
            EditDate = GETDATE()
         WHERE Mobile = @nMobile
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 159556
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
            FROM Orders O WITH (NOLOCK) 
               JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
            WHERE o.loadkey = @cLoadkey
               AND PD.QTY > 0
               AND PD.Status <> '4'
               AND O.Status <> 'CANC' 
               AND O.SOStatus <> 'CANC'
      
            -- Check order fit in station
            IF @nTotalOrder > @nTotalPos 
            BEGIN
               SET @nErrNo = 159557
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
               FROM  Orders O WITH (NOLOCK)
                  JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
               WHERE O.loadkey= @cLoadkey
                  AND PD.QTY > 0
                  AND PD.Status <> '4'
                  AND O.Status <> 'CANC' 
                  AND O.SOStatus <> 'CANC'
               ORDER BY o.OrderKey  --(yeekung02)
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
                  INSERT rdt.rdtPTLPieceLog (Station, IPAddress, Position, loadkey, OrderKey)
                  VALUES (@cStation, @cIPAddress, @cPosition, @cLoadkey, @cOrderKey)
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 159558
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
         SET @cOutField01 = @cLoadkey
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
               SET @nErrNo = 159559
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need CartonID
               EXEC rdt.rdtSetFocusField @nMobile, 4 -- CartonID
               GOTO Quit
            END
   
            -- Check barcode format
            IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'CartonID', @cCartonID) = 0
            BEGIN
               SET @nErrNo = 159560
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
               SET @nErrNo = 159561
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CartonAssigned
               EXEC rdt.rdtSetFocusField @nMobile, 4 -- CartonID
               SET @cOutField04 = ''
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
                     ('@cLoadkey',     @cLoadkey), 
                     ('@cOrderKey',    @cOrderKey), 
                     ('@cPosition',    @cPosition), 
                     ('@cCartonID',    @cCartonID)

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
                  ' @cType       NVARCHAR( 15)'  --(yeekung01)
               
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
               SET @nErrNo = 159562
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
      SET @cFieldAttr01 = '' -- loadkey
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
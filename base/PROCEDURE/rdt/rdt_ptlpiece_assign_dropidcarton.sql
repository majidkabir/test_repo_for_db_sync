SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_PTLPiece_Assign_DropIDCarton                          */
/* Copyright      : Maersk                                                    */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 20-04-2023 1.0  Ung        WMS-15181 Created                               */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_PTLPiece_Assign_DropIDCarton] (
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

   DECLARE @bSuccess       INT
   DECLARE @cSQL           NVARCHAR(MAX)
   DECLARE @cSQLParam      NVARCHAR(MAX)
   DECLARE @nTranCount     INT
   DECLARE @cIPAddress     NVARCHAR(40)
   DECLARE @cPosition      NVARCHAR(10)
   DECLARE @cLightMode     NVARCHAR( 4)
   DECLARE @tVar           VariableTable

   DECLARE @cDropID        NVARCHAR(20)
   DECLARE @cOrderKey      NVARCHAR(10)
   DECLARE @cCartonID      NVARCHAR(20)
   DECLARE @nTotalOrder    INT
   DECLARE @nTotalCarton   INT

   -- Get session info
   DECLARE @cLight NVARCHAR( 1)
   SELECT @cLight = V_String24 FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile

   -- Get storer config
   IF @cLight = '1'
      SET @cLightMode = rdt.RDTGetConfig( @nFunc, 'LightMode', @cStorerKey)

   SET @nTranCount = @@TRANCOUNT

   /***********************************************************************************************
                                                POPULATE
   ***********************************************************************************************/
   IF @cType = 'POPULATE-IN'
   BEGIN
      SELECT @nTotalOrder = COUNT(1) FROM rdt.rdtPTLPieceLog WITH (NOLOCK) WHERE Station = @cStation
      SELECT @nTotalCarton = COUNT(1) FROM rdt.rdtPTLPieceLog WITH (NOLOCK) WHERE Station = @cStation AND CartonID <> ''

      -- Prepare next screen var
      SET @cOutField01 = '' -- @cDropID
      SET @cOutField02 = '' -- OrderKey
      SET @cOutField03 = '' -- Position
      SET @cOutField04 = '' -- CartonID
      SET @cOutField05 = CAST( @nTotalOrder AS NVARCHAR(5))
      SET @cOutField06 = CAST( @nTotalCarton AS NVARCHAR(5))

      -- Enable disable field
      SET @cFieldAttr01 = ''  -- DropID
      SET @cFieldAttr04 = 'O' -- CartonID

      -- Go to DropID, carton screen
      SET @nScn = 6162
   END

   IF @cType = 'POPULATE-OUT'
   BEGIN
      SET @cFieldAttr01 = '' -- DropID
      SET @cFieldAttr04 = '' -- CartonID
   END

   /***********************************************************************************************
                                                 CHECK
   ***********************************************************************************************/
   IF @cType = 'CHECK'
   BEGIN
      -- Screen mapping
      SET @cDropID = CASE WHEN @cFieldAttr01 = '' THEN @cInField01 ELSE @cOutField01 END
      SET @cOrderKey = @cOutField02
      SET @cPosition = @cOutField03
      SET @cCartonID   = CASE WHEN @cFieldAttr04 = '' THEN @cInField04 ELSE @cOutField04 END

      -- DropID enable
      IF @cFieldAttr01 = ''
      BEGIN
         -- Check blank
         IF @cDropID = ''
         BEGIN
            SET @nErrNo = 199801
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need DropID
            GOTO Quit
         END

         -- Check barcode format
         IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'DropID', @cDropID) = 0
         BEGIN
            SET @nErrNo = 199811
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
            SET @cOutField01 = ''
            GOTO Quit
         END

         -- Check DropID valid
         SET @cOrderKey = ''
         SELECT TOP 1
            @cOrderKey = O.OrderKey
         FROM Orders O WITH (NOLOCK)
            JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
         WHERE O.StorerKey = @cStorerKey
            AND PD.DropID = @cDropID
            AND PD.CaseID = ''
            AND PD.QTY > 0
            AND PD.Status <> '4'
            AND PD.Status < '5'
            AND O.Status <> 'CANC' 
            AND O.SOStatus <> 'CANC'

         -- Check DropID valid
         IF @cOrderKey = ''
         BEGIN
            SET @nErrNo = 199802
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No order
            SET @cOutField01 = ''
            --EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @cStorerKey, @cDropID
            GOTO Quit
         END

         -- Check DropID belong to station
         IF NOT EXISTS( SELECT 1
            FROM Orders O (NOLOCK)
               JOIN Wave W (NOLOCK) ON (W.Wavekey = O.Userdefine09)
            WHERE O.OrderKey = @cOrderKey
               AND W.UserDefine01 = @cStation)
         BEGIN
            SET @nErrNo = 199803
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff Station
            SET @cOutField01 = ''
            GOTO Quit
         END

         -- Save assign
         UPDATE rdt.rdtMobRec SET
            V_DropID = @cDropID,
            EditDate = GETDATE()
         WHERE Mobile = @nMobile
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 199804
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD MobRecfail
            SET @cOutField01 = ''
            GOTO Quit
         END

         -- Get position available
         DECLARE @nPosAvail INT
         SELECT @nPosAvail = COUNT(1)
         FROM DeviceProfile WITH (NOLOCK)
         WHERE DeviceType = 'STATION'
            AND DeviceID = @cStation
            AND DevicePosition NOT IN (
               SELECT Position
               FROM rdt.rdtPTLPieceLog WITH (NOLOCK)
               WHERE Station = @cStation)

         -- Get orders not yet assign
         DECLARE @nOrderNotAssign INT
         SELECT @nOrderNotAssign = COUNT( DISTINCT O.OrderKey)
         FROM Orders O WITH (NOLOCK)
            JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
         WHERE O.StorerKey = @cStorerKey
            AND PD.DropID = @cDropID
            AND PD.QTY > 0
            AND PD.Status <> '4'
            AND PD.Status < '5'
            AND O.Status <> 'CANC'
            AND O.SOStatus <> 'CANC'
            AND O.OrderKey NOT IN (
               SELECT OrderKey
               FROM rdt.rdtPTLPieceLog WITH (NOLOCK)
               WHERE Station = @cStation)

         -- Check orders fit in station
         IF @nOrderNotAssign > @nPosAvail
         BEGIN
            SET @nErrNo = 199805
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not enuf Pos
            SET @cOutField01 = ''
            GOTO Quit
         END

         -- Assign order
         IF @nOrderNotAssign > 0
         BEGIN
            -- Handling transaction
            BEGIN TRAN  -- Begin our own transaction
            SAVE TRAN rdt_PTLPiece_Assign -- For rollback or commit only our own transaction

            -- Loop orders
            DECLARE @cPreassignPos NVARCHAR(10)
            DECLARE @curOrder CURSOR
            SET @curOrder = CURSOR FOR
               SELECT DISTINCT O.OrderKey
               FROM Orders O WITH (NOLOCK)
                  JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
               WHERE O.StorerKey = @cStorerKey
                  AND PD.DropID = @cDropID
                  AND PD.QTY > 0
                  AND PD.Status <> '4'
                  AND PD.Status < '5'
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
                  INSERT rdt.rdtPTLPieceLog (Station, IPAddress, Position, DropID, OrderKey)
                  VALUES (@cStation, @cIPAddress, @cPosition, @cDropID, @cOrderKey) --
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 199806
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log fail
                     SET @cOutField01 = ''
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
            @cIPAddress = IPAddress, 
            @cPosition = Position,
            @cCartonID = ''
         FROM rdt.rdtPTLPieceLog WITH (NOLOCK)
         WHERE Station = @cStation
            AND CartonID = ''
         ORDER BY RowRef

         SELECT @nTotalOrder = COUNT(1) FROM rdt.rdtPTLPieceLog WITH (NOLOCK) WHERE Station = @cStation AND DropID = @cDropID
         SELECT @nTotalCarton = COUNT(1) FROM rdt.rdtPTLPieceLog WITH (NOLOCK) WHERE Station = @cStation AND DropID = @cDropID AND CartonID <> ''

         -- Assign carton
         IF @nTotalOrder > @nTotalCarton
         BEGIN
            IF @cLight = '1'
            BEGIN
               -- Light up
               EXEC PTL.isp_PTL_LightUpLoc
                  @n_Func           = @nFunc
                 ,@n_PTLKey         = 0
                 ,@c_DisplayValue   = 'TOTE'
                 ,@b_Success        = @bSuccess    OUTPUT
                 ,@n_Err            = @nErrNo      OUTPUT
                 ,@c_ErrMsg         = @cErrMsg     OUTPUT
                 ,@c_DeviceID       = @cStation
                 ,@c_DevicePos      = @cPosition
                 ,@c_DeviceIP       = @cIPAddress
                 ,@c_LModMode       = @cLightMode
               IF @nErrNo <> 0
                  GOTO Quit
            END
            
            -- Prepare current screen var
            SET @cOutField01 = @cDropID
            SET @cOutField02 = @cOrderKey
            SET @cOutField03 = @cPosition
            SET @cOutField04 = '' -- CartonID
            SET @cOutField05 = CAST( @nTotalOrder AS NVARCHAR(5))
            SET @cOutField06 = CAST( @nTotalCarton AS NVARCHAR(5))

            -- Enable / Disable field
            SET @cFieldAttr01 = 'O' -- DropID
            SET @cFieldAttr04 = ''  -- CartonID

            -- Remain in current screen
            SET @nErrNo = -1
            GOTO Quit
         END
      END

      -- CartonID enable
      IF @cFieldAttr04 = ''
      BEGIN
         IF @cOrderKey <> ''
         BEGIN
            -- Check blank carton
            IF @cCartonID = ''
            BEGIN
               SET @nErrNo = 199807
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need CartonID
               GOTO Quit
            END

            -- Check barcode format
            IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'CartonID', @cCartonID) = 0
            BEGIN
               SET @nErrNo = 199808
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
               SET @cOutField04 = ''
               GOTO Quit
            END

            -- Check carton assigned
            IF EXISTS( SELECT 1
               FROM rdt.rdtPTLPieceLog WITH (NOLOCK)
               WHERE Station = @cStation
                  AND CartonID = @cCartonID)
            BEGIN
               SET @nErrNo = 199809
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CartonAssigned
               SET @cOutField04 = ''
               GOTO Quit
            END

            -- Save assign
            UPDATE rdt.rdtPTLPieceLog SET
               CartonID = @cCartonID
            WHERE Station = @cStation
               AND OrderKey = @cOrderKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 199810
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Log fail
               SET @cOutField04 = ''
               GOTO Quit
            END
            
            SELECT @nTotalOrder = COUNT(1) FROM rdt.rdtPTLPieceLog WITH (NOLOCK) WHERE Station = @cStation AND DropID = @cDropID
            SELECT @nTotalCarton = COUNT(1) FROM rdt.rdtPTLPieceLog WITH (NOLOCK) WHERE Station = @cStation AND DropID = @cDropID AND CartonID <> ''

            -- Get carton not yet assign
            IF @nTotalOrder > @nTotalCarton
            BEGIN
               SET @cOrderKey = ''
               SET @cPosition = ''
               SELECT TOP 1
                  @cOrderKey = OrderKey,
                  @cIPAddress = IPAddress, 
                  @cPosition = Position
               FROM rdt.rdtPTLPieceLog WITH (NOLOCK)
               WHERE Station = @cStation
                  AND CartonID = ''
               ORDER BY RowRef

               -- Prepare current screen var
               SET @cOutField02 = @cOrderKey
               SET @cOutField03 = @cPosition
               SET @cOutField04 = '' -- CartonID
               SET @cOutField05 = CAST( @nTotalOrder AS NVARCHAR(5))
               SET @cOutField06 = CAST( @nTotalCarton AS NVARCHAR(5))

               IF @cLight = '1'
               BEGIN
                  -- Light up
                  EXEC PTL.isp_PTL_LightUpLoc
                     @n_Func           = @nFunc
                    ,@n_PTLKey         = 0
                    ,@c_DisplayValue   = 'TOTE'
                    ,@b_Success        = @bSuccess    OUTPUT
                    ,@n_Err            = @nErrNo      OUTPUT
                    ,@c_ErrMsg         = @cErrMsg     OUTPUT
                    ,@c_DeviceID       = @cStation
                    ,@c_DevicePos      = @cPosition
                    ,@c_DeviceIP       = @cIPAddress
                    ,@c_LModMode       = @cLightMode
                  IF @nErrNo <> 0
                     GOTO Quit
               END

               -- Remain in current screen
               SET @nErrNo = -1
               GOTO Quit
            END
         END
      END

      -- Enable field
      SET @cFieldAttr01 = '' -- DropID
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
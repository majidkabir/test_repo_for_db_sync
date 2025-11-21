SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_PTLPiece_Assign_Batch                                 */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 26-04-2016 1.0  Ung      SOS368861 Created                                 */
/* 12-11-2016 1.1  James    Reset variable (james01)                          */
/* 04-05-2017 1.2  Ung      WMS-1856 Add Orders sequence                      */
/* 15-05-2021 1.3  YeeKung  WMS-16220 Add assignextupd (yeekung01)            */
/******************************************************************************/

CREATE PROC [RDT].[rdt_PTLPiece_Assign_Batch] (
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

   DECLARE @nTranCount  INT
   DECLARE @cSQL           NVARCHAR(MAX)
   DECLARE @cSQLParam      NVARCHAR(MAX)

   DECLARE @cBatchKey       NVARCHAR(20)
   DECLARE @cOrderKey       NVARCHAR(10)
   DECLARE @cIPAddress      NVARCHAR(40)
   DECLARE @cPosition       NVARCHAR(10)

   DECLARE @tVar           VariableTable
   DECLARE @cCurrentSP NVARCHAR( 60)

   SET @nTranCount = @@TRANCOUNT

   DECLARE @cAssignExtUpdSP NVARCHAR( 20) --(yeekung01)
   SET @cAssignExtUpdSP = rdt.RDTGetConfig( @nFunc, 'AssignExtUpdSP', @cStorerKey)
   IF @cAssignExtUpdSP = '0'
      SET @cAssignExtUpdSP = ''

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
      
		-- Prepare next screen var
		SET @cOutField01 = @cBatchKey

		-- Go to batch screen
		SET @nScn = 4600
   END
      

   IF @cType = 'POPULATE-OUT'
   BEGIN
      IF @cAssignExtUpdSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cAssignExtUpdSP AND type = 'P')
         BEGIN
            SET @cCurrentSP = OBJECT_NAME( @@PROCID)

            INSERT INTO @tVar (Variable, Value) VALUES 
               ('@cType',@cType),
               ('@cBatchKey',    @cBatchKey)

            SET @cSQL = 'EXEC rdt.' + RTRIM( @cAssignExtUpdSP) +
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
      DECLARE @cChkBatchKey NVARCHAR(20)

      -- Screen mapping
      SET @cChkBatchKey = @cInField01

      -- Get batch 
      SET @cBatchKey = ''
      SELECT @cBatchKey = BatchKey
      FROM rdt.rdtPTLPieceLog WITH (NOLOCK) 
      WHERE Station = @cStation
      
      -- Assigned
      IF @cBatchKey <> '' 
      BEGIN
         -- Check different batch
         IF @cChkBatchKey <> @cBatchKey
         BEGIN
            SET @nErrNo = 99701
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff batch
            SET @cOutField01 = ''
            GOTO Quit
         END
         GOTO Quit
      END
      
      -- Not yet assign
      IF @cBatchKey = '' 
      BEGIN
         -- Check batch valid
         IF NOT EXISTS( SELECT 1 FROM PackTask WITH (NOLOCK) WHERE TaskBatchNo = @cChkBatchKey)
         BEGIN
            SET @nErrNo = 99702
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid batch
            SET @cOutField01 = ''
            GOTO Quit
         END
   
         -- Check batch assigned
         IF EXISTS( SELECT 1
            FROM rdt.rdtPTLPieceLog WITH (NOLOCK)
            WHERE Station <> @cStation
               AND BatchKey = @cChkBatchKey)
         BEGIN
            SET @nErrNo = 99703
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Batch assigned
            SET @cOutField01 = ''
            GOTO Quit
         END

         IF @cAssignExtUpdSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cAssignExtUpdSP AND type = 'P')
            BEGIN
               SET @cCurrentSP = OBJECT_NAME( @@PROCID)

               INSERT INTO @tVar (Variable, Value) VALUES 
                  ('@cType',@cType),
                  ('@cBatchKey',    @cBatchKey)

               SET @cSQL = 'EXEC rdt.' + RTRIM( @cAssignExtUpdSP) +
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
   
         -- Check batch belong to login storer
         IF EXISTS( SELECT 1 
            FROM PackTask T WITH (NOLOCK) 
               JOIN Orders O WITH (NOLOCK) ON (O.OrderKey = T.OrderKey)
            WHERE T.TaskBatchNo = @cChkBatchKey
               AND O.StorerKey <> @cStorerKey)
         BEGIN
            SET @nErrNo = 99704
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff Storerf
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
               WHERE T.TaskBatchNo = @cChkBatchKey
                  AND PD.Status IN ('0', '4')
                  AND PD.QTY > 0)
            BEGIN
               SET @nErrNo = 99705
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pick NotFinish
               SET @cOutField01 = ''
               GOTO Quit
            END         
         END
            
         -- Get station info
         DECLARE @nTotalPos INT
         SELECT @nTotalPos = COUNT(1) 
         FROM DeviceProfile WITH (NOLOCK) 
         WHERE DeviceType = 'STATION' 
            AND DeviceID = @cStation 
            
         -- Get total orders
         DECLARE @nTotalOrder INT
         SELECT @nTotalOrder = COUNT(1) FROM PackTask WITH (NOLOCK) WHERE TaskBatchNo = @cChkBatchKey
   
         -- Check order fit in station
         IF @nTotalOrder > @nTotalPos 
         BEGIN
            SET @nErrNo = 99706
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not enuf Pos
            SET @cOutField01 = ''
            GOTO Quit
         END 
         
         -- Handling transaction
         BEGIN TRAN  -- Begin our own transaction
         SAVE TRAN rdt_PTLPiece_Assign -- For rollback or commit only our own transaction
         
         SET @cIPAddress = '' -- (james01)

         -- Loop orders
         DECLARE @cPreassignPos NVARCHAR(10)
         DECLARE @curOrder CURSOR
         SET @curOrder = CURSOR FOR
            SELECT OrderKey, DevicePosition
            FROM PackTask PT WITH (NOLOCK) 
            WHERE TaskBatchNo = @cChkBatchKey
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
                  @cPosition = DP.DevicePosition
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
                  @cIPAddress = DP.IPAddress
               FROM dbo.DeviceProfile DP WITH (NOLOCK)
               WHERE DP.DeviceType = 'STATION'
                  AND DP.DeviceID = @cStation
                  AND DevicePosition = @cPosition
            END
   
            -- Save assign
            INSERT rdt.rdtPTLPieceLog (Station, IPAddress, Position, BatchKey, OrderKey)
            SELECT @cStation, @cIPAddress, @cPosition, @cChkBatchKey, @cOrderKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 99707
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log fail
               GOTO RollBackTran
            END
   
            FETCH NEXT FROM @curOrder INTO @cOrderKey, @cPreassignPos
         END
   
         COMMIT TRAN rdt_PTLStation_Assign
      END
   END
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_PTLStation_Assign

Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO
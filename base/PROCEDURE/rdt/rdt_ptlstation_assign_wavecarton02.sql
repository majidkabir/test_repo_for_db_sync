SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_PTLStation_Assign_WaveCarton02                        */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 25-04-2018 1.0  ChewKP   WMS-4538 Created                                  */
/* 06-12-2023 1.1  Ung      WMS-24310 Many minor bugs fix. Clean up source    */
/******************************************************************************/

CREATE   PROC rdt.rdt_PTLStation_Assign_WaveCarton02 (
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

   DECLARE @cWaveKey       NVARCHAR(10)
   DECLARE @cOrderKey      NVARCHAR(10)
   DECLARE @cStation       NVARCHAR(10)
   DECLARE @cIPAddress     NVARCHAR(40)
   DECLARE @cPosition      NVARCHAR(10)
   DECLARE @cCartonID      NVARCHAR(20)
   DECLARE @cLOC           NVARCHAR(10)
   DECLARE @nTotalOrder    INT
   DECLARE @nTotalCarton   INT
   DECLARE @curPTLAssign   CURSOR

   SET @nTranCount = @@TRANCOUNT

   /***********************************************************************************************
                                                POPULATE
   ***********************************************************************************************/
   IF @cType = 'POPULATE-IN'
   BEGIN
      -- Get total
      SELECT @nTotalOrder = COUNT(1)
      FROM rdt.rdtPTLStationLog WITH (NOLOCK)
      WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)

      SELECT @nTotalCarton = COUNT(1)
      FROM rdt.rdtPTLStationLog WITH (NOLOCK)
      WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
         AND CartonID <> ''

      -- Assigned
      IF @nTotalOrder > 0
      BEGIN
         -- Get assigned data
         SELECT TOP 1
            @cWaveKey = WaveKey,
            @cStation = Station,
            @cPosition = '', --Position,
            @cLOC      = ''  -- Loc
         FROM rdt.rdtPTLStationLog WITH (NOLOCK)
         WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
         ORDER BY RowRef

         -- Fully assigned
         IF @nTotalOrder = @nTotalCarton
         BEGIN
   	      SET @cFieldAttr01 = 'O' -- WaveKey
            SET @cFieldAttr03 = 'O' -- LOC
            SET @cFieldAttr04 = 'O' -- Carton
         END

         -- Partial assigned
         ELSE
         BEGIN
   	      SET @cFieldAttr01 = 'O' -- WaveKey
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- LOC
         END
      END
      ELSE
      BEGIN
         SET @cWaveKey = ''
         SET @cStation = ''
         SET @cPosition = ''
         SET @cCartonID = ''

   	   EXEC rdt.rdtSetFocusField @nMobile, 1 -- WaveKey
      END

		-- Prepare next screen var
		SET @cOutField01 = @cWaveKey
		SET @cOutField02 = @cStation
		SET @cOutField03 = @cLOC
		SET @cOutField04 = @cCartonID
		SET @cOutField05 = CAST( @nTotalOrder AS NVARCHAR(5))
		SET @cOutField06 = CAST( @nTotalCarton AS NVARCHAR(5))

		-- Go to load consignee carton screen
		SET @nScn = 4495
   END

   IF @cType = 'POPULATE-OUT'
   BEGIN
      -- Enable field
      SET @cFieldAttr01 = '' -- cWaveKey
      SET @cFieldAttr03 = '' -- LOC
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
      SET @cStation = @cOutField02
      SET @cLOC     = CASE WHEN @cFieldAttr03 = '' THEN @cInField03 ELSE @cOutField03 END
      SET @cCartonID = CASE WHEN @cFieldAttr04 = '' THEN @cInField04 ELSE @cOutField04 END

      -- Get total
      SELECT @nTotalOrder = COUNT(1)
      FROM rdt.rdtPTLStationLog WITH (NOLOCK)
      WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)

      SELECT @nTotalCarton = COUNT(1)
      FROM rdt.rdtPTLStationLog WITH (NOLOCK)
      WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
         AND CartonID <> ''

      -- Check finish assign
      IF @nTotalCarton > 0 AND @nTotalOrder = @nTotalCarton AND @cWaveKey = '' AND @cCartonID = ''
      BEGIN
         SET @cFieldAttr01 = '' -- cWaveKey
         SET @cFieldAttr04 = '' -- CartonID
         GOTO Quit
      END

      -- WaveKey enabled
      IF @cFieldAttr01 = ''
      BEGIN
   		-- Check blank
   		IF @cWaveKey = ''
         BEGIN
            SET @nErrNo = 123501
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need WaveKey
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- WaveKey
            GOTO Quit
         END

         -- Check wave valid
         IF NOT EXISTS( SELECT 1 FROM dbo.Wave (NOLOCK) WHERE WaveKey = @cWaveKey)
         BEGIN
            SET @nErrNo = 123502
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidWaveKey
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- WaveKey
            GOTO Quit
         END

         -- Check wave assigned (in other station)
         IF EXISTS( SELECT 1 
            FROM rdt.rdtPTLstationLog WITH (NOLOCK)
            WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
               AND WaveKey <> @cWaveKey)
         BEGIN
           SET @nErrNo = 123503
           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --StationUnassig
           EXEC rdt.rdtSetFocusField @nMobile, 1 -- WaveKey
           GOTO Quit
         END

         -- Get total orders
         SELECT @nTotalOrder = COUNT( DISTINCT O.OrderKey)
         FROM dbo.Orders O WITH (NOLOCK)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
         WHERE O.UserDefine09 = @cWaveKey
            AND O.StorerKey = @cStorerKey
            AND O.Facility = @cFacility
            AND O.Status <> 'CANC'
            AND O.SOStatus <> 'CANC'
            AND PD.Status = '3'
            AND PD.CaseID = ''
            AND PD.QTY > 0

         -- Check wave no task
         IF @nTotalOrder = 0
         BEGIN
            SET @nErrNo = 123504
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Wave no task
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- WaveKey
            SET @cOutField01 = ''
            GOTO Quit
         END

         -- Get total positions
         DECLARE @nTotalLOC INT
         SELECT @nTotalLOC = COUNT(1) 
         FROM dbo.DeviceProfile WITH (NOLOCK)
         WHERE DeviceType = 'STATION'
            AND DeviceID IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
         
         -- Check enough positions
         IF @nTotalOrder > @nTotalLOC
         BEGIN
            SET @nErrNo = 123505
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not enuf LOC
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- WaveKey
            SET @cOutField01 = ''
            GOTO Quit
         END
         
         -- Temporary assign as 
         SELECT @cStation = 
            CASE WHEN @cStation1 <> '' THEN @cStation1
                 WHEN @cStation2 <> '' THEN @cStation2
                 WHEN @cStation3 <> '' THEN @cStation3
                 WHEN @cStation4 <> '' THEN @cStation4
                 WHEN @cStation5 <> '' THEN @cStation5
            END
         
         -- Loop orders in wave
         SET @curPTLAssign = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT WD.OrderKey
            FROM dbo.WaveDetail WD WITH (NOLOCK)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = WD.OrderKey)
            WHERE WD.Wavekey = @cWaveKey
               AND PD.UOM <> '2'
            GROUP BY WD.OrderKey
         OPEN @curPTLAssign
         FETCH NEXT FROM @curPTLAssign INTO @cOrderKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            -- Save assign (only order, without LOC and carton ID)
            INSERT INTO rdt.rdtPTLStationLog (Station, IPAddress, Position, CartonID, Method, WaveKey, OrderKey, StorerKey)
            VALUES (@cStation, '', '', '', @cMethod, @cWaveKey, @cOrderKey, @cStorerKey)
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 123506
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log Fail
               EXEC rdt.rdtSetFocusField @nMobile, 1 -- WaveKey
               SET @cOutField01 = ''
               GOTO Quit
            END

            FETCH NEXT FROM @curPTLAssign INTO @cOrderKey
         END

         SELECT @nTotalOrder = COUNT(1)
         FROM rdt.rdtPTLStationLog WITH (NOLOCK)
         WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)

         SELECT @nTotalCarton = COUNT(1)
         FROM rdt.rdtPTLStationLog WITH (NOLOCK)
         WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
            AND CartonID <> ''

         -- Prepare current screen var
         SET @cOutField01 = @cWaveKey
         SET @cOutField02 = @cStation
         SET @cOutField03 = '' -- LOC
         SET @cOutField04 = '' -- CartonID
         SET @cOutField05 = CAST( @nTotalOrder AS NVARCHAR(5))
         SET @cOutField06 = CAST( @nTotalCarton AS NVARCHAR(5))

         -- Enable disable field
         SET @cFieldAttr01 = 'O' -- WaveKey
         SET @cFieldAttr03 = ''  -- LOC
         SET @cFieldAttr04 = ''  -- CartonID

         -- Stay in current page
         SET @nErrNo = -1
         GOTO Quit
      END

      -- Position Field enabled
      IF @cFieldAttr03 = ''
      BEGIN
         -- Check blank
         IF @cLOC = ''
         BEGIN
            SET @nErrNo = 123507
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need LOC
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- LOC
            SET @cOutField03 = ''
            GOTO Quit
         END

         -- Get LOC info
         SELECT @cStation = DeviceID
         FROM dbo.DeviceProfile WITH (NOLOCK)
         WHERE DeviceType = 'STATION'
            AND DeviceID IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
            AND LOC = @cLOC
               
         -- Check LOC valid
         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 123508
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOC
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- LOC
            SET @cOutField03 = ''
            GOTO Quit
         END

         -- Check LOC assigned
         IF EXISTS( SELECT 1 
            FROM rdt.rdtPTLStationLog WITH (NOLOCK)
            WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
               AND WaveKey = @cWaveKey
               AND LOC = @cLOC)
         BEGIN
            SET @nErrNo = 123509
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOC Assigned
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- LOC
            SET @cOutField03 = ''
            GOTO Quit
         END
         
         SET @cOutField02 = @cStation
         SET @cOutField03 = @cLOC
      END

      -- CartonID field enabled
      IF @cFieldAttr04 = ''
      BEGIN
         -- Check blank tote
         IF @cCartonID = ''
         BEGIN
            SET @nErrNo = 123510
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need CartonID
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- CartonID
            SET @cOutField04 = ''
            GOTO Quit
         END

         -- Check barcode format
         IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'CartonID', @cCartonID) = 0
         BEGIN
            SET @nErrNo = 123511
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- CartonID
            SET @cOutField04 = ''
            GOTO Quit
         END

         -- Check carton assigned
         IF EXISTS( SELECT 1
            FROM rdt.rdtPTLStationLog WITH (NOLOCK)
            WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
               AND CartonID = @cCartonID
               AND WaveKey = @cWaveKey)
         BEGIN
            SET @nErrNo = 123512
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CartonID used
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- CartonID
            SET @cOutField04 = ''
            GOTO Quit
         END

         -- Get any order not yet assign (LOC, carton ID)
         SELECT TOP 1 
            @cOrderKey = OrderKey
         FROM rdt.rdtPTLStationLog WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND Station = @cStation
            AND CartonID = ''
         ORDER BY RowRef

         -- Get LOC info
         SELECT TOP 1 
            @cIPAddress = IPAddress, 
            @cPosition = DevicePosition
         FROM DeviceProfile WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND DeviceID = @cStation
            AND LOC = @cLOC

         -- Save assign (LOC, carton ID) for that order
         UPDATE rdt.rdtPTLStationLog SET
            Station = @cStation, -- Need to overwrite the initial random station
            IPAddress = @cIPAddress,
            Position = @cPosition,
            LOC = @cLOC,
            CartonID = @cCartonID,
            EditWho = SUSER_SNAME(),
            EditDate = GETDATE()
         WHERE Station = @cStation
            AND OrderKey = @cOrderKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 123513
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Log fail
            GOTO Quit
         END

         SET @cOutField04 = @cCartonID
      END

      -- Get Total
      SELECT @nTotalOrder = COUNT(1)
      FROM rdt.rdtPTLStationLog WITH (NOLOCK)
      WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)

      SELECT @nTotalCarton = COUNT(1)
      FROM rdt.rdtPTLStationLog WITH (NOLOCK)
      WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
         AND CartonID <> ''

      -- Check finish assign
      IF @nTotalOrder > 0 AND @nTotalOrder = @nTotalCarton
      BEGIN
         -- Enable field
         SET @cFieldAttr01 = '' -- WaveKey
         SET @cFieldAttr03 = '' -- LOC
         SET @cFieldAttr04 = '' -- CartonID

         GOTO Quit
      END

      -- Prepare current screen var
      SET @cOutField01 = @cWaveKey
      SET @cOutField02 = @cStation
      SET @cOutField03 = '' -- LOC
      SET @cOutField04 = '' -- CartonID
      SET @cOutField05 = CAST( @nTotalOrder AS NVARCHAR(5))
      SET @cOutField06 = CAST( @nTotalCarton AS NVARCHAR(5))

      EXEC rdt.rdtSetFocusField @nMobile, 3 -- LOC

      -- Stay in current page
      SET @nErrNo = -1
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_PTLStation_Assign

Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO
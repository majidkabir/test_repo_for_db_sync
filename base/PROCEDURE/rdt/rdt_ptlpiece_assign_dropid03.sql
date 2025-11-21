SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_PTLPiece_Assign_DropID03                              */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 09-09-2021 1.0  Chermaine  WMS-17331 Created                               */
/* 12-05-2022 1.1  Ung        WMS-19619 Remove pre-assign LOC                 */
/* 22-09-2022 1.2  Ung        WMS-19619 Check drop ID belong to station       */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_PTLPiece_Assign_DropID03] (
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

   DECLARE @cDropID      NVARCHAR(20)
   DECLARE @cBatchKey    NVARCHAR(20)
   DECLARE @cChkBatchKey NVARCHAR(20)
   DECLARE @cOrderKey    NVARCHAR(10)
   DECLARE @cWaveKey     NVARCHAR(10)
   DECLARE @nTotalDropID INT
   DECLARE @cIPAddress   NVARCHAR(40)
   DECLARE @cPosition    NVARCHAR(10)
   DECLARE @cDPLoc       NVARCHAR(10)
   DECLARE @cUserID      NVARCHAR(20)
   DECLARE @cCartonID    NVARCHAR(20)
   DECLARE @cTotalBatchOrder  NVARCHAR(5)
   DECLARE @cToTalNotSorted   NVARCHAR(5)
   DECLARE @cSortedQty   NVARCHAR(5)
   DECLARE @cToTalQty    NVARCHAR(5)
   DECLARE @cToTalOpen   NVARCHAR(5)
   DECLARE @cLightMode   NVARCHAR(4)
   DECLARE @bSuccess     INT
   DECLARE @cLight       NVARCHAR(1)


   /***********************************************************************************************
                                       POPULATE-IN
   ***********************************************************************************************/
   IF @cType = 'POPULATE-IN'
   BEGIN
      -- Get stat
      SELECT @nTotalDropID = COUNT(1) FROM rdt.rdtPTLPieceLog WITH (NOLOCK) WHERE Station = @cStation AND Method = @cMethod AND SourceKey <> ''

      --Get Display Info
      SET @cBatchKey = ''
      SELECT
         @cBatchKey = BatchKey,
         @cDropID = DropID
      FROM rdt.rdtPTLPieceLog WITH (NOLOCK)
      WHERE Station = @cStation

      SELECT TOP 1
         @cWaveKey = PD.waveKey,
         @cOrderKey = PD.OrderKey
      FROM PICKDETAIL PD WITH (NOLOCK)
      JOIN PackTask PT WITH (NOLOCK) ON (PD.orderKey = PT.OrderKey )
      WHERE DropID = @cDropID
      AND caseID <> 'Sorted'

      SELECT
          @cTotalBatchOrder = COUNT (DISTINCT OrderKey)
      FROM packTask (NOLOCK) WHERE taskBatchNo = @cBatchKey
      IF @@ROWCOUNT = 0
      SET @cTotalBatchOrder = '0'


      SELECT
         @cToTalNotSorted = COUNT (DISTINCT PD.OrderKey)
      FROM Orders O WITH (NOLOCK)
         JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
         --LEFT JOIN rdt.rdtPTLPieceLog L WITH (NOLOCK) ON (L.OrderKey = O.OrderKey AND L.Station = @cStation)
         JOIN PackTask PT WITH (NOLOCK) ON (PD.orderKey = PT.OrderKey )
      WHERE PT.taskBatchNo = @cBatchKey
         AND PD.Status <> '4'
         AND O.Status <> 'CANC'
         AND O.SOStatus <> 'CANC'
         AND PD.CaseID <> 'Sorted'
      GROUP BY PD.storerKey ,  PD.Orderkey
      IF @@ROWCOUNT = 0
      SET @cToTalNotSorted = '0'

      SELECT
         @cToTalQty = SUM(Qty)
      FROM Orders O WITH (NOLOCK)
         JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
         --LEFT JOIN rdt.rdtPTLPieceLog L WITH (NOLOCK) ON (L.OrderKey = O.OrderKey AND L.Station = @cStation)
         JOIN PackTask PT WITH (NOLOCK) ON (PD.orderKey = PT.OrderKey )
      WHERE PT.taskBatchNo = @cBatchKey
         AND PD.Status <> '4'
         AND O.Status <> 'CANC'
         AND O.SOStatus <> 'CANC'
      GROUP BY PD.storerKey ,  PD.Orderkey
      IF @@ROWCOUNT = 0
      SET @cToTalQty = '0'

      SELECT
         @cSortedQty = SUM(Qty)
      FROM Orders O WITH (NOLOCK)
         JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
         LEFT JOIN rdt.rdtPTLPieceLog L WITH (NOLOCK) ON (L.OrderKey = O.OrderKey AND L.Station = @cStation)
         JOIN PackTask PT WITH (NOLOCK) ON (L.batchKey = PT.TaskBatchNo)
      WHERE PT.taskBatchNo = @cBatchKey
         AND PD.Status <> '4'
         AND O.Status <> 'CANC'
         AND O.SOStatus <> 'CANC'
         AND PD.CaseID = 'Sorted'
      GROUP BY PD.storerKey ,  PD.Orderkey
      IF @@ROWCOUNT = 0
      SET @cSortedQty = '0'

      -- Go to batch screen
      SET @nScn = 4602

      IF @nScn = 4601  --wave/cartonID screen
      BEGIN
         SET @cFieldAttr01 = 'o'  -- WaveKey
         SET @cOutField01 = @cWaveKey
         SET @cOutField02 = @cOrderKey
         SET @cOutField03 = @cPosition
         SET @cOutField04 = '' --cartonID
         SET @cOutField05 = ''
         SET @cOutField06 = ''
      END
      ELSE
      BEGIN
       SET @cToTalOpen = CONVERT(INT,@cTotalBatchOrder) - CONVERT(INT,@cToTalNotSorted)
         -- Prepare current screen var
         SET @cFieldAttr01 = ''
         SET @cOutField01 = '' -- DropID
         SET @cOutField02 = CAST( @nTotalDropID AS NVARCHAR(5))
         SET @cOutField03 = 'WaveID: ' + @cWaveKey
         SET @cOutField04 = 'TskBatch#:' + @cBatchKey
         SET @cOutField05 = 'Open/TtlOrd: ' + @cToTalOpen + '/' + @cTotalBatchOrder
         SET @cOutField06 = 'Open/TtlQty: ' + @cSortedQty + '/' + @cToTalQty

         -- Go to dropID screen
        SET @nScn = 4602
      END
   END
   /***********************************************************************************************
                    POPULATE-OUT
   ***********************************************************************************************/

   IF @cType = 'POPULATE-OUT'
   BEGIN
      IF @nScn = 4601  --wave/CartonID scn
      BEGIN
         -- Get stat
         SELECT @nTotalDropID = COUNT(1) FROM rdt.rdtPTLPieceLog WITH (NOLOCK) WHERE Station = @cStation AND Method = @cMethod AND SourceKey <> ''

         --Get Display Info
         SET @cBatchKey = ''
         SELECT
            @cBatchKey = BatchKey,
            @cDropID = DropID
         FROM rdt.rdtPTLPieceLog WITH (NOLOCK)
         WHERE Station = @cStation

         SELECT TOP 1
            @cWaveKey = PD.waveKey,
            @cOrderKey = PD.OrderKey
         FROM PICKDETAIL PD WITH (NOLOCK)
         JOIN PackTask PT WITH (NOLOCK) ON (PD.orderKey = PT.OrderKey )
         WHERE DropID = @cDropID

         SELECT
             @cTotalBatchOrder = COUNT (DISTINCT OrderKey)
         FROM packTask (NOLOCK) WHERE taskBatchNo = @cBatchKey
         IF @@ROWCOUNT = 0
         SET @cTotalBatchOrder = '0'


         SELECT
            @cToTalNotSorted = COUNT (DISTINCT PD.OrderKey)
         FROM Orders O WITH (NOLOCK)
            JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
            --LEFT JOIN rdt.rdtPTLPieceLog L WITH (NOLOCK) ON (L.OrderKey = O.OrderKey AND L.Station = @cStation)
            JOIN PackTask PT WITH (NOLOCK) ON (PD.orderKey = PT.OrderKey )
         WHERE PT.taskBatchNo = @cBatchKey
            AND PD.Status <> '4'
            AND O.Status <> 'CANC'
            AND O.SOStatus <> 'CANC'
            AND PD.CaseID <> 'Sorted'
         GROUP BY PD.storerKey ,  PD.Orderkey
         IF @@ROWCOUNT = 0
            SET @cToTalNotSorted = '0'

         SELECT
            @cToTalQty = SUM(Qty)
         FROM Orders O WITH (NOLOCK)
            JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
            --LEFT JOIN rdt.rdtPTLPieceLog L WITH (NOLOCK) ON (L.OrderKey = O.OrderKey AND L.Station = @cStation)
            JOIN PackTask PT WITH (NOLOCK) ON (PD.orderKey = PT.OrderKey )
         WHERE PT.taskBatchNo = @cBatchKey
            AND PD.Status <> '4'
            AND O.Status <> 'CANC'
            AND O.SOStatus <> 'CANC'
         GROUP BY PD.storerKey ,  PD.Orderkey
         IF @@ROWCOUNT = 0
         SET @cToTalQty = '0'

         SELECT
            @cSortedQty = SUM(Qty)
         FROM Orders O WITH (NOLOCK)
            JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
            LEFT JOIN rdt.rdtPTLPieceLog L WITH (NOLOCK) ON (L.OrderKey = O.OrderKey AND L.Station = @cStation)
            JOIN PackTask PT WITH (NOLOCK) ON (L.batchKey = PT.TaskBatchNo)
         WHERE PT.taskBatchNo = @cBatchKey
            AND PD.Status <> '4'
            AND O.Status <> 'CANC'
            AND O.SOStatus <> 'CANC'
            AND PD.CaseID = 'Sorted'
         GROUP BY PD.storerKey ,  PD.Orderkey
         IF @@ROWCOUNT = 0
         SET @cSortedQty = '0'

         SET @cToTalOpen = CONVERT(INT,@cTotalBatchOrder) - CONVERT(INT,@cToTalNotSorted)
         -- Prepare next screen var
         SET @cOutField01 = '' -- DropID
         SET @cOutField02 = CAST( @nTotalDropID AS NVARCHAR(5))
         SET @cOutField03 = 'WaveID: ' + @cWaveKey
         SET @cOutField04 = 'TskBatch#:' + @cBatchKey
         SET @cOutField05 = 'Open/TtlOrd: ' + @cToTalOpen + '/' + @cTotalBatchOrder
         SET @cOutField06 = 'Open/TtlQty: ' + @cSortedQty + '/' + @cToTalQty

         SET @nscn=4602  --dropID scn
         SET @nErrNo='-1'
         GOTO quit
      END
   END


   /***********************************************************************************************
                                                 CHECK
   ***********************************************************************************************/
   IF @cType = 'CHECK'
   BEGIN
      IF @nScn = 4602 --dropID scn
      BEGIN
         -- Screen mapping
         SET @cDropID = @cInField01

         -- Check finish assign
         IF @cDropID = '' AND @nTotalDropID > 0
         BEGIN
            GOTO Quit
         END

         -- Check blank
         IF @cDropID = ''
         BEGIN
            SET @nErrNo = 176001
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need DropID
            GOTO Quit
         END

         -- Check DropID valid
         IF NOT EXISTS( SELECT 1 FROM PickDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND DropID = @cDropID)
         BEGIN
            SET @nErrNo = 176002
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad DropID
            SET @cOutField01 = ''
            GOTO Quit
         END

         -- Check DropID assigned to this station
         IF NOT EXISTS( SELECT TOP 1 1 
            FROM PickDetail PD WITH (NOLOCK) 
               JOIN PackTask PT WITH (NOLOCK) ON (PD.OrderKey = PT.OrderKey)
               JOIN DeviceProfile DP WITH (NOLOCK) ON (
                  DP.DeviceType = 'STATION' AND 
                  DP.DeviceID = @cStation AND 
                  DP.DevicePosition = PT.DevicePosition AND 
                  DP.StorerKey = @cStorerKey)
            WHERE PD.StorerKey = @cStorerKey 
               AND PD.DropID = @cDropID)
         BEGIN
            SET @nErrNo = 176011
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Wrong Station
            SET @cOutField01 = ''
            GOTO Quit
         END

         -- Get batch
         SET @cBatchKey = ''
         SELECT @cBatchKey = BatchKey
         FROM rdt.rdtPTLPieceLog WITH (NOLOCK)
         WHERE Station = @cStation

         SELECT TOP 1
            @cChkBatchKey = PT.taskBatchNo,
            @cWaveKey = PD.waveKey
         FROM packTask PT WITH (NOLOCK)
         JOIN pickDetail PD WITH (NOLOCK) ON (PD.OrderKey = PT.Orderkey)
         WHERE PD.Storerkey = @cStorerKey
         AND PD.DropID = @cDropID
         AND caseID <> 'Sorted'
         AND PD.Status < '9'

          -- Assigned
         IF @cBatchKey <> ''
         BEGIN
            -- Check different batch
            IF @cChkBatchKey <> @cBatchKey
            BEGIN
               SET @nErrNo = 176003
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff batch
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
            SET @nErrNo = 176004
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not enuf Pos
            SET @cOutField01 = ''
            GOTO Quit
         END

         --SELECT TOP 1
         --   @cWaveKey = waveKey
         --FROM PICKDETAIL WITH (NOLOCK)
         --WHERE DropID = @cDropID

         SET @cIPAddress = ''

         -- Loop orders
         DECLARE @curOrder CURSOR
         SET @curOrder = CURSOR FOR
            SELECT DISTINCT PD.OrderKey
            FROM PackTask PT WITH (NOLOCK)
            JOIN PICKDETAIL PD WITH (NOLOCK) ON (PT.Orderkey = PD.OrderKey)
            WHERE PD.DropID = @cDropID
            AND PD.Storerkey = @cStorerKey
            AND PD.CaseID <> 'Sorted'
          AND PT.TaskBatchNo = @cChkBatchKey
            ORDER BY PD.OrderKey
         OPEN @curOrder
         FETCH NEXT FROM @curOrder INTO @cOrderKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            -- Get position not yet assign
            SET @cPosition = ''
            SELECT TOP 1
               @cIPAddress = DP.IPAddress,
               @cPosition = DP.DevicePosition,
               @cDPLoc = DP.Loc
            FROM dbo.DeviceProfile DP WITH (NOLOCK)
            WHERE DP.DeviceType = 'STATION'
               AND DP.DeviceID = @cStation
               AND NOT EXISTS( SELECT 1
                  FROM rdt.rdtPTLPieceLog Log WITH (NOLOCK)
                  WHERE Log.Station = @cStation
                     AND Log.Position = DP.DevicePosition)
            ORDER BY DP.LogicalPos, DP.DevicePosition

            IF ISNULL(@cDPLoc,'') = ''
            BEGIN
               SET @nErrNo = 176007
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid DPloc
               GOTO Quit
            END

            -- get same CartonID in same wave but diff toteID
            SELECT
               @cCartonID  = CartonID
            FROM rdt.rdtPTLPieceLog WITH (NOLOCK)
            WHERE station = @cStation
            AND position = @cPosition
            AND Loc = @cDPLoc
            AND waveKey = @cWaveKey
            AND OrderKey = @cOrderKey
            AND CartonID <> ''

            IF @@ROWCOUNT = 0
            BEGIN
             SET @cCartonID = ''
            END


            IF NOT EXISTS (SELECT 1 FROM rdt.rdtPTLPieceLog WITH (NOLOCK) WHERE storerKey = @cStorerKey AND OrderKey = @cOrderKey)
            BEGIN
             -- Save assign
               INSERT rdt.rdtPTLPieceLog (Station, IPAddress, Position, BatchKey, OrderKey, dropID, LOC, waveKey,StorerKey,cartonID)
               SELECT @cStation, @cIPAddress, @cPosition, @cChkBatchKey, @cOrderKey, @cDropID,@cDPLoc, @cWaveKey, @cStorerKey, @cCartonID
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 176005
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log fail
                  GOTO Quit
               END
            END
            ELSE
            BEGIN
               UPDATE rdt.rdtPTLPieceLog WITH (ROWLOCK)
               set dropid=@cDropID,
               editdate=GETDATE()
               WHERE storerKey = @cStorerKey
               AND OrderKey = @cOrderKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 176005
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log fail
                  GOTO Quit
               END
            END


            FETCH NEXT FROM @curOrder INTO @cOrderKey
         END

         -- Get total
         SELECT @nTotalDropID = COUNT(1) FROM rdt.rdtPTLPieceLog WITH (NOLOCK) WHERE Station = @cStation AND Method = @cMethod AND SourceKey <> ''

         --Get Display Info
         SELECT
             @cTotalBatchOrder = COUNT (DISTINCT OrderKey)
         FROM packTask (NOLOCK) WHERE taskBatchNo = @cChkBatchKey
         IF @@ROWCOUNT = 0
         SET @cTotalBatchOrder = '0'

         SELECT
            @cToTalNotSorted = COUNT (DISTINCT PD.OrderKey)
         FROM Orders O WITH (NOLOCK)
            JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
            LEFT JOIN rdt.rdtPTLPieceLog L WITH (NOLOCK) ON (L.OrderKey = O.OrderKey AND L.Station = @cStation)
            JOIN PackTask PT WITH (NOLOCK) ON (L.batchKey = PT.TaskBatchNo)
         WHERE PT.taskBatchNo = @cChkBatchKey
            AND PD.Status <> '4'
            AND O.Status <> 'CANC'
            AND O.SOStatus <> 'CANC'
            AND PD.CaseID <> 'Sorted'
         GROUP BY PD.storerKey ,  PD.Orderkey
         IF @@ROWCOUNT = 0
         SET @cToTalNotSorted = '0'

         SELECT
            @cToTalQty = SUM(Qty)
         FROM Orders O WITH (NOLOCK)
            JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
            --LEFT JOIN rdt.rdtPTLPieceLog L WITH (NOLOCK) ON (L.OrderKey = O.OrderKey AND L.Station = @cStation)
            JOIN PackTask PT WITH (NOLOCK) ON (PD.orderKey = PT.OrderKey )
         WHERE PT.taskBatchNo = @cChkBatchKey
            AND PD.Status <> '4'
            AND O.Status <> 'CANC'
            AND O.SOStatus <> 'CANC'
         GROUP BY PD.storerKey ,  PD.Orderkey

         IF @@ROWCOUNT = 0
            SET @cToTalQty = '0'

         SELECT
            @cSortedQty = SUM(Qty)
         FROM Orders O WITH (NOLOCK)
            JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
            --LEFT JOIN rdt.rdtPTLPieceLog L WITH (NOLOCK) ON (L.OrderKey = O.OrderKey AND L.Station = @cStation)
            JOIN PackTask PT WITH (NOLOCK) ON (PD.orderKey = PT.OrderKey )
         WHERE PT.taskBatchNo = @cChkBatchKey
            AND PD.Status <> '4'
            AND O.Status <> 'CANC'
            AND O.SOStatus <> 'CANC'
            AND PD.CaseID = 'Sorted'
         GROUP BY PD.storerKey ,  PD.Orderkey
         IF @@ROWCOUNT = 0
         SET @cSortedQty = '0'

         -- if same wavekey diff order, only need to marry cartonID one time
         IF  EXISTS (SELECT TOP 1 1
                     FROM rdt.rdtPTLPieceLog PTL WITH (NOLOCK)
                        JOIN deviceprofile DP on (PTL.station = DP.deviceid and ptl.position = dp.deviceposition)
                     WHERE DP.deviceid = @cStation
                     --AND PTL.position = @cPosition
                     --AND PTL.Loc = @cDPLoc
                     AND PTL.waveKey = @cWaveKey
                     --AND PTL.OrderKey = @cOrderKey
                     AND PTL.dropID = @cDropID
                     AND PTL.CartonID = '' )
         BEGIN
            SELECT TOP 1
               @cWaveKey = waveKey,
               @cOrderKey = OrderKey,
               @cPosition = Position,
               @cIPAddress=PTL.IPAddress
            FROM rdt.rdtPTLPieceLog PTL (NOLOCK)
            JOIN deviceprofile DP on (PTL.station = DP.deviceid and ptl.position = dp.deviceposition)
            WHERE DP.deviceid = @cStation
            AND cartonID = ''
            ORDER BY DP.logicalname

            SET @nScn = 4601 --wake/cartonID scn
            SET @cFieldAttr01 = 'o'  -- WaveKey
            SET @cOutField01 = @cWaveKey
            SET @cOutField02 = @cOrderKey
            SET @cOutField03 = @cPosition
            SET @cOutField04 = '' --cartonID
            SET @cOutField05 = ''
            SET @cOutField06 = ''
            SET @cInField04 = ''
            --SET @nErrNo = -1
         END
         ELSE
         BEGIN
            SET @cToTalOpen = CONVERT(INT,@cTotalBatchOrder) - CONVERT(INT,@cToTalNotSorted)
            -- Prepare current screen var
            SET @cFieldAttr01 = ''
            SET @cOutField01 = '' -- DropID
            SET @cOutField02 = CAST( @nTotalDropID AS NVARCHAR(5))
            SET @cOutField03 = 'WaveID: ' + @cWaveKey
            SET @cOutField04 = 'TskBatch#:' + @cChkBatchKey
            SET @cOutField05 = 'Open/TtlOrd: ' + @cToTalOpen + '/' + @cTotalBatchOrder
            SET @cOutField06 = 'Open/TtlQty: ' + @cSortedQty + '/' + @cToTalQty
            ---- Stay in current screen
            --SET @nErrNo = -1
         END
    END

    IF @nScn = 4601 --Wave/CartonID scn
    BEGIN
      SELECT @cUserID = username
      from rdt.rdtmobrec WITH (NOLOCK)
      where mobile = @nMobile

      SET @cWaveKey = @cOutField01
      SET @cOrderKey = @cOutField02
      SET @cPosition = @cOutField03
      SET @cCartonID = @cInField04
      SET @cDropID = @cInField01

      --position from prev screen
      IF NOT EXISTS (SELECT TOP 1 1
          FROM rdt.rdtPTLPieceLog PTL WITH (NOLOCK)
           JOIN deviceprofile DP on (PTL.station = DP.deviceid and ptl.position = dp.deviceposition)
          WHERE DP.deviceid = @cStation
          AND PTL.dropID = @cDropID
          AND PTL.waveKey = @cWaveKey
          AND PTL.OrderKey = @cOrderKey
          AND PTL.Position = @cPosition
          AND PTL.CartonID = '' )
      BEGIN
         -- find new position with caseID = ''
         SELECT TOP 1
         @cPosition = PTL.Position
         FROM rdt.rdtPTLPieceLog PTL WITH (NOLOCK)
         JOIN deviceprofile DP on (PTL.station = DP.deviceid and ptl.position = dp.deviceposition)
         WHERE DP.deviceid = @cStation
         AND PTL.dropID = @cDropID
         AND PTL.waveKey = @cWaveKey
         AND PTL.OrderKey = @cOrderKey
         AND PTL.CartonID = ''
         ORDER BY DP.logicalname
      END

      IF @cCartonID <> ''
      BEGIN
         IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'CartonID', @cCartonID) = 0
         BEGIN
            SET @nErrNo = 176010
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid format
            GOTO Quit
         END

         IF EXISTS ( SELECT 1 from  rdt.rdtPTLPieceLog (NOLOCK)
                     WHERE OrderKey = @cOrderKey
                        AND waveKey = @cWaveKey
                        AND CartonID = @cCartonID )
         BEGIN
            SET @nErrNo = 176009
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CartonAssigned
            GOTO Quit
         END


         UPDATE rdt.rdtPTLPieceLog WITH(ROWLOCK) SET
            CartonID = @cCartonID   ,
            editdate=getdate()
         WHERE Position = @cPosition
         AND OrderKey = @cOrderKey
         AND waveKey = @cWaveKey

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 176006
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Log fail
            GOTO Quit
         END


         SELECT TOP 1
         @cPosition = PTL.Position,
         @cOrderKey = PTL.OrderKey,
         @cWaveKey = PTL.waveKey
         FROM rdt.rdtPTLPieceLog PTL WITH (NOLOCK)
         JOIN deviceprofile DP on (PTL.station = DP.deviceid and ptl.position = dp.deviceposition)
         WHERE DP.deviceid = @cStation
         AND PTL.dropID = @cDropID
         AND PTL.CartonID = ''
         ORDER BY DP.logicalname

         IF @@ROWCOUNT = 0
            SET @cPosition = ''

    --END
      END

   --INSERT INTO traceinfo (TraceName,col1)
   --VALUES('cc803',@cPosition)

      IF @cPosition <> ''
      BEGIN
         -- Get light setting
         SET @cLightMode = rdt.RDTGetConfig( @nFunc, 'LightMode', @cStorerKey)

         SELECT
         @cIPAddress = PTL.IPAddress
         FROM rdt.rdtPTLPieceLog PTL WITH (NOLOCK)
         JOIN deviceprofile DP on (PTL.station = DP.deviceid and ptl.position = dp.deviceposition)
         WHERE DP.deviceid = @cStation
         AND PTL.dropID = @cDropID
         AND PTL.Position = @cPosition
         AND PTL.CartonID = ''

         IF EXISTS ( SELECT 1 FROM rdt.rdtMobRec WITH (NOLOCK)
         WHERE Mobile = @nMobile
         AND Func = @nFunc
         AND DeviceID <> '' )
         BEGIN
            SET @cLight = '1' -- Use light
         END
         ELSE
         BEGIN
            SET @cLight = '0' -- Not use
         END

         IF @cLight  = '1'
         BEGIN
            -- Off all lights
            EXEC PTL.isp_PTL_TerminateModule
               @cStorerKey
            ,@nFunc
            ,@cStation
            ,'STATION'
            ,@bSuccess    OUTPUT
            ,@nErrNo       OUTPUT
            ,@cErrMsg      OUTPUT
            IF @nErrNo <> 0
               GOTO Quit

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
      END

      IF EXISTS (SELECT TOP 1 1
         FROM rdt.rdtPTLPieceLog PTL WITH (NOLOCK)
          JOIN deviceprofile DP on (PTL.station = DP.deviceid and ptl.position = dp.deviceposition)
         WHERE DP.deviceid = @cStation
         AND PTL.dropID = @cDropID
         AND position = @cPosition
         AND PTL.CartonID = '' )
      BEGIN
      --   SELECT TOP 1
      --      @cWaveKey = waveKey,
      --      @cOrderKey = OrderKey,
      --      --@cPosition = Position,
      --      @cIPAddress=IPAddress
      --   FROM rdt.rdtPTLPieceLog (NOLOCK)
      --   WHERE EditWho = @cUserID
      --   AND Position = @cPosition
      --   ORDER BY EditDate DESC
      --END
      --ELSE
      --BEGIN
      --   SELECT TOP 1
      --      @cWaveKey = waveKey,
      --      @cOrderKey = OrderKey,
      --      @cPosition = Position,
      --      @cIPAddress=IPAddress
      --   FROM rdt.rdtPTLPieceLog (NOLOCK)
      --   WHERE EditWho = @cUserID
      --   --AND Position = @cPosition
      --   ORDER BY EditDate DESC
      --END
         IF @nInputKey = '1'
         BEGIN
            SET @cFieldAttr01 = 'o'  -- WaveKey
         END
         ELSE
         BEGIN
            SET @cFieldAttr01 = ''  -- Option
         END

         --SET @cFieldAttr01 = 'o'  -- WaveKey
         SET @cOutField01 = @cWaveKey
         SET @cOutField02 = @cOrderKey
         SET @cOutField03 = @cPosition
         SET @cOutField04 = '' --cartonID
         SET @cOutField05 = ''
         SET @cOutField06 = ''
         SET @nErrNo = -1
      END

   END
END

Quit:

END

GO
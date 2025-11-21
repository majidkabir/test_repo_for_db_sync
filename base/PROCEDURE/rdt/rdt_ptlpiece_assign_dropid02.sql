SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_PTLPiece_Assign_DropID02                              */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 09-07-2021 1.0  Chermaine  WMS-17331 Created                               */
/******************************************************************************/

CREATE PROC [RDT].[rdt_PTLPiece_Assign_DropID02] (
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
   DECLARE @cTotalBatchOrder  NVARCHAR(5)
   DECLARE @cToTalNotSorted   NVARCHAR(5)
   DECLARE @cToTalSorted      NVARCHAR(5)
   DECLARE @cSortedQty        NVARCHAR(5)
   DECLARE @cOpenQty          NVARCHAR(5)
   DECLARE @cToTalQty         NVARCHAR(5)
   DECLARE @cToTalOpen        NVARCHAR(5)
  

   /***********************************************************************************************
                                                POPULATE
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
         @cWaveKey = waveKey 
      FROM PICKDETAIL WITH (NOLOCK)
      WHERE DropID = @cDropID
      AND caseID <> 'sorted'
      AND Status < '9'
      
		SELECT 
          @cTotalBatchOrder = COUNT (DISTINCT OrderKey)
      FROM packTask (NOLOCK) WHERE taskBatchNo = @cBatchKey
		
         
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
      GROUP BY PD.storerKey --,  PD.Orderkey
      
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
         --AND O.OrderKey = @cOrderKey
      GROUP BY PD.storerKey-- ,  PD.Orderkey
      
      SELECT 
         @cSortedQty = SUM(Qty)
      FROM Orders O WITH (NOLOCK) 
         JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
         --LEFT JOIN rdt.rdtPTLPieceLog L WITH (NOLOCK) ON (L.OrderKey = O.OrderKey AND L.Station = @cStation)
         JOIN PackTask PT WITH (NOLOCK) ON (PD.orderKey = PT.OrderKey )--(L.batchKey = PT.TaskBatchNo)
      WHERE PT.taskBatchNo = @cBatchKey
         AND PD.Status <> '4'
         AND O.Status <> 'CANC' 
         AND O.SOStatus <> 'CANC'
         AND PD.CaseID = 'Sorted'
         --AND O.OrderKey = @cOrderKey
      GROUP BY PD.storerKey --,  PD.Orderkey
      
      
      SET @cToTalOpen = CONVERT(INT,@cTotalBatchOrder) - CONVERT(INT,@cToTalNotSorted)
      -- Prepare current screen var
      SET @cOutField01 = '' -- DropID
      SET @cOutField02 = CAST( @nTotalDropID AS NVARCHAR(5))
      SET @cOutField03 = 'WaveID: ' + @cWaveKey
      SET @cOutField04 = 'TskBatch#:' + @cBatchKey
      SET @cOutField05 = 'Sort/TtlOrd: ' + @cToTalOpen + '/' + @cTotalBatchOrder
      SET @cOutField06 = 'Sort/TtlQty: ' + @cSortedQty + '/' + @cToTalQty
      		
		-- Go to batch screen
		SET @nScn = 4602
   END
      
/*
   IF @cType = 'POPULATE-OUT'
   BEGIN

		-- Go to station screen
   END
*/
   
   /***********************************************************************************************
                                                 CHECK
   ***********************************************************************************************/
   IF @cType = 'CHECK'
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
         SET @nErrNo = 170901
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need DropID
         GOTO Quit
      END
   
      -- Check DropID valid
      IF NOT EXISTS( SELECT 1 FROM PickDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND DropID = @cDropID)
      BEGIN
         SET @nErrNo = 170902
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad DropID
         SET @cOutField01 = ''
         GOTO Quit
      END
      
      -- Get batch   
      SET @cBatchKey = ''  
      SELECT @cBatchKey = BatchKey  
      FROM rdt.rdtPTLPieceLog WITH (NOLOCK)   
      WHERE Station = @cStation 
      
      SELECT 
         @cChkBatchKey = taskBatchNo
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
            SET @nErrNo = 170903  
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
         SET @nErrNo = 170904  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not enuf Pos  
         SET @cOutField01 = ''  
         GOTO Quit  
      END   
      
      
      SET @cIPAddress = '' 
  
      -- Loop orders  
      DECLARE @cPreassignPos NVARCHAR(10)  
      DECLARE @curOrder CURSOR  
      SET @curOrder = CURSOR FOR  
         SELECT DISTINCT PD.OrderKey, PT.DevicePosition
         FROM PackTask PT WITH (NOLOCK)   
         JOIN PICKDETAIL PD WITH (NOLOCK) ON (PT.Orderkey = PD.OrderKey)
         WHERE PD.DropID = @cDropID
         AND PD.CaseID <> 'SORTED'
         AND PD.Storerkey = @cStorerKey
         ORDER BY PD.OrderKey  
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
               @cDPLoc = DP.Loc    
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
               @cDPLoc = DP.Loc  
            FROM dbo.DeviceProfile DP WITH (NOLOCK)  
            WHERE DP.DeviceType = 'STATION'  
               AND DP.DeviceID = @cStation  
               AND DevicePosition = @cPosition  
         END  
         
         IF ISNULL(@cDPLoc,'') = ''
         BEGIN
         	SET @nErrNo = 170906  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid DPLoc  
            GOTO Quit  
         END 
         
         -- Save assign  
         INSERT rdt.rdtPTLPieceLog (Station, IPAddress, Position, BatchKey, OrderKey, dropID, LOC)  
         SELECT @cStation, @cIPAddress, @cPosition, @cChkBatchKey, @cOrderKey, @cDropID,@cDPLoc  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 170905  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log fail  
            GOTO Quit  
         END  
     
         FETCH NEXT FROM @curOrder INTO @cOrderKey, @cPreassignPos   
      END  

      -- Get total
      SELECT @nTotalDropID = COUNT(1) FROM rdt.rdtPTLPieceLog WITH (NOLOCK) WHERE Station = @cStation AND Method = @cMethod AND SourceKey <> ''
      
      --Get Display Info
      SELECT TOP 1
         @cWaveKey = waveKey 
      FROM PICKDETAIL WITH (NOLOCK)
      WHERE DropID = @cDropID
      AND caseID <> 'sorted'
      AND Status < '9'
      
		SELECT 
          @cTotalBatchOrder = COUNT (DISTINCT OrderKey)
      FROM packTask (NOLOCK) WHERE taskBatchNo = @cBatchKey
		
		SELECT 
         @cToTalNotSorted = COUNT (DISTINCT PD.OrderKey)
      FROM Orders O WITH (NOLOCK) 
         JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
         LEFT JOIN rdt.rdtPTLPieceLog L WITH (NOLOCK) ON (L.OrderKey = O.OrderKey AND L.Station = @cStation)
         JOIN PackTask PT WITH (NOLOCK) ON (L.batchKey = PT.TaskBatchNo)
      WHERE PT.taskBatchNo = @cBatchKey
         AND PD.Status <> '4'
         AND O.Status <> 'CANC' 
         AND O.SOStatus <> 'CANC'
         AND PD.CaseID <> 'Sorted'
      GROUP BY PD.storerKey-- ,  PD.Orderkey
      
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
         AND O.OrderKey = @cOrderKey
      GROUP BY PD.storerKey --,  PD.Orderkey
      
      SELECT 
         @cSortedQty = SUM(Qty)
      FROM Orders O WITH (NOLOCK) 
         JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
         --LEFT JOIN rdt.rdtPTLPieceLog L WITH (NOLOCK) ON (L.OrderKey = O.OrderKey AND L.Station = @cStation)
         JOIN PackTask PT WITH (NOLOCK) ON (PD.orderKey = PT.OrderKey )
      WHERE PT.taskBatchNo = @cBatchKey
         AND PD.Status <> '4'
         AND O.Status <> 'CANC' 
         AND O.SOStatus <> 'CANC'
         AND PD.CaseID = 'Sorted'
         AND O.OrderKey = @cOrderKey
      GROUP BY PD.storerKey ,  PD.Orderkey
      
      SET @cToTalOpen = CONVERT(INT,@cTotalBatchOrder) - CONVERT(INT,@cToTalNotSorted)
      -- Prepare current screen var
      SET @cOutField01 = '' -- DropID
      SET @cOutField02 = CAST( @nTotalDropID AS NVARCHAR(5))
      SET @cOutField03 = 'WaveID: ' + @cWaveKey
      SET @cOutField04 = 'TskBatch#:' + @cBatchKey
      SET @cOutField05 = 'Sort/TtlOrd: ' + @cToTalOpen + '/' + @cTotalBatchOrder
      SET @cOutField06 = 'Sort/TtlQty: ' + @cSortedQty + '/' + @cToTalQty
      ---- Stay in current screen
      --SET @nErrNo = -1 

   END

Quit:

END

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_PTLStation_CreateTask_ToteIDSKU03               */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Date       Rev Author      Purposes                                  */
/* 19-02-2018 1.0 ChewKP      WMS-3962 Created                          */
/************************************************************************/

CREATE PROC [RDT].[rdt_PTLStation_CreateTask_ToteIDSKU03] (
    @nMobile      INT
   ,@nFunc        INT
   ,@cLangCode    NVARCHAR(3)
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cFacility    NVARCHAR(5)
   ,@cStorerKey   NVARCHAR(15)
   ,@cType        NVARCHAR(20)  
   ,@cLight       NVARCHAR(1)   -- 0 = no light, 1 = use light
   ,@cStation1    NVARCHAR(10)  
   ,@cStation2    NVARCHAR(10)  
   ,@cStation3    NVARCHAR(10)  
   ,@cStation4    NVARCHAR(10)  
   ,@cStation5    NVARCHAR(10)  
   ,@cMethod      NVARCHAR(10)
   ,@cScanID      NVARCHAR(20)      OUTPUT
   ,@cCartonID    NVARCHAR(20)
   ,@nErrNo       INT               OUTPUT
   ,@cErrMsg      NVARCHAR(20)      OUTPUT
   ,@cScanSKU     NVARCHAR(20) = '' OUTPUT
   ,@cSKUDescr    NVARCHAR(60) = '' OUTPUT
   ,@nQTY         INT          = 0  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount     INT
   DECLARE @bSuccess       INT
   DECLARE @cSQL           NVARCHAR( MAX)
   DECLARE @cSQLParam      NVARCHAR( MAX)
   
   DECLARE @cOrderKey      NVARCHAR( 10)
   DECLARE @nPDQTY         INT
   DECLARE @nPTLQty        INT

   DECLARE @nRowRef      INT
   --DECLARE @cIPAddress   NVARCHAR(40)
   --DECLARE @cPosition    NVARCHAR(10)
   --DECLARE @cStation     NVARCHAR(10)
   --DECLARE @cDropID      NVARCHAR(20)
   
   DECLARE @cStation       NVARCHAR(10)
   DECLARE @cIPAddress     NVARCHAR(40)
   DECLARE @cPosition      NVARCHAR(10)
   DECLARE @cWaveKey       NVARCHAR(10)
          ,@cSuggSKU       NVARCHAR(20)
          ,@cSuggWaveKey   NVARCHAR(10) 
		    ,@cToLoc		   NVARCHAR(10) 
		    ,@cStyle         NVARCHAR(20)
		    ,@cFinalLoc      NVARCHAR(10)
          ,@cSuggToLoc     NVARCHAR(10) 
          
   
   SET @nErrNo = 0 

   DECLARE @tOrders TABLE
   (
        WaveKey NVARCHAR(10) NOT NULL
      , SKU     NVARCHAR(20) NOT NULL
   )
      
   /***********************************************************************************************
                                              Generate PTLTran
   ***********************************************************************************************/
   -- Check order not yet assign carton ID (for Exceed continuous backend assign new orders)
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_PTLStation_CreateTask
   
   SET @cSuggToLoc = '' 
   SET @cSuggWaveKey = ''
   
    --Check If Stations is Occupied by other WaveKey
   SELECT Top 1 @cWaveKey = WaveKey
   FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
   WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
   
   -- Get Assigned Location From TaskDetail 
   SELECT TOP 1  @cSuggToLoc         = TD.FinalLoc,
                --,@cSuggSKU       = TD.SKU
                @cSuggWaveKey   = TD.WaveKey 
   FROM dbo.TaskDetail TD WITH (NOLOCK)
   INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.TaskDetailKey = TD.TaskDetailKey AND PD.StorerKey = TD.StorerKey
   INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON LOC.Loc = TD.FinalLoc
   WHERE TD.StorerKey = @cStorerKey
   AND TD.TaskType = 'FCP'
   AND PD.DropID = @cScanID
   AND PD.SKU    = CASE WHEN ISNULL(@cScanSKU ,'' ) = '' THEN TD.SKU ELSE ISNULL(@cScanSKU,'') END
   AND Loc.Facility = @cFacility 
   AND Loc.LocationType = 'PTL'
   AND TD.Status = '9'
   AND PD.CaseID = ''
   AND PD.WaveKey = CASE WHEN ISNULL(@cWaveKey ,'' ) = '' THEN PD.WaveKey ELSE ISNULL(@cWaveKey,'') END
   ORDER BY TD.EditDate desc

   --SELECT @cSuggToLoc '@cSuggToLoc' , @cSuggWaveKey '@cSuggWaveKey' 
   
   
   SELECT @cStation   = DeviceID, 
          @cIPAddress = IPAddress
   FROM dbo.DeviceProfile WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey
   AND Loc = @cSuggToLoc  
   AND LogicalName = 'PTL'

   IF ISNULL(@cStation,'' ) = '' 
   BEGIN
         SET @nErrNo = 119707
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidLoc
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- UCC/ID
         SET @nErrNo = -1 -- Remain in current screen
         SET @cScanID = ''
         SET @cScanSKU = ''
         GOTO Quit
   END
   
--   IF ISNULL(@cToLoc,'' ) = ''
--   BEGIN
--      SELECT TOP 1  @cToLoc         = TD.FinalLoc 
--                ,@cSuggSKU       = TD.SKU
--                ,@cSuggWaveKey   = TD.WaveKey 
--      FROM dbo.TaskDetail TD WITH (NOLOCK)
--      INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.TaskDetailKey = TD.TaskDetailKey AND PD.StorerKey = TD.StorerKey
--      --INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON LOC.Loc = TD.ToLoc
--      WHERE TD.StorerKey = @cStorerKey
--      AND TD.TaskType = 'FCP'
--      AND PD.DropID = @cScanID
--      --AND Loc.Facility = @cFacility 
--      --AND Loc.LocationType = 'PTL'
--      AND TD.Status = '9'
--      
--      IF ISNULL(@cToLoc,'' ) = ''
--      BEGIN
--         SET @nErrNo = 119701
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --AssignmentNotFound
--         EXEC rdt.rdtSetFocusField @nMobile, 1 -- UCC/ID
--         SET @nErrNo = -1 -- Remain in current screen
--         SET @cScanID = ''
--         SET @cScanSKU = ''
--         GOTO Quit
--      END
--   END
--   ELSE
--   BEGIN
--      SET @cScanSKU = @cSuggSKU 
--   END
   
   
--   SELECT TOP 1 
--      @cStation   = DP.DeviceID, 
--      @cIPAddress = DP.IPAddress, 
--      @cPosition  = DP.DevicePosition
--      --@cLOC       = DP.Loc
--   FROM DeviceProfile DP WITH (NOLOCK)
--      --LEFT JOIN rdt.rdtPTLStationLog L WITH (NOLOCK) ON (DP.DeviceID = L.Station AND DP.IPAddress = L.IPAddress AND DP.DevicePosition = L.Position)
--   WHERE DeviceID IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
--      AND DeviceType = 'STATION'
--      --AND DeviceID <> ''
--      --AND Position IS NULL
--      AND DP.DevicePosition NOT IN ( SELECT Position FROM rdt.rdtPTLStationLog WITH (NOLOCK) WHERE StorerKey= @cStorerKey AND Wavekey = @cWaveKey) 
--   ORDER BY DP.DeviceID, DP.IPAddress, DP.DevicePosition
--   
   
   --SELECT @cSuggWaveKey '@cSuggWaveKey' , @cWaveKey '@cWaveKey' 
               
   IF ISNULL ( @cWaveKey,'') = '' OR @cWaveKey = @cSuggWaveKey
   BEGIN   
            
         

      DECLARE @curPTLLog CURSOR
         SET @curPTLLog = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT TD.FinalLoc,
                TD.SKU
         FROM dbo.TaskDetail TD WITH (NOLOCK)
         INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.TaskDetailKey = TD.TaskDetailKey AND PD.StorerKey = TD.StorerKey
         INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON LOC.Loc = TD.FinalLoc
         WHERE TD.StorerKey = @cStorerKey
         AND TD.TaskType = 'FCP'
         AND PD.DropID = @cScanID
         AND PD.SKU    = CASE WHEN ISNULL(@cScanSKU ,'' ) = '' THEN TD.SKU ELSE ISNULL(@cScanSKU,'') END
         AND Loc.Facility = @cFacility 
         AND Loc.LocationType = 'PTL'
         AND TD.Status = '9'
         AND PD.WaveKey = CASE WHEN ISNULL(@cWaveKey,'') = '' THEN @cSuggWaveKey ELSE PD.WaveKey END 
      
      OPEN @curPTLLog
      FETCH NEXT FROM @curPTLLog INTO @cFinalLoc, @cSuggSKU 
      WHILE @@FETCH_STATUS = 0
      BEGIN
         
         SELECT @cStyle = Style 
         FROM dbo.SKU WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND SKU = @cSuggSKU 
         
         SELECT --@cPosition  = LogicalPos, 
                @cPosition  = DevicePosition,
                @cIPAddress = IPAddress
         FROM dbo.DeviceProfile WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND Loc = @cFinalLoc
         AND LogicalName = 'PTL'  
            
         IF NOT EXISTS (SELECT 1 FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
                        WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
                        AND UserDefine01 = @cStyle
                        AND Position = @cPosition
                        AND WaveKey = @cSuggWaveKey  )
         BEGIN 
      
            
            -- Insert Assignment into RDT.RDTPTLStationLog with AUTO CartonID
            EXEC rdt.rdt_PTLStation_CustomCartonID @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'NEW', 
               @cStation1, @cStation2, @cStation3, @cStation4, @cStation5, @cMethod, '', '', 0, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT, @cCartonID OUTPUT
            IF @nErrNo <> 0
               GOTO Quit
            
            -- Save assign
            INSERT INTO rdt.rdtPTLStationLog (Station, IPAddress, Position, LOC, CartonID, Method, OrderKey, StorerKey, WaveKey, UserDefine01, UserDefine02)
            VALUES (@cStation, @cIPAddress, @cPosition, @cFinalLoc, @cCartonID, @cMethod, '', @cStorerKey, @cSuggWaveKey, @cStyle, @cSuggSKU)
            
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 119703
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsertLogFail
               EXEC rdt.rdtSetFocusField @nMobile, 1 -- UCC/ID
               SET @nErrNo = -1 -- Remain in current screen
               SET @cScanID = ''
               SET @cScanSKU = ''
               GOTO Quit
            END
            
            --SET @cWaveKey = @cSuggWaveKey
         END
      
         FETCH NEXT FROM @curPTLLog INTO @cFinalLoc, @cSuggSKU 
      END
      
      
   END
   ELSE 
   BEGIN
      SET @nErrNo = 119705
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DiffWaveKey
      EXEC rdt.rdtSetFocusField @nMobile, 1 -- UCC/ID
      SET @nErrNo = -1 -- Remain in current screen
      SET @cScanID = ''
      SET @cScanSKU = ''
      GOTO Quit
   END
   
   
   
   IF EXISTS( SELECT 1 
      FROM rdt.rdtPTLStationLog WITH (NOLOCK)
      WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
         AND CartonID = '')
   BEGIN
      SET @nErrNo = 119704
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --AssignCartonID
      GOTO Quit
   END
   
    -- Get orders in station
   INSERT INTO @tOrders (WaveKey,SKU) 
   SELECT WaveKey, UserDefine02
   FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
   WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
      AND WaveKey = @cSuggWaveKey

   

   --SELECT @cStorerKey '@cStorerKey' , @cScanID '@cScanID' , @cScanSKU '@cScanSKU' , @cSuggWaveKey '@cSuggWaveKey' 
   -- Check task 
   IF NOT EXISTS( SELECT 1 
      FROM PickDetail PD WITH (NOLOCK) 
         JOIN Orders O WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
      WHERE PD.StorerKey = @cStorerKey
         AND PD.DropID = @cScanID
         AND PD.SKU = @cScanSKU
         AND PD.Status <= '5'
         AND PD.CaseID = ''
         AND PD.QTY > 0
         AND PD.Status <> '4'
         AND O.Status <> 'CANC' 
         AND O.SOStatus <> 'CANC'
         AND PD.WaveKey = @cSuggWaveKey)
   BEGIN
      SET @nErrNo = 119702
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoTask
      EXEC rdt.rdtSetFocusField @nMobile, 1 -- UCC/ID
      SET @nErrNo = -1 -- Remain in current screen
      SET @cScanID = ''
      SET @cScanSKU = ''
      GOTO Quit
   END
--   ELSE
--   BEGIN
--      SET @cScanID = @cScanID
--   END
   
   

   SET @nPDQTY = 0
   --SET @nQTY = 0

    --SELECT SUM( PD.QTY)
    --  FROM Orders O WITH (NOLOCK) 
    --     JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
    --     --JOIN LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
    --     JOIN @tOrders t ON (t.WaveKey = PD.WaveKey)
    --  WHERE  PD.StorerKey = @cStorerKey 
    --     AND PD.DropID = @cScanID
    --     AND PD.SKU = @cScanSKU
    --     AND PD.Status <= '5'
    --     AND PD.CaseID = ''
    --     AND PD.QTY > 0
    --     AND PD.Status <> '4'
    --     AND O.Status <> 'CANC' 
    --     AND O.SOStatus <> 'CANC'
    --     --AND LOC.Facility = @cFacility

    --SELECT * FROM @tOrders 

    
   DECLARE @curPD CURSOR
   SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT SUM( PD.QTY)
      FROM Orders O WITH (NOLOCK) 
         JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
         --JOIN LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
         JOIN @tOrders t ON (t.WaveKey = PD.WaveKey AND t.SKU = PD.SKU )
      WHERE  PD.StorerKey = @cStorerKey 
         AND PD.DropID = @cScanID
         AND PD.SKU = @cScanSKU
         AND PD.Status <= '5'
         AND PD.CaseID = ''
         AND PD.QTY > 0
         AND PD.Status <> '4'
         AND O.Status <> 'CANC' 
         AND O.SOStatus <> 'CANC'
         AND PD.WaveKey = @cSuggWaveKey
         AND t.SKU = @cScanSKU 
         
         --AND LOC.Facility = @cFacility
      GROUP BY PD.WaveKey, PD.SKU
   OPEN @curPD
   FETCH NEXT FROM @curPD INTO @nPDQTY
   WHILE @@FETCH_STATUS = 0
   BEGIN
      --PRINT @nPDQTY
      SET @cStyle = '' 
       
      SELECT @cStyle = Style 
      FROM dbo.SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND SKU = @cScanSKU 
         
      -- Get station info
      SET @nRowRef = 0
      SELECT 
         @nRowRef = RowRef, 
         @cStation = Station, 
         @cIPAddress = IPAddress, 
         @cPosition = Position 
      FROM rdt.rdtPTLStationLog WITH (NOLOCK)
      WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
         AND WaveKey = @cSuggWaveKey 
         AND UserDefine01 = @cStyle 
         AND UserDefine02 = @cScanSKU
      
      
      
      IF @nRowRef > 0
      BEGIN
         -- Check PTLTran generated
         IF NOT EXISTS( SELECT 1
                        FROM PTL.PTLTran WITH (NOLOCK)
                        WHERE DeviceID = @cStation
                           AND IPAddress = @cIPAddress 
                           AND DevicePosition = @cPosition
                           AND GroupKey = @nRowRef
                           AND Func = @nFunc
                           AND SKU = @cScanSKU
                           AND DropID = @cScanID
                           AND SourceKey = @cSuggWaveKey)
                           --AND Status NOT IN ('1', '0' )  )
         BEGIN
            

            --IF @nQty = @nPDQty 
            --BEGIN
            --   SET @nPTLQty = @nQty
            --   SET @nQty = 0 
            --END
            --ELSE IF @nQty > @nPDQty 
            --BEGIN
            --   SET @nPTLQty = @nPDQty
            --   SET @nQty = @nQty - @nPDQty
            --END
            --ELSE IF @nQty < @nPDQty 
            --BEGIN
            --   SELECT @nPTLQty '@nPTLQty' , @nQty '@nQty' 
            --   SET @nPTLQty = @nQty
            --   SET @nQty = 0
            --END

            -- Generate PTLTran
            INSERT INTO PTL.PTLTran (
               IPAddress, DevicePosition, DeviceID, PTLType, 
                StorerKey, SKU, ExpectedQTY, QTY, DropID, Func, GroupKey, SourceType, SourceKey)
            VALUES (
               @cIPAddress, @cPosition, @cStation, 'STATION', 
               @cStorerKey, @cScanSKU, @nPDQTY, 0,  @cScanID, @nFunc, @nRowRef, 'rdt_PTLStation_CreateTask_ToteIDSKU03', @cSuggWaveKey)
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 119706
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPTLTranFail
               GOTO RollbackTran
            END
         END
      END
      FETCH NEXT FROM @curPD INTO @nPDQTY
   END
   CLOSE @curPD               
   DEALLOCATE @curPD
   
   COMMIT TRAN rdt_PTLStation_CreateTask


   /***********************************************************************************************
                                              Get task info
   ***********************************************************************************************/
   -- Get QTY
   --SET @nQTY = @nQTY_PTL

   -- Get SKU description
   DECLARE @cDispStyleColorSize  NVARCHAR( 20)
   SET @cDispStyleColorSize = rdt.RDTGetConfig( @nFunc, 'DispStyleColorSize', @cStorerKey)
   
   IF @cDispStyleColorSize = '0'
      SELECT @cSKUDescr = Descr FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cScanSKU
   
   ELSE IF @cDispStyleColorSize = '1'
      SELECT @cSKUDescr = 
         CAST( Style AS NCHAR(20)) + 
         CAST( Color AS NCHAR(10)) + 
         CAST( Size  AS NCHAR(10)) 
      FROM SKU WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey 
         AND SKU = @cScanSKU
      
   ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDispStyleColorSize AND type = 'P')
   BEGIN
      SET @cSQL = 'EXEC rdt.' + RTRIM( @cDispStyleColorSize) +
         ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
         ' @cType, @cLight, @cStation1, @cStation2, @cStation3, @cStation4, @cStation5, @cMethod, @cScanID, @cCartonID, @cScanSKU, ' +
         ' @nErrNo OUTPUT, @cErrMsg OUTPUT, @cSKUDescr OUTPUT '
      SET @cSQLParam =
         ' @nMobile    INT,          ' +
         ' @nFunc      INT,          ' +
         ' @cLangCode  NVARCHAR( 3), ' +
         ' @nStep      INT,          ' +
         ' @nInputKey  INT,          ' +
         ' @cFacility  NVARCHAR(5),  ' +
         ' @cStorerKey NVARCHAR(15), ' +
         ' @cType      NVARCHAR(20), ' +
         ' @cLight     NVARCHAR(1),  ' +
         ' @cStation1  NVARCHAR(10), ' +  
         ' @cStation2  NVARCHAR(10), ' +  
         ' @cStation3  NVARCHAR(10), ' +  
         ' @cStation4  NVARCHAR(10), ' +  
         ' @cStation5  NVARCHAR(10), ' +  
         ' @cMethod    NVARCHAR(10), ' +
         ' @cScanID    NVARCHAR(20), ' +
         ' @cScanSKU   NVARCHAR(20), ' +
         ' @nErrNo     INT          OUTPUT, ' +
         ' @cErrMsg    NVARCHAR(20) OUTPUT, ' +
         ' @cSKUDescr  NVARCHAR(60) OUTPUT  '
   
      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
         @cType, @cLight, @cStation1, @cStation2, @cStation3, @cStation4, @cStation5, @cMethod, @cScanID, @cCartonID, @cScanSKU, 
         @nErrNo OUTPUT, @cErrMsg OUTPUT, @cSKUDescr OUTPUT
   END
   
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_PTLStation_CreateTask
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN

END


GO
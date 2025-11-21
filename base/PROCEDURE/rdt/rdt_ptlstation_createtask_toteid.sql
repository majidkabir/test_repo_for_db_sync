SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_PTLStation_CreateTask_ToteID                    */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 27-06-2016  1.0  ChewKP      SOS#372370 Created                      */
/* 12-07-2017  1.1  Ung         WMS-2410 Clear scan ID if not task      */
/************************************************************************/

CREATE PROC [RDT].[rdt_PTLStation_CreateTask_ToteID] (
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
   
   DECLARE @cWaveKey       NVARCHAR( 10)
   DECLARE @cCriteria1     NVARCHAR( 30)
   DECLARE @cCriteria2     NVARCHAR( 30)
   DECLARE @cOrderKey      NVARCHAR( 10)
   DECLARE @cSKU           NVARCHAR( 20)
   DECLARE @nPDQTY         INT
         , @nPTLQty        INT
   
--   DECLARE @tWaveCriteria TABLE
--   (
--      WaveKey        NVARCHAR(10) NOT NULL, 
--      Criteria1      NVARCHAR(30) NOT NULL, 
--      Criteria2      NVARCHAR(30) NOT NULL
--   )
--   
   SET @nErrNo = 0 

   DECLARE @tOrders TABLE
   (
      OrderKey       NVARCHAR(10) NOT NULL, 
      CreatedPTLTran NVARCHAR(10) NOT NULL
   )
   
   -- Validate if Input rdt.rdtMobrec.DeviceID
   IF NOT EXISTS ( SELECT 1 FROM rdt.rdtMobrec WITH (NOLOCK) 
                   WHERE Mobile = @nMobile 
                   AND ISNULL(DeviceID,'')  <> '' ) 
   BEGIN
      SET @nErrNo = 101705
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DeviceIDReq
      GOTO Quit
   END
   
   /***********************************************************************************************
                                              Generate PTLTran
   ***********************************************************************************************/
   -- Check order not yet assign carton ID (for Exceed continuous backend assign new orders)
   IF EXISTS( SELECT 1 
      FROM rdt.rdtPTLStationLog WITH (NOLOCK)
      WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
         AND CartonID = '')
   BEGIN
      SET @nErrNo = 101701
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --AssignCartonID
      GOTO Quit
   END
   
    -- Get orders in station
   INSERT INTO @tOrders (OrderKey, CreatedPTLTran) 
   SELECT OrderKey, CreatedPTLTran 
   FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
   WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
      AND OrderKey <> ''
      
       DECLARE @ncount INT 
       SELECT @ncount = Count(*) FROM @tOrders

   
   -- Check task 
   IF NOT EXISTS( SELECT 1 
      FROM @tOrders O 
         JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
         JOIN Orders AO WITH (NOLOCK) ON (O.OrderKey = AO.OrderKey ) 
      WHERE PD.StorerKey = @cStorerKey
         AND PD.DropID = @cScanID
         AND PD.Status <= '5'
         AND PD.CaseID = ''
         AND PD.QTY > 0
         AND PD.Status <> '4'
         AND AO.Status <> 'CANC' 
         AND AO.SOStatus <> 'CANC')
   BEGIN
      SET @nErrNo = 101702
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No more task
      GOTO Quit
   END
     
      
   -- Get wave criteria in station
--   INSERT INTO @tWaveCriteria (WaveKey, Criteria1, Criteria2) 
--   SELECT WaveKey, ShipTo, UserDefine01
--   FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
--   WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
--      AND WaveKey <> ''
--      AND ShipTo <> ''
--      AND UserDefine01 <> ''
   
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_PTLStation_CreateTask

   DECLARE @nRowRef      INT
   DECLARE @cIPAddress   NVARCHAR(40)
   DECLARE @cPosition    NVARCHAR(10)
   DECLARE @cStation     NVARCHAR(10)
   DECLARE @cDropID      NVARCHAR(20)

   SET @nPDQTY = 0
   --SET @nQTY = 0
   
   DECLARE @curPD CURSOR
   SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PD.OrderKey, PD.SKU, SUM( PD.QTY)
         FROM Orders O WITH (NOLOCK) 
            JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
            JOIN LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            JOIN @tOrders t ON (t.OrderKey = PD.OrderKey)
         WHERE LOC.Facility = @cFacility
            AND PD.StorerKey = @cStorerKey 
            AND PD.DropID = @cScanID
            AND PD.Status = '5'
            AND PD.CaseID = ''
            AND PD.QTY > 0
            AND O.Status <> 'CANC' 
            AND O.SOStatus <> 'CANC'
         GROUP BY PD.OrderKey, PD.DropID, PD.SKU
   OPEN @curPD
   FETCH NEXT FROM @curPD INTO @cOrderKey, @cSKU, @nPDQTY
   WHILE @@FETCH_STATUS = 0
   BEGIN
      
      SET @cScanSKU = @cSKU 
      
      -- Get station info
      -- Get station info
      SET @nRowRef = 0
      SELECT 
         @nRowRef = RowRef, 
         @cStation = Station, 
         @cIPAddress = IPAddress, 
         @cPosition = Position 
      FROM rdt.rdtPTLStationLog WITH (NOLOCK)
      WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
         AND OrderKey = @cOrderKey
      
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
               AND SKU = @cSKU
               AND DropID = @cScanID
               AND OrderKey = @cOrderKey )
         BEGIN
            
            IF @nQty = @nPDQty 
            BEGIN
               SET @nPTLQty = @nQty
               SET @nQty = 0 
            END
            ELSE IF @nQty > @nPDQty 
            BEGIN
               SET @nPTLQty = @nPDQty
               SET @nQty = @nQty - @nPDQty
            END
            ELSE IF @nQty < @nPDQty 
            BEGIN
               SET @nPTLQty = @nQty
               SET @nQty = 0
            END
            -- Generate PTLTran
            INSERT INTO PTL.PTLTran (
               IPAddress, DevicePosition, DeviceID, PTLType, 
               OrderKey, StorerKey, SKU, ExpectedQTY, QTY, DropID, Func, GroupKey, SourceType)
            VALUES (
               @cIPAddress, @cPosition, @cStation, 'STATION', 
               @cOrderKey, @cStorerKey, @cSKU, @nPDQTY, 0,  @cScanID, @nFunc, @nRowRef, 'rdt_PTLStation_CreateTask_ToteID')
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 101703
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPTLTranFail
               GOTO RollbackTran
            END
         END
      END
      FETCH NEXT FROM @curPD INTO @cOrderKey, @cSKU, @nPDQTY
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
   
--   IF @cDispStyleColorSize = '0'
--      SELECT @cSKUDescr = Descr FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cScanSKU
--   
--   ELSE IF @cDispStyleColorSize = '1'
--      SELECT @cSKUDescr = 
--         CAST( Style AS NCHAR(20)) + 
--         CAST( Color AS NCHAR(10)) + 
--         CAST( Size  AS NCHAR(10)) 
--      FROM SKU WITH (NOLOCK) 
--      WHERE StorerKey = @cStorerKey 
--         AND SKU = @cScanSKU
      
   IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDispStyleColorSize AND type = 'P')
   BEGIN
      SET @cSQL = 'EXEC rdt.' + RTRIM( @cDispStyleColorSize) +
         ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
         ' @cType, @cLight, @cStation1, @cStation2, @cStation3, @cStation4, @cStation5, @cMethod, @cScanID, @cCartonID, @cSKU, ' +
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
         ' @cSKU       NVARCHAR(20), ' +
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
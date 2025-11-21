SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_PTLStation_CreateTask_OrderSKU                  */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 16-02-2016  1.0  Ung         SOS363160 Created                       */
/* 12-07-2017  1.1  Ung         WMS-2410 Clear scan ID if not task      */
/************************************************************************/

CREATE PROC [RDT].[rdt_PTLStation_CreateTask_OrderSKU] (
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

   DECLARE @nTranCount  INT
   DECLARE @bSuccess    INT
   DECLARE @cSQL        NVARCHAR( MAX)
   DECLARE @cSQLParam   NVARCHAR( MAX)
   
   DECLARE @cOrderKey   NVARCHAR( 10)
   DECLARE @cSKU        NVARCHAR( 20)
   DECLARE @nPDQTY      INT
   
   DECLARE @tOrders TABLE
   (
      OrderKey       NVARCHAR(10) NOT NULL, 
      CreatedPTLTran NVARCHAR(10) NOT NULL
   )
   
   /***********************************************************************************************
                                              Generate PTLTran
   ***********************************************************************************************/
   -- Check order not yet assign carton ID (for Exceed continuous backend assign new orders)
   IF EXISTS( SELECT 1 
      FROM rdt.rdtPTLStationLog WITH (NOLOCK)
      WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
         AND CartonID = '')
   BEGIN
      SET @nErrNo = 97101
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --AssignCartonID
      GOTO Quit
   END

   -- Get orders in station
   INSERT INTO @tOrders (OrderKey, CreatedPTLTran) 
   SELECT OrderKey, CreatedPTLTran 
   FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
   WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
      AND OrderKey <> ''
   
   -- Check PTLTran generated
   IF EXISTS( SELECT 1 FROM @tOrders WHERE CreatedPTLTran <> 'Y')
   BEGIN
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN
      SAVE TRAN rdt_PTLStation_CreateTask
   
      DECLARE @nRowRef      INT
      DECLARE @cIPAddress   NVARCHAR(40)
      DECLARE @cPosition    NVARCHAR(10)
      DECLARE @cStation     NVARCHAR(10)
   
      SET @nPDQTY = 0
      SET @nQTY = 0
      
      DECLARE @curPD CURSOR
      SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PD.OrderKey, PD.SKU, SUM( PD.QTY)
         FROM Orders O WITH (NOLOCK) 
            JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
            JOIN LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            JOIN @tOrders t ON (t.OrderKey = PD.OrderKey AND CreatedPTLTran <> 'Y')
         WHERE LOC.Facility = @cFacility
            AND PD.StorerKey = @cStorerKey 
            AND PD.Status < '4'
            AND PD.QTY > 0
            AND O.Status <> 'CANC' 
            AND O.SOStatus <> 'CANC'
         GROUP BY PD.OrderKey, PD.DropID, PD.SKU
      OPEN @curPD
      FETCH NEXT FROM @curPD INTO @cOrderKey, @cSKU, @nPDQTY
      WHILE @@FETCH_STATUS = 0
      BEGIN
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
                  AND SourceKey = @nRowRef
                  AND Func = @nFunc)
            BEGIN
               -- Generate PTLTran
               INSERT INTO PTL.PTLTran (IPAddress, DevicePosition, DeviceID, PTLType, OrderKey, StorerKey, SKU, ExpectedQTY, QTY, DropID, Func, GroupKey, SourceType)
               VALUES (@cIPAddress, @cPosition, @cStation, 'STATION', @cOrderKey, @cStorerKey, @cSKU, @nPDQTY, 0, '', @nFunc, @nRowRef, 'rdt_PTLStation_CreateTask_OrderSKU')
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 97102
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPTLTranFail
                  GOTO RollbackTran
               END
            END
            
            -- Mark as created task
            UPDATE rdt.rdtPTLStationLog SET
               CreatedPTLTran = 'Y', 
               EditWho = SUSER_SNAME(), 
               EditDate = GETDATE()
            WHERE RowRef = @nRowRef
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 97103
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Log Fail
               GOTO RollbackTran
            END
         END
         FETCH NEXT FROM @curPD INTO @cOrderKey, @cSKU, @nPDQTY
      END
      COMMIT TRAN rdt_PTLStation_CreateTask
   END


   /***********************************************************************************************
                                              Check task valid
   ***********************************************************************************************/
   DECLARE @nQTY_PTL INT
   DECLARE @nQTY_PD  INT

   SET @nQTY_PTL = 0
   SET @nQTY_PD = 0
   
   -- Get PTLTran QTY
   SELECT @nQTY_PTL = ISNULL( SUM( ExpectedQTY), 0)
   FROM PTL.PTLTran WITH (NOLOCK)
   WHERE DeviceID IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
      AND SKU = @cScanSKU
      AND Status <> '9'
   IF @nQTY_PTL = 0
   BEGIN
      SET @nErrNo = 97104
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Task
      GOTO Quit
   END

   -- Get PickDetail QTY
   SELECT @nQTY_PD = ISNULL( SUM( PD.QTY), 0)
   FROM Orders O WITH (NOLOCK) 
      JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
      JOIN LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
      JOIN @tOrders t ON (t.OrderKey = PD.OrderKey)
   WHERE LOC.Facility = @cFacility
      AND PD.StorerKey = @cStorerKey 
      AND PD.SKU = @cScanSKU
      AND PD.Status < '4'
      AND PD.QTY > 0
      AND O.Status <> 'CANC' 
      AND O.SOStatus <> 'CANC'

   -- Check PickDetail changed
   IF @nQTY_PD <> @nQTY_PTL
   BEGIN
      SET @nErrNo = 97105
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKDtl changed
      GOTO Quit
   END

   /***********************************************************************************************
                                              Get task info
   ***********************************************************************************************/
   -- Get QTY
   SET @nQTY = @nQTY_PTL

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
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_PTLStation_CreateTask_ToteIDSKU04               */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Date       Rev Author      Purposes                                  */
/* 21-09-2018 1.0 ChewKP      WMS-4538 Created                          */
/************************************************************************/

CREATE PROC [RDT].[rdt_PTLStation_CreateTask_ToteIDSKU04] (
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
          ,@cSKUGroup      NVARCHAR(10) 
   
   SET @nErrNo = 0 

   DECLARE @tOrders TABLE
   (
      OrderKey NVARCHAR(10) NOT NULL
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
      SET @nErrNo = 111651
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --AssignCartonID
      GOTO Quit
   END
   
    -- Get orders in station
   INSERT INTO @tOrders (OrderKey) 
   SELECT DISTINCT OrderKey
   FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
   WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
      AND OrderKey <> ''

   -- Check task 
   IF NOT EXISTS( SELECT 1 
      FROM @tOrders O 
         JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
         JOIN Orders AO WITH (NOLOCK) ON (O.OrderKey = AO.OrderKey ) 
      WHERE PD.StorerKey = @cStorerKey
         AND PD.DropID = @cScanID
         --AND PD.SKU = @cScanSKU
         AND PD.Status <= '5'
         AND PD.CaseID = ''
         AND PD.QTY > 0
         AND PD.Status <> '4'
         AND AO.Status <> 'CANC' 
         AND AO.SOStatus <> 'CANC')
   BEGIN
      SET @nErrNo = 129452
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No task
      EXEC rdt.rdtSetFocusField @nMobile, 1 -- UCC/ID
      SET @nErrNo = -1 -- Remain in current screen
      SET @cScanID = ''
      SET @cScanSKU = ''
      GOTO Quit
   END
   ELSE
   BEGIN
      SET @cScanID = @cScanID
   END
   
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
      SELECT PD.OrderKey, SUM( PD.QTY), PD.SKU
         FROM Orders O WITH (NOLOCK) 
            JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
            JOIN LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            JOIN @tOrders t ON (t.OrderKey = PD.OrderKey)
         WHERE LOC.Facility = @cFacility
            AND PD.StorerKey = @cStorerKey 
            AND PD.DropID = @cScanID
            --AND PD.SKU = @cScanSKU
            AND PD.Status <= '5'
            AND PD.CaseID = ''
            AND PD.QTY > 0
            AND PD.Status <> '4'
            AND O.Status <> 'CANC' 
            AND O.SOStatus <> 'CANC'
         GROUP BY PD.OrderKey, PD.DropID, PD.SKU
   OPEN @curPD
   FETCH NEXT FROM @curPD INTO @cOrderKey, @nPDQTY, @cScanSKU
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Get station info
      
      SELECT TOP 1 @cSKUGroup = CD.Short FROM dbo.SKU SKU WITH (NOLOCK) 
      JOIN dbo.Codelkup CD WITH (NOLOCK) ON CD.StorerKey = SKU.StorerKey AND CD.Code = SKU.SUSR3 AND CD.ListName = 'SKUGROUP' 
      WHERE SKU.StorerKey = @cStorerkey  
      AND  CD.ListName = 'SKUGROUP'
      AND SKU.SKU = @cScanSKU
      
      
      SET @nRowRef = 0
      SELECT 
         @nRowRef = RowRef, 
         @cStation = Station, 
         @cIPAddress = IPAddress, 
         @cPosition = Position 
      FROM rdt.rdtPTLStationLog WITH (NOLOCK)
      WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
         AND OrderKey = @cOrderKey
         AND UserDefine02 = @cSKUGroup
      
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
                           AND OrderKey = @cOrderKey 
                           AND Status IN ('1', '0' )  )
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
               @cOrderKey, @cStorerKey, @cScanSKU, @nPDQTY, 0,  @cScanID, @nFunc, @nRowRef, 'rdt_PTLStation_CreateTask_ToteIDSKU04')
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 129453
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPTLTranFail
               GOTO RollbackTran
            END
         END
      END
      FETCH NEXT FROM @curPD INTO @cOrderKey, @nPDQTY, @cScanSKU
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
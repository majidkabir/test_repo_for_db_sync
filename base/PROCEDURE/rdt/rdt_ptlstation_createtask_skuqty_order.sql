SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_PTLStation_CreateTask_SKUQTY_Order              */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 09-11-2022  1.0  Ung         WMS-21024 Created                       */
/************************************************************************/

CREATE   PROC [RDT].[rdt_PTLStation_CreateTask_SKUQTY_Order] (
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

   DECLARE @nTranCount  INT = @@TRANCOUNT
   DECLARE @bSuccess    INT
   DECLARE @cSQL        NVARCHAR( MAX)
   DECLARE @cSQLParam   NVARCHAR( MAX)

   DECLARE @nRowRef     INT
   DECLARE @cIPAddress  NVARCHAR( 40)
   DECLARE @cPosition   NVARCHAR( 10)
   DECLARE @cStation    NVARCHAR( 10)
   
   DECLARE @cPickFilter NVARCHAR( MAX) = ''
   DECLARE @cOrderKey   NVARCHAR( 10)
   DECLARE @nQTY_Bal    INT
   DECLARE @nQTY_PD     INT
   
   -- Get other sorter working on this SKU
   DECLARE @cUserName NVARCHAR( 128) = ''
   SELECT @cUserName = UserName  
   FROM rdt.rdtMobRec WITH (NOLOCK) 
   WHERE Func = @nFunc 
      AND V_SKU = @cScanSKU 
      AND Step BETWEEN 3 AND 7
      AND UserName <> SUSER_SNAME()

   -- Check same SKU only 1 sorter at same time
   IF @cUserName <> ''
   BEGIN
      SET @nErrNo = 193851
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU LOCKED BY: 
      EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @cErrMsg, @cUserName 
      EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU
      SET @cErrMsg = ''
      SET @nErrNo = -1 -- Remain in current screen
      SET @cScanSKU = ''
      SET @nQTY = 0
      GOTO Quit
   END

   IF OBJECT_ID('tempdb..#tOrders') IS NOT NULL
       DROP TABLE #tOrders

   -- Get orders in station
   SELECT OrderKey, RowRef
   INTO #tOrders 
   FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
   WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
      AND OrderKey <> ''

   -- Get pick filter
   SELECT @cPickFilter = ISNULL( Long, '')
   FROM CodeLKUP WITH (NOLOCK) 
   WHERE ListName = 'PickFilter'
      AND Code = @nFunc 
      AND StorerKey = @cStorerKey
      AND Code2 = @cFacility

   -- Get Pickdetail task
   SET @cSQL = 
      ' SELECT @nQTY_PD = ISNULL( SUM( PD.QTY), 0) ' + 
      ' FROM #tOrders t ' + 
         ' JOIN Orders O WITH (NOLOCK) ON (t.OrderKey = O.OrderKey ) ' + 
         ' JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey) ' + 
         ' JOIN LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC) ' + 
      ' WHERE PD.SKU = @cScanSKU ' + 
         ' AND PD.CaseID = '''' ' + 
         ' AND PD.QTY > 0 ' + 
         ' AND PD.Status <> ''4'' ' + 
         ' AND O.Status <> ''CANC'' ' + 
         ' AND O.SOStatus <> ''CANC'' ' + 
         CASE WHEN @cPickFilter <> '' THEN @cPickFilter ELSE '' END
   SET @cSQLParam =
      ' @cScanSKU NVARCHAR( 20), ' + 
      ' @nQTY_PD  INT OUTPUT '
   EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
      @cScanSKU, 
      @nQTY_PD OUTPUT

   -- Check has task
   IF @nQTY_PD = 0
   BEGIN
      SET @nErrNo = 193852
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No task
      EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU
      SET @nErrNo = -1 -- Remain in current screen
      SET @cScanSKU = ''
      SET @nQTY = 0
      GOTO Quit
   END
   
   -- Check over pick
   IF @nQTY > @nQTY_PD
   BEGIN
      SET @nErrNo = 193853
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over pick
      EXEC rdt.rdtSetFocusField @nMobile, 6 -- QTY
      SET @nErrNo = -1 -- Remain in current screen
      SET @nQTY = 0
      GOTO Quit
   END

   /***********************************************************************************************
                                              Generate PTLTran
   ***********************************************************************************************/
   BEGIN TRAN
   SAVE TRAN rdt_PTLStation_CreateTask

   -- Remove any open PTLTran
   IF EXISTS( SELECT TOP 1 1
      FROM #tOrders t
         JOIN PTL.PTLTran L WITH (NOLOCK) ON (t.OrderKey = L.OrderKey AND t.RowRef = L.GroupKey)
      WHERE L.SKU = @cScanSKU
         AND L.Status <> '9')
   BEGIN
      DECLARE @nPTLKey INT
      DECLARE @curLog CURSOR
      SET @curLog = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT L.PTLKey
         FROM #tOrders t
            JOIN PTL.PTLTran L WITH (NOLOCK) ON (t.OrderKey = L.OrderKey AND t.RowRef = L.GroupKey)
         WHERE L.SKU = @cScanSKU
            AND L.Status <> '9'
      OPEN @curLog
      FETCH NEXT FROM @curLog INTO @nPTLKey
      WHILE @@FETCH_STATUS = 0
      BEGIN
         DELETE PTL.PTLTran WHERE PTLKey = @nPTLKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 193854
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DELPTLTranFail
            GOTO RollbackTran
         END
         FETCH NEXT FROM @curLog INTO @nPTLKey
      END
   END

   -- Generate new PTLTran (by QTY)
   SET @nQTY_Bal = @nQTY
   DECLARE @curPD CURSOR
   SET @cSQL = 
      ' SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR ' + 
         ' SELECT PD.OrderKey, SUM( PD.QTY) ' + 
         ' FROM Orders O WITH (NOLOCK) ' + 
            ' JOIN #tOrders t ON (t.OrderKey = O.OrderKey) ' + 
            ' JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey) ' + 
            ' JOIN LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC) ' + 
         ' WHERE PD.SKU = @cScanSKU ' + 
            ' AND PD.CaseID = '''' ' + 
            ' AND PD.Status <> ''4''  ' + 
            ' AND PD.QTY > 0 ' + 
            ' AND O.Status <> ''CANC''  ' + 
            ' AND O.SOStatus <> ''CANC'' ' + 
            CASE WHEN @cPickFilter <> '' THEN @cPickFilter ELSE '' END + 
         ' GROUP BY PD.OrderKey, PD.SKU ' + 
      ' OPEN @curPD '
   SET @cSQLParam =
      ' @cScanSKU NVARCHAR( 20), ' + 
      ' @curPD CURSOR OUTPUT '
   EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
      @cScanSKU, 
      @curPD OUTPUT

   FETCH NEXT FROM @curPD INTO @cOrderKey, @nQTY_PD
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
         -- Calc QTY
         IF @nQTY_PD > @nQTY_Bal
            SET @nQTY_PD = @nQTY_Bal

         -- Generate PTLTran
         INSERT INTO PTL.PTLTran (IPAddress, DevicePosition, DeviceID, PTLType, OrderKey, StorerKey, SKU, ExpectedQTY, QTY, DropID, Func, GroupKey, SourceType)
         VALUES (@cIPAddress, @cPosition, @cStation, 'STATION', @cOrderKey, @cStorerKey, @cScanSKU, @nQTY_PD, 0, '', @nFunc, @nRowRef, 'rdt_PTLStation_CreateTask_SKUQTY_Order')
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 193855
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPTLTranFail
            GOTO RollbackTran
         END
         
         SET @nQTY_Bal = @nQTY_Bal - @nQTY_PD
         IF @nQTY_Bal = 0
            BREAK
      END
      FETCH NEXT FROM @curPD INTO @cOrderKey, @nQTY_PD
   END
   COMMIT TRAN rdt_PTLStation_CreateTaskEND

   /***********************************************************************************************
                                              Get task info
   ***********************************************************************************************/
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
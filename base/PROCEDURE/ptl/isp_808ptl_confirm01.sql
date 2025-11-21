SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: isp_808PTL_Confirm01                                */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Accept QTY in CS-PCS, format 9-999                          */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 15-09-2016 1.0  ChewKP   Created                                     */
/* 24-03-2016 1.1  CheeMun  IN00299080 - Insert qty                     */
/************************************************************************/

CREATE PROC [PTL].[isp_808PTL_Confirm01] (
   @cIPAddress    NVARCHAR(30), 
   @cPosition     NVARCHAR(20),
   @cFuncKey      NVARCHAR(2), 
   @nSerialNo     INT,
   @cInputValue   NVARCHAR(20),
   @nErrNo        INT           OUTPUT,  
   @cErrMsg       NVARCHAR(125) OUTPUT,  
   @cDebug        NVARCHAR( 1) = ''
)
AS
BEGIN TRY
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cLangCode      NVARCHAR( 3)
   DECLARE @cUserName      NVARCHAR( 18)
   DECLARE @nTranCount     INT
   DECLARE @bSuccess       INT
   DECLARE @nFunc          INT
   DECLARE @nQTY           INT
   DECLARE @nPTLKey        INT
   DECLARE @nQTY_PTL       INT
   DECLARE @nQTY_PD        INT
   DECLARE @nQTY_Bal       INT
   DECLARE @nExpectedQTY   INT
   DECLARE @nGroupKey      INT
   DECLARE @nCartonNo      INT
   DECLARE @cStation       NVARCHAR( 10)
   DECLARE @cStation1      NVARCHAR( 10)
   DECLARE @cStation2      NVARCHAR( 10)
   DECLARE @cStation3      NVARCHAR( 10)
   DECLARE @cStation4      NVARCHAR( 10)
   DECLARE @cStation5      NVARCHAR( 10)
   DECLARE @cCartonID      NVARCHAR( 20)
   DECLARE @cSKU           NVARCHAR( 20)
   DECLARE @cLOC           NVARCHAR( 10)
   DECLARE @cType          NVARCHAR( 10)
   DECLARE @cOrderKey      NVARCHAR( 10)
   DECLARE @cPickDetailKey NVARCHAR( 10)
   DECLARE @cLightMode     NVARCHAR( 4)
   DECLARE @cLabelLine     NVARCHAR( 5)
   DECLARE @cDisplayValue  NVARCHAR( 5)
         , @cDropID        NVARCHAR(20)
         , @nSPErrNo       INT 
         , @cSPErrMSG      NVARCHAR(125) 
         , @cWaveKey       NVARCHAR(10)

   DECLARE @curPTL CURSOR
   DECLARE @curPD  CURSOR

   SET @nFunc = 805 -- PTL Cart (rdt.rdtfnc_PTLCart)
   SET @cInputValue = RTRIM( LTRIM( @cInputValue))
   
   -- Get storer 
   DECLARE @cStorerKey NVARCHAR(15)
   SELECT TOP 1 
      @cStorerKey = StorerKey
   FROM PTL.PTLTran WITH (NOLOCK)
   WHERE IPAddress = @cIPAddress 
      AND DevicePosition = @cPosition 
      AND LightUp = '1'
      
   -- Get display value
   SELECT @cDisplayValue = LEFT( DisplayValue, 5)
   FROM PTL.LightStatus WITH (NOLOCK)
   WHERE IPAddress = @cIPAddress
      AND DevicePosition = @cPosition

   -- Get device profile info
   SELECT @cStation = DeviceID
   FROM dbo.DeviceProfile WITH (NOLOCK)  
   WHERE IPAddress = @cIPAddress
      AND DevicePosition = @cPosition
      AND DeviceType = 'CART'
      AND DeviceID <> ''
      AND StorerKey = @cStorerKey 
   
     -- Get PTLTran info
--   SELECT TOP 1
--      @cSKU = SKU, 
--      @cUserName = EditWho, 
--      @cDropID = DropID
--   FROM PTL.PTLTran WITH (NOLOCK)
--   WHERE IPAddress = @cIPAddress
--      AND DevicePosition = @cPosition
--      --AND GroupKey = @nGroupKey
--      --AND Func = 808
--      AND Status = '1' -- Lighted up

   -- Handling transaction
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN isp_808PTL_Confirm01 -- For rollback or commit only our own transaction

/*
insert into a (fld, val) values ('@cDPLKey', @cDPLKey)
insert into a (fld, val) values ('@cPosition', @cPosition)
insert into a (fld, val) values ('@cLOC', @cLOC)
insert into a (fld, val) values ('@cSKU', @cSKU)
insert into a (fld, val) values ('@nQTY', @nQTY)
insert into a (fld, val) values ('@cStation', @cStation)
*/
   PRINT @cIPAddress
   PRINT @cPosition
   -- PTLTran
   SET @curPTL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PTLKey--, ExpectedQTY
      FROM PTL.PTLTran WITH (NOLOCK)
      WHERE IPAddress = @cIPAddress
         AND DevicePosition = @cPosition
         --AND SKU = @cSKU
         --AND DropID = @cDropID 
         AND Status = '1'
   OPEN @curPTL
   FETCH NEXT FROM @curPTL INTO @nPTLKey--, @nQTY_PTL
   WHILE @@FETCH_STATUS = 0
   BEGIN
      

         -- Confirm PTLTran
         UPDATE PTL.PTLTran WITH (ROWLOCK) SET
            Status = '9',
            LightUp = '0', 
            QTY = @cInputValue,  --IN00299080
            --QTY = ExpectedQTY,
            --CaseID = @cCartonID,
            --MessageNum = @cMessageNum,
            EditWho = SUSER_SNAME(),
            EditDate = GETDATE(),
            TrafficCop = NULL
         WHERE PTLKey = @nPTLKey
         
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 104051
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PTL Fail
            GOTO RollBackTran
         END


      FETCH NEXT FROM @curPTL INTO @nPTLKey--, @nQTY_PTL
   END

 
   

   COMMIT TRAN isp_808PTL_Confirm01
   GOTO Quit

   RollBackTran:
   ROLLBACK TRAN isp_808PTL_Confirm01 -- Only rollback change made here
   
   -- Raise error to go to catch block
   RAISERROR ('', 16, 1) WITH SETERROR

END TRY
BEGIN CATCH
   
   SET @nSPErrNo = @nErrNo 
   SET @cSPErrMSG = @cErrMsg

   

END CATCH

Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN

GO
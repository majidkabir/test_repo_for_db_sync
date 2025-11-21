SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_811InsPTLTran01                                       */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 17-10-2014 1.0  Ung      SOS316714 Created                                 */
/******************************************************************************/

CREATE PROC [RDT].[rdt_811InsPTLTran01] (
     @nMobile    INT
    ,@nFunc      INT
    ,@cFacility  NVARCHAR(5)
    ,@cStorerKey NVARCHAR( 15)
    ,@cCartID    NVARCHAR( 10)
    ,@cUserName  NVARCHAR( 18)
    ,@cLangCode  NVARCHAR( 3)
    ,@cPickZone  NVARCHAR( 10)
    ,@nErrNo     INT          OUTPUT
    ,@cErrMsg    NVARCHAR(20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

    DECLARE 
        @nTranCount            INT
      , @cPTLType              NVARCHAR(20)
      , @cIPAddress            NVARCHAR(40)
      , @cDevicePosition       NVARCHAR(10)
      , @cDropID               NVARCHAR(20)
      , @cOrderKey             NVARCHAR(10)
      , @cSKU                  NVARCHAR(20)
      , @cLOC                  NVARCHAR(10)
      , @nExpectedQTY          INT
      , @cLot                  NVARCHAR(10)
      , @cDeviceProfileLogKey  NVARCHAR(10)
      , @cPTLPKZoneReq         NVARCHAR(1)
      , @cGetTaskIgnoreLOT     NVARCHAR(1)

   SET @cPTLPKZoneReq = rdt.rdtGetConfig( @nFunc, 'PTLPicKZoneReq', @cStorerKey)
   IF @cPTLPKZoneReq = '0'
      SET @cPTLPKZoneReq = ''
   SET @cGetTaskIgnoreLOT = rdt.RDTGetConfig( @nFunc, 'GetTaskIgnoreLOT', @cStorerKey)

   SET @cPTLType          = 'Pick2Cart'
   SET @cIPAddress        = ''
   SET @cDevicePosition   = ''
   SET @cDropID           = ''
   SET @cOrderKey         = ''
   SET @cSKU              = ''
   SET @cLOC              = ''
   SET @nExpectedQTY      = 0
   SET @cDeviceProfileLogKey = ''

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_811InsPTLTran01

   DECLARE @curPTLTran CURSOR

   SET @curPTLTran = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DP.IPAddress, DP.DevicePosition, DPL.DeviceProfileLogKey, DPL.DropID, DPL.OrderKey, PD.StorerKey, PD.SKU, PD.LOC, SUM(PD.QTY), ''
      FROM dbo.DeviceProfile DP WITH (NOLOCK)
         JOIN dbo.DeviceProfileLog DPL WITH (NOLOCK) ON (DPL.DeviceProfileKey = DP.DeviceProfileKey)
         JOIN dbo.Orders O WITH (NOLOCK) ON (O.OrderKey = DPL.OrderKey)
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.OrderKey  = O.OrderKey)
         JOIN dbo.LOC LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
      WHERE DP.DeviceID = @cCartID
         AND DPL.Status = '1'
         AND PD.Status <= '3'
      GROUP BY DP.IPAddress, DP.DevicePosition, DPL.DeviceProfileLogKey, DPL.DropID, DPL.OrderKey, PD.StorerKey, PD.SKU, PD.LOC
      ORDER BY DPL.OrderKey

   OPEN @curPTLTran
   FETCH NEXT FROM @curPTLTran INTO @cIPAddress, @cDevicePosition, @cDeviceProfileLogKey, @cDropID, @cOrderKey, @cStorerKey, @cSKU, @cLOC, @nExpectedQTY, @cLOT

   WHILE @@FETCH_STATUS = 0
   BEGIN
      IF NOT EXISTS ( SELECT 1
         FROM dbo.PTLTran WITH (NOLOCK)
         WHERE IPAddress       = @cIPAddress
            AND DeviceID       = @cCartID
            AND DevicePosition = @cDevicePosition
            AND OrderKey       = @cOrderKey
            AND SKU            = @cSKU
            AND LOC            = @cLOC
            AND LOT            = @cLOT
            AND DeviceProfileLogKey = @cDeviceProfileLogKey)
      BEGIN
         INSERT INTO PTLTran
         (
            IPAddress,  DeviceID,     DevicePosition,
            [Status],   PTL_Type,     DropID,
            OrderKey,   Storerkey,    SKU,
            LOC,        ExpectedQty,  QTY,
            Remarks,    MessageNum,   LOT,
            DeviceProfileLogKey, SourceKey
         )
         VALUES
         (
            @cIPAddress  ,
            @cCartID     ,
            @cDevicePosition  ,
            '0'          ,
            @cPTLType    ,
            @cDropID     ,
            @cOrderKey   ,
            @cStorerKey ,
            @cSKU       ,
            @cLOC       ,
            @nExpectedQTY ,
            0           ,
            ''          ,
            ''          ,
            @cLOT       ,
            @cDeviceProfileLogKey,
            ''
         )

         IF @@ERROR <> ''
         BEGIN
            SET @nErrNo = 79751
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdPTLTranFail'
            GOTO RollBackTran
         END
      END

      FETCH NEXT FROM @curPTLTran INTO @cIPAddress, @cDevicePosition, @cDeviceProfileLogKey, @cDropID, @cOrderKey, @cStorerKey, @cSKU, @cLOC, @nExpectedQTY, @cLOT
   END

   GOTO QUIT

RollBackTran:
   ROLLBACK TRAN rdt_811InsPTLTran01
   CLOSE curPTLTran
   DEALLOCATE curPTLTran

Quit:
   WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started
      COMMIT TRAN rdt_811InsPTLTran01
END

GO
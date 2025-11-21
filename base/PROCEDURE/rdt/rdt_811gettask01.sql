SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_811GetTask01                                    */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Get next SKU to Pick                                        */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 24-Nov-2014 1.0  Ung         SOS316714 Created                       */
/************************************************************************/

CREATE PROC [RDT].[rdt_811GetTask01] (
     @nMobile          INT
    ,@nFunc            INT
    ,@cFacility        NVARCHAR(5)
    ,@cStorerKey       NVARCHAR( 15)
    ,@cCartID          NVARCHAR( 10)
    ,@cUserName        NVARCHAR( 18)
    ,@cLangCode        NVARCHAR( 3)
    ,@cPickZone        NVARCHAR( 10)
    ,@nErrNo           INT                 OUTPUT
    ,@cErrMsg          NVARCHAR(250)       OUTPUT
    ,@cSKU             NVARCHAR(20) = ''   OUTPUT
    ,@cSKUDescr        NVARCHAR(60) = ''   OUTPUT
    ,@cLoc             NVARCHAR(10) = ''   OUTPUT
    ,@cLot             NVARCHAR(10) = ''   OUTPUT
    ,@cLottable01      NVARCHAR(18) = ''   OUTPUT
    ,@cLottable02      NVARCHAR(18) = ''   OUTPUT
    ,@cLottable03      NVARCHAR(18) = ''   OUTPUT
    ,@dLottable04      DATETIME     = NULL OUTPUT
    ,@dLottable05      DATETIME     = NULL OUTPUT
    ,@nTotalOrder      INT          = 0    OUTPUT
    ,@nTotalQty        INT          = 0    OUTPUT
    ,@cPDDropID        NVARCHAR(20) = ''   OUTPUT
    ,@cPDLoc           NVARCHAR(20) = ''   OUTPUT
    ,@cPDToLoc         NVARCHAR(20) = ''   OUTPUT
    ,@cPDID            NVARCHAR(20) = ''   OUTPUT
    ,@cWaveKey         NVARCHAR(10) = ''   OUTPUT

)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @bSuccess               INT
   DECLARE @cDeviceProfileLogKey   NVARCHAR(10)
   DECLARE @cBypassTCPSocketClient NVARCHAR(1)

   -- Get storer config
   SET @cBypassTCPSocketClient = ''
   EXECUTE nspGetRight
      NULL,
      @cStorerKey,
      NULL,
      'BypassTCPSocketClient',
      @bSuccess                OUTPUT,
      @cBypassTCPSocketClient  OUTPUT,
      @nErrNo                  OUTPUT,
      @cErrMsg                 OUTPUT

   -- Initialize LightModules
   IF @cBypassTCPSocketClient <> '1'
      EXEC [dbo].[isp_DPC_TerminateAllLight]
            @cStorerKey
           ,@cCartID
           ,@bSuccess    OUTPUT
           ,@nErrNo      OUTPUT
           ,@cErrMsg     OUTPUT

   -- Get working batch
   SELECT TOP 1
      @cDeviceProfileLogKey = DeviceProfileLogKey
   FROM dbo.DeviceProfile WITH (NOLOCK)
	WHERE DeviceID = @cCartID
	  AND Status IN ('1', '3')

   -- Default
   SET @cLottable01 = ''
   SET @cLottable02 = ''
   SET @cLottable03 = ''
   SET @dLottable04 = 0
   SET @cLOT        = ''
   SET @cPDToLoc    = ''
   SET @cPDDropID   = ''
   SET @cWaveKey    = ''
   SET @cPDLoc      = ''
   SET @cPDID       = ''

   -- Get task in same LOC, next SKU
   SELECT TOP 1
      @cLOC = PTL.LOC,
      @cSKU = PTL.SKU
   FROM PTLTran PTL WITH (NOLOCK)
      JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PTL.LOC)
   WHERE PTL.DeviceProfileLogKey = @cDeviceProfileLogKey
      AND PTL.Status = '0'
      AND PTL.LOC = @cLOC
   ORDER BY LOC.LogicalLocation, LOC.LOC, PTL.SKU

   IF @@ROWCOUNT = 0
   BEGIN
      -- Get task for next LOC
      SELECT TOP 1
         @cLOC = PTL.LOC,
         @cSKU = PTL.SKU
      FROM PTLTran PTL WITH (NOLOCK)
         JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PTL.LOC)
      WHERE PTL.DeviceProfileLogKey = @cDeviceProfileLogKey
         AND PTL.Status = '0'
         AND PTL.LOC > @cLOC
      ORDER BY LOC.LogicalLocation, LOC.LOC, PTL.SKU

      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 79801
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'NoTask!'
         GOTO Quit
      END
   END

   -- Update pick in progress
   IF NOT EXISTS( SELECT 1 FROM dbo.DeviceProfile WITH (NOLOCK) WHERE DeviceProfileLogKey = @cDeviceProfileLogKey AND Status = '3')
   BEGIN
      UPDATE dbo.DeviceProfile WITH (ROWLOCK) SET
         Status = '3'
      WHERE DeviceProfileLogKey = @cDeviceProfileLogKey
         AND Status = '1'

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 79803
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdDPFail'
         GOTO Quit
      END

      UPDATE DeviceProfileLog WITH (ROWLOCK) SET
         Status = '3'
      WHERE DeviceProfileLogKey = @cDeviceProfileLogKey
         AND Status = '1'

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 79804
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdDPLogFail'
         GOTO Quit
      END
   END

   -- Get SKU info
   SELECT @cSKUDescr = Descr FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU

   -- Get total order, QTY
   SELECT
      @nTotalOrder = COUNT( DISTINCT OrderKey),
      @nTotalQty = SUM( ExpectedQTY)
   FROM dbo.PTLTran WITH (NOLOCK)
	WHERE DeviceProfileLogKey = @cDeviceProfileLogKey
	  AND SKU = @cSKU
	  AND LOC = @cLOC
	  AND Status = '0'

Quit:

END

GO
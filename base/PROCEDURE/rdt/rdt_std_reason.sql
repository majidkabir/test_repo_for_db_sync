SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_STD_Reason                                      */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Standard reason code handling                               */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 2010-05-20 1.0  James       Created                                  */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_STD_Reason] (
   @nFunc          INT,
   @nMobile        INT,
   @cLangCode      NVARCHAR( 3),
   @nErrNo         INT          OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT, -- screen limitation, 20 char max
   @cStorerKey     NVARCHAR( 15),
   @cFacility      NVARCHAR( 5),
   @cPickSlipNo    NVARCHAR( 10),
   @cLoadKey       NVARCHAR( 10),
   @cWaveKey       NVARCHAR( 10),
   @cOrderKey      NVARCHAR( 10),
   @cLOC           NVARCHAR( 10),
   @cID            NVARCHAR( 18),
   @cSKU           NVARCHAR( 20),
   @cUOM           NVARCHAR( 10),
   @nQTY           INT,       -- In master unit
   @cLottable01    NVARCHAR( 18),
   @cLottable02    NVARCHAR( 18),
   @cLottable03    NVARCHAR( 18),
   @dLottable04    DATETIME,
   @dLottable05    DATETIME,
   @cReasonCode    NVARCHAR( 10),
   @cUserName      NVARCHAR( 15),
   @cModuleName    NVARCHAR( 45),
   @cNotes         NVARCHAR( 45)
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @bSuccess INT
   DECLARE @nTranCount INT
   DECLARE @cAlertMessage NVARCHAR( 255)
   DECLARE @cRSN_Descr NVARCHAR( 60)

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN STD_Reason

   /*-------------------------------------------------------------------------------

                                    Convert parameters

   -------------------------------------------------------------------------------*/
   IF @cStorerKey  IS NULL SET @cStorerKey  = ''
   IF @cFacility   IS NULL SET @cFacility   = ''
   IF @cPickSlipNo IS NULL SET @cPickSlipNo = ''
   IF @cLoadKey    IS NULL SET @cLoadKey    = ''
   IF @cWaveKey    IS NULL SET @cWaveKey    = ''
   IF @cOrderKey   IS NULL SET @cOrderKey   = ''
   IF @cLOC        IS NULL SET @cLOC        = ''
   IF @cID         IS NULL SET @cID         = ''
   IF @cSKU        IS NULL SET @cSKU        = ''
   IF @cUOM        IS NULL SET @cSKU        = ''
   IF @nQTY        IS NULL SET @nQTY        = 0
   IF @cLottable01 IS NULL SET @cLottable01 = ''
   IF @cLottable02 IS NULL SET @cLottable02 = ''
   IF @cLottable03 IS NULL SET @cLottable03 = ''
   IF @dLottable04 = 0     SET @dLottable04 = NULL
   IF @dLottable05 = 0     SET @dLottable05 = NULL
   IF @cUserName   IS NULL SET @cUserName   = ''

   -- Truncate the time portion
   IF @dLottable04 IS NOT NULL
      SET @dLottable04 = CONVERT( DATETIME, CONVERT( NVARCHAR( 10), @dLottable04, 120), 120)
   IF @dLottable05 IS NOT NULL
      SET @dLottable05 = CONVERT( DATETIME, CONVERT( NVARCHAR( 10), @dLottable05, 120), 120)

   -- Validate StorerKey
   IF @cStorerKey = ''
   BEGIN
      SET @nErrNo = 69516
      SET @cErrMsg = rdt.rdtgetmessage( 69516, @cLangCode, 'DSP') --'Need Storer'
      GOTO Fail
   END

   -- Validate Facility
   IF @cFacility = ''
   BEGIN
      SET @nErrNo = 69517
      SET @cErrMsg = rdt.rdtgetmessage( 69517, @cLangCode, 'DSP') --'Need Fac'
      GOTO Fail
   END

   -- Validate PickSlipNo
   IF @cPickSlipNo <> ''
   BEGIN
      IF NOT EXISTS (SELECT 1 FROM dbo.PickHeader WITH (NOLOCK) WHERE PickHeaderKey = @cPickSlipNo)
      BEGIN
         SET @nErrNo = 69518
         SET @cErrMsg = rdt.rdtgetmessage( 69518, @cLangCode, 'DSP') --'BAD PKSlip'
         GOTO Fail
      END
   END

   IF @cUserName = ''
   BEGIN
      SET @nErrNo = 69519
      SET @cErrMsg = rdt.rdtgetmessage( 69519, @cLangCode, 'DSP') --'BAD UserID'
      GOTO Fail
   END

   IF NOT EXISTS (SELECT 1 FROM dbo.TaskManagerReason WITH (NOLOCK) WHERE TaskManagerReasonKey = @cReasonCode)
   BEGIN
      SET @nErrNo = 69520
      SET @cErrMsg = rdt.rdtgetmessage( 69520, @cLangCode, 'DSP') --'BAD RSN'
      GOTO Fail
   END

   IF NOT EXISTS (SELECT 1 FROM dbo.TaskManagerReason WITH (NOLOCK)
      WHERE TaskManagerReasonKey = @cReasonCode
         AND ValidInFromLoc = '1')
   BEGIN
      SET @nErrNo = 69521
      SET @cErrMsg = rdt.rdtgetmessage( 69521, @cLangCode, 'DSP') --'X ValidAtLOC'
      GOTO Fail
   END

   SELECT @cRSN_Descr = Descr FROM dbo.TaskManagerReason WITH (NOLOCK)
   WHERE TaskManagerReasonKey = @cReasonCode
      AND ValidInFromLoc = '1'

   SET @cAlertMessage = @cNotes + ': ' + @cPickSlipNo
   IF @cLoadKey = ''
      SET @cAlertMessage = RTRIM(@cAlertMessage) + ' Wave: ' + @cWaveKey
   ELSE
      SET @cAlertMessage = RTRIM(@cAlertMessage) + ' Load: ' + @cLoadKey
   SET @cAlertMessage = RTRIM(@cAlertMessage) + ' Order: ' + @cOrderKey
   SET @cAlertMessage = RTRIM(@cAlertMessage) + ' SKU: ' + @cSKU
   SET @cAlertMessage = RTRIM(@cAlertMessage) + ' QTY: ' + CAST(@nQty AS NVARCHAR( 5))
   SET @cAlertMessage = RTRIM(@cAlertMessage) + ' UID: ' + @cUserName
   SET @cAlertMessage = RTRIM(@cAlertMessage) + ' MOB: ' + CAST(@nMobile AS NVARCHAR( 5))
   SET @cAlertMessage = RTRIM(@cAlertMessage) + ' DateTime: ' + CONVERT(CHAR,GETDATE(), 103)
   SET @cAlertMessage = RTRIM(@cAlertMessage) + ' RSN: ' + @cReasonCode
   SET @cAlertMessage = RTRIM(@cAlertMessage) + ' RSN Desc: ' + @cRSN_Descr

   -- Insert LOG Alert
   SELECT @bSuccess = 1
   EXECUTE dbo.nspLogAlert
	   @c_ModuleName   = @cModuleName,
	   @c_AlertMessage = @cAlertMessage,
	   @n_Severity     = 0,
	   @b_success      = @bSuccess OUTPUT,
	   @n_err          = @nErrNo OUTPUT,
	   @c_errmsg       = @cErrmsg OUTPUT

   IF NOT @bSuccess = 1
   BEGIN
      GOTO Fail
   END

   GOTO Quit   -- Success and goto commit transaction

   Fail:
      ROLLBACK TRAN STD_Reason

   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN STD_Reason
END

GO
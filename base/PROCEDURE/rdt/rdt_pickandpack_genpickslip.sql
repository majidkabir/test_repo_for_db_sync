SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_PickAndPack_GenPickSlip                         */
/* Copyright: LF Logistics                                              */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2014-08-07 1.0  Ung        SOS317600                                 */
/************************************************************************/

CREATE PROC [RDT].[rdt_PickAndPack_GenPickSlip] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @cStorerKey     NVARCHAR( 15),
   @cFacility      NVARCHAR( 5),
   @cGenPickSlipSP NVARCHAR( 20),
   @cOrderKey      NVARCHAR( 10),
   @cPickSlipNo    NVARCHAR( 10) OUTPUT,
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL      NVARCHAR(1000)
   DECLARE @cSQLParam NVARCHAR(1000)

   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_PickAndPack_GenPickSlip

   IF @cGenPickSlipSP = '1'
   BEGIN
      -- Get PickSlipNo
      DECLARE @bsuccess INT
      EXECUTE dbo.nspg_GetKey
         'PICKSLIP',
         9,
         @cPickslipNo   OUTPUT,
         @bsuccess      OUTPUT,
         @nErrNo        OUTPUT,
         @cErrMsg       OUTPUT  
      IF @nErrNo <> 0
         GOTO RollBackTran

      SET @cPickslipNo = 'P' + @cPickslipNo

      -- Insert PickHeader
      INSERT INTO dbo.PickHeader (PickHeaderKey, ExternOrderKey, Orderkey, PickType, Zone)
      VALUES (@cPickslipno, '', @cOrderKey, '0', 'D')
      IF @@ERROR <> 0
         GOTO RollBackTran

      -- Insert PickingInfo
      IF NOT EXISTS( SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickslipNo)
      BEGIN
         -- Get login info
         DECLARE @cUserName NVARCHAR(18)
         SET @cUserName = SUSER_SNAME()

         EXEC dbo.isp_ScanInPickslip
            @c_PickSlipNo = @cPickSlipNo,
            @c_PickerID   = @cUserName,
            @n_err        = @nErrNo      OUTPUT,
            @c_errmsg     = @cErrMsg     OUTPUT
         IF @nErrNo <> 0
            GOTO RollBackTran
      END
   END
   ELSE
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cGenPickSlipSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cGenPickSlipSP) +
            ' @nMobile, @nFunc, @cLangCode, @cStorerKey, @cFacility, @cOrderKey, @cPickSlipNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
         SET @cSQLParam =
            '@nMobile     INT,           ' +
            '@nFunc       INT,           ' +
            '@cLangCode   NVARCHAR( 3),  ' +
            '@cStorerKey  NVARCHAR( 15), ' +
            '@cFacility   NVARCHAR( 5),  ' +
            '@cOrderKey   NVARCHAR( 10), ' +
            '@cPickSlipNo NVARCHAR( 10) OUTPUT, ' +
            '@nErrNo      INT           OUTPUT, ' +
            '@cErrMsg     NVARCHAR( 20) OUTPUT'

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @cStorerKey, @cFacility, @cOrderKey, @cPickSlipNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO Quit
      END
   END

   COMMIT TRAN rdt_PickAndPack_GenPickSlip
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_PickAndPack_GenPickSlip
Quit:
   WHILE @@TRANCOUNT > @nTranCount
      COMMIT TRAN

GO
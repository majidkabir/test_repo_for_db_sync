SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_850ExtUpdSP01                                   */
/* Purpose: PPA Update                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2014-03-26 1.0  ChewKP     SOS#303019. Created                       */
/* 2017-06-02 1.1  James      Add new param (james01)                   */
/* 2018-11-19 1.2  Ung        WMS-6932 Add ID param                     */
/* 2019-03-29 1.3  James      WMS-8002 Add TaskDetailKey param (james02)*/
/* 2021-07-06 1.4  YeeKung     WMS-17278 Add Reasonkey (yeekung01)      */
/************************************************************************/

CREATE PROC [RDT].[rdt_850ExtUpdSP01] (
   @nMobile     INT,
   @nFunc       INT, 
   @cLangCode   NVARCHAR( 3), 
   @nStep       INT, 
   @nInputKey   INT, 
   @cStorerKey  NVARCHAR( 15), 
   @cRefNo      NVARCHAR( 10), 
   @cPickSlipNo NVARCHAR( 10),
   @cLoadKey    NVARCHAR( 10),
   @cOrderKey   NVARCHAR( 10), 
   @cDropID     NVARCHAR( 20),
   @cSKU        NVARCHAR( 20),
   @nQty        INT,
   @cOption     NVARCHAR( 1), 
   @nErrNo      INT           OUTPUT, 
   @cErrMsg     NVARCHAR( 20) OUTPUT, 
   @cID         NVARCHAR( 18) = '',
   @cTaskDetailKey   NVARCHAR( 10) = '',
   @cReasonCode  NVARCHAR(20) OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

   DECLARE @nTranCount     INT, 
           @cUOM           NVARCHAR( 10),
           @nCSKU          INT,
           @nCQTY          INT,
           @nPSKU          INT,
           @nPQTY          INT
      
   SET @nTranCount = @@TRANCOUNT

   -- Scan Out Start
   BEGIN TRAN
   SAVE TRAN PPA

   IF @nStep <> 2 OR @nInputKey <> 0
      GOTO Quit

   SELECT @cUOM = V_UOM FROM rdt.rdtMOBREC WITH (NOLOCK) WHERE UserName = sUser_sName()

   EXECUTE rdt.rdt_PostPickAudit_GetStat @nMobile, @nFunc, @cRefNo, @cPickSlipNo, @cLoadKey, @cOrderKey, @cDropID, @cStorerKey, @cUOM,
      @nCSKU OUTPUT,
      @nCQTY OUTPUT,
      @nPSKU OUTPUT,
      @nPQTY OUTPUT

   -- Discrepancy found
   IF @nCSKU <> @nPSKU OR @nCQTY <> @nPQTY
      GOTO Quit
         
   EXEC dbo.isp_ScanOutPickslip
      @c_PickSlipNo 		= @cPickSlipNo, 
      @n_err            = @nErrNo OUTPUT,
      @c_errmsg         = @cErrMsg OUTPUT          
      
   IF @nErrNo <> 0
      GOTO RollBackTran

   GOTO Quit
   

   RollBackTran:
   ROLLBACK TRAN PPA
   
QUIT:
   WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started
         COMMIT TRAN PPA

GO
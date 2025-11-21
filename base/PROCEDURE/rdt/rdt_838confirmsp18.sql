SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_838ConfirmSP18                                        */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date       Rev  Author      Purposes                                       */
/* 17-08-2023 1.0  Ung         WMS-22913 FromDropID = PackDetail.DropID       */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_838ConfirmSP18] (
    @nMobile         INT
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR( 3)
   ,@nStep           INT
   ,@nInputKey       INT
   ,@cFacility       NVARCHAR( 5)
   ,@cStorerKey      NVARCHAR( 15)
   ,@cPickSlipNo     NVARCHAR( 10)
   ,@cFromDropID     NVARCHAR( 20)
   ,@cSKU            NVARCHAR( 20)
   ,@nQTY            INT
   ,@cUCCNo          NVARCHAR( 20)
   ,@cSerialNo       NVARCHAR( 30)
   ,@nSerialQTY      INT
   ,@cPackDtlRefNo   NVARCHAR( 20)
   ,@cPackDtlRefNo2  NVARCHAR( 20)
   ,@cPackDtlUPC     NVARCHAR( 30)
   ,@cPackDtlDropID  NVARCHAR( 20)
   ,@nCartonNo       INT           OUTPUT
   ,@cLabelNo        NVARCHAR( 20) OUTPUT
   ,@nErrNo          INT           OUTPUT
   ,@cErrMsg         NVARCHAR(250) OUTPUT
   ,@nBulkSNO        INT
   ,@nBulkSNOQTY     INT
   ,@cPackData1      NVARCHAR( 30)
   ,@cPackData2      NVARCHAR( 30)
   ,@cPackData3      NVARCHAR( 30)
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   -- Set PickDetail.DropID = PackDetail.DropID
   IF @cFromDropID <> ''
      SET @cPackDtlDropID = @cFromDropID
   
   -- Standard confirm
   EXEC rdt.rdt_Pack_Confirm
       @nMobile        = @nMobile
      ,@nFunc          = @nFunc
      ,@cLangCode      = @cLangCode
      ,@nStep          = @nStep
      ,@nInputKey      = @nInputKey
      ,@cFacility      = @cFacility
      ,@cStorerKey     = @cStorerKey
      ,@cPickSlipNo    = @cPickSlipNo
      ,@cFromDropID    = @cFromDropID
      ,@cSKU           = @cSKU
      ,@nQTY           = @nQTY
      ,@cUCCNo         = @cUCCNo
      ,@cSerialNo      = @cSerialNo
      ,@nSerialQTY     = @nSerialQTY
      ,@cPackDtlRefNo  = @cPackDtlRefNo
      ,@cPackDtlRefNo2 = @cPackDtlRefNo2
      ,@cPackDtlUPC    = @cUCCNo         -- PackDetail.UPC = UCCNo
      ,@cPackDtlDropID = @cPackDtlDropID
      ,@nCartonNo      = @nCartonNo      OUTPUT
      ,@cLabelNo       = @cLabelNo       OUTPUT
      ,@nErrNo         = @nErrNo         OUTPUT
      ,@cErrMsg        = @cErrMsg        OUTPUT
      ,@nBulkSNO       = @nBulkSNO
      ,@nBulkSNOQTY    = @nBulkSNOQTY
      ,@cPackData1     = @cPackData1
      ,@cPackData2     = @cPackData2
      ,@cPackData3     = @cPackData3
      ,@nUseStandard   = 1 -- Force use back standard logic, otherwise infinite loop

END

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*********************************************************************************/
/* Store procedure: rdt_DynamicPick_PickAndPack_NewCarton                        */
/* Copyright      : IDS                                                          */
/*                                                                               */
/* Purpose: Get next location for Pick And Pack function                         */
/*                                                                               */
/* Called from: rdtfnc_DynamicPick_PickAndPack                                   */
/*                                                                               */
/* Exceed version: 5.4                                                           */
/*                                                                               */
/* Modifications log:                                                            */
/*                                                                               */
/* Date        Rev  Author      Purposes                                         */
/* 20-Jan-2014 1.0  Ung         SOS294417 New carton                             */
/* 28-Jul-2016 1.1  Ung         SOS375224 Add LoadKey, Zone optional             */
/* 07-Jun-2018 1.2  Ung         INC0228346 Standardize GetNextCartonLabel param  */
/*********************************************************************************/

CREATE PROC [RDT].[rdt_DynamicPick_PickAndPack_NewCarton] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5),
   @cStorerKey    NVARCHAR( 15),
   @cUserName     NVARCHAR( 18),
	@cPrinter      NVARCHAR( 10),
   @cPickSlipType NVARCHAR( 10),
   @cPickSlipNo   NVARCHAR( 10),
   @cPickZone     NVARCHAR( 10),
   @cFromLOC      NVARCHAR( 10),
   @cToLOC        NVARCHAR( 10),
   @cDynamicPickCartonLabel       NVARCHAR(1),
   @cDynamicPickCartonManifest    NVARCHAR(1),
   @cDynamicPickPrePrintedLabelNo NVARCHAR(1),
   @nCartonNo     INT             OUTPUT,
   @cLabelNo      NVARCHAR( 20)   OUTPUT,
   @nErrNo        INT             OUTPUT,
   @cErrMsg       NVARCHAR( 20)   OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   -- Print Carton Manifest
   IF @cPrinter <> '' AND @cDynamicPickCartonManifest = '1'
      EXECUTE rdt.rdt_DynamicPick_PickAndPack_PrintJob
         @cStorerKey, 'PRINTCTNMNFEST', 'CTNMNFEST', @cPrinter, '0', 3, 1, @nMobile, @cPickSlipNo, @cLabelNo, @cLabelNo, '', '',
         @cLangCode,
         @nErrNo       OUTPUT,
         @cErrMsg      OUTPUT

   -- Get next CartonNo, LabelNo
   EXECUTE rdt.rdt_DynamicPick_PickAndPack_GetNextCartonLabel @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
      @cUserName, 
      @cPrinter,
      @cDynamicPickCartonLabel,
      @cDynamicPickPrePrintedLabelNo,
      @cPickSlipNo,
      @cPickZone,
      @cFromLoc,
      @cToLoc,
      @nCartonNo   OUTPUT,
      @cLabelNo    OUTPUT,
      @nErrNo      OUTPUT,
      @cErrMsg     OUTPUT
   IF @nErrNo <> 0 GOTO Fail

   -- Print Carton Label
   IF @cPrinter <> '' AND @cDynamicPickCartonLabel = '1'
   BEGIN
      DECLARE @nBal INT
      SET @nBal = 0
      EXEC rdt.rdt_DynamicPick_PickAndPack_GetStat @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
         ,@cPickSlipType
         ,@cPickSlipNo
         ,@cPickZone
         ,@cFromLoc
         ,@cToLoc
         ,'Balance'
         ,@nBal    OUTPUT
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT

      IF @nBal > 0
      BEGIN
         EXECUTE rdt.rdt_DynamicPick_PickAndPack_PrintJob
            @cStorerKey, 'PRINTCARTONLBL', 'CARTONLBL', @cPrinter, '0', 5, 1,
            @nMobile, @cPickSlipNo, @nCartonNo, @nCartonNo, @cLabelNo, @cLabelNo,
            @cLangCode,
            @nErrNo       OUTPUT,
            @cErrMsg      OUTPUT
      END
   END
Fail:

END

GO
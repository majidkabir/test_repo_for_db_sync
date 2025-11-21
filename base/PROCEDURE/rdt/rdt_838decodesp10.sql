SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_838DecodeSP10                                   */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose: Decode SKU, Lottable01.                                     */
/*          Save L01 to rdtMobRec, as FN838 not yet support lottables   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2023-11-06  1.0  Ung         WMS-24060 Created                       */
/* 2024-10-25  1.1  PXL009      FCR-759 ID and UCC Length Issue         */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_838DecodeSP10]
   @nMobile             INT,
   @nFunc               INT,
   @cLangCode           NVARCHAR( 3),
   @nStep               INT,
   @nInputKey           INT,
   @cFacility           NVARCHAR( 5),
   @cStorerKey          NVARCHAR( 15),
   @cPickSlipNo         NVARCHAR( 10),
   @cFromDropID         NVARCHAR( 20),
   @cBarcode            NVARCHAR( 60),
   @cBarcode2           NVARCHAR( 60),
   @cSKU                NVARCHAR( 20)  OUTPUT,
   @nQTY                INT            OUTPUT,
   @cPackDtlRefNo       NVARCHAR( 20)  OUTPUT,
   @cPackDtlRefNo2      NVARCHAR( 20)  OUTPUT,
   @cPackDtlUPC         NVARCHAR( 30)  OUTPUT,
   @cPackDtlDropID      NVARCHAR( 20)  OUTPUT,
   @cSerialNo           NVARCHAR( 30)  OUTPUT,
   @cFromDropIDDecode   NVARCHAR( 20)  OUTPUT,
   @cToDropIDDecode     NVARCHAR( 20)  OUTPUT,
   @cUCCNo              NVARCHAR( 20)  OUTPUT,
   @nErrNo              INT            OUTPUT,
   @cErrMsg             NVARCHAR( 20)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 838
   BEGIN
      IF @nStep = 3  -- SKU QTY
      BEGIN
         IF @nInputKey = 1
         BEGIN

            DECLARE @bSuccess    INT
            DECLARE @cOrderKey   NVARCHAR( 10)
            DECLARE @cLottable01 NVARCHAR( 18) = ''
            DECLARE @cUPC        NVARCHAR( 30) = ''
            DECLARE @nQTY_Bal    INT

            -- Standard decode
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,
               @cUPC        = @cUPC         OUTPUT,
               @cLottable01 = @cLottable01  OUTPUT

            -- Get SKU count
            DECLARE @nSKUCnt INT
            SET @nSKUCnt = 0
            EXEC RDT.rdt_GetSKUCNT
               @cStorerKey  = @cStorerKey
               ,@cSKU        = @cUPC
               ,@nSKUCnt     = @nSKUCnt   OUTPUT
               ,@bSuccess    = @bSuccess  OUTPUT
               ,@nErr        = @nErrNo    OUTPUT
               ,@cErrMsg     = @cErrMsg   OUTPUT

            -- Check SKU valid
            IF @nSKUCnt = 0
            BEGIN
               SET @nErrNo = 208251
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
               EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', '', @nErrNo, @cErrMsg
               SET @cErrMsg = ''
               GOTO Quit
            END
            SET @cSKU = @cUPC 

            -- Get PickHeader info
            SELECT TOP 1
               @cOrderKey = OrderKey
            FROM dbo.PickHeader WITH (NOLOCK)
            WHERE PickHeaderKey = @cPickSlipNo

            -- Check SKU, L01 in PickSlipNo
            IF NOT EXISTS( SELECT TOP 1 1
               FROM dbo.PickDetail PD WITH (NOLOCK) 
                  JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
               WHERE PD.OrderKey = @cOrderKey
                  AND PD.StorerKey = @cStorerKey
                  AND PD.SKU = @cSKU
                  AND LA.Lottable01 = @cLottable01
                  AND PD.QTY > 0
                  AND PD.Status <> '4')
            BEGIN
               SET @nErrNo = 208252
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKUL01 NotinPS
               EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', '', @nErrNo, @cErrMsg
               SET @cErrMsg = ''
               GOTO Quit
            END

            -- Get QTY not yet pack
            SELECT @nQTY_Bal = ISNULL( SUM( QTY), 0)
            FROM dbo.PickDetail PD WITH (NOLOCK) 
               JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
            WHERE PD.OrderKey = @cOrderKey
               AND PD.StorerKey = @cStorerKey
               AND PD.SKU = @cSKU
               AND LA.Lottable01 = @cLottable01
               AND PD.CaseID = ''
               AND PD.QTY > 0
               AND PD.Status <> '4'

            -- Check over pack
            IF @nQTY > @nQTY_Bal 
            BEGIN
               SET @nErrNo = 208253
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over pack
               EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', '', @nErrNo, @cErrMsg
               SET @cErrMsg = ''
               GOTO Quit
            END

            -- Save to session
            UPDATE rdt.rdtMobRec SET 
               V_Lottable01 = @cLottable01
            WHERE Mobile = @nMobile
         END
      END
   END

Quit:

END

GO
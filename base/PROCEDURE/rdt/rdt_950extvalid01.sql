SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_950ExtValid01                                   */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date        Rev Author      Purposes                                 */
/* 13-Apr-2018 1.0 James       WMS4107 Created                          */
/************************************************************************/

CREATE PROC [RDT].[rdt_950ExtValid01] (
   @nMobile      INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @nInputKey       INT,
   @cFacility       NVARCHAR( 5),
   @cStorerKey      NVARCHAR( 15),
   @cWaveKey        NVARCHAR( 10),
   @cLoadKey        NVARCHAR( 10),
   @cPickZone       NVARCHAR( 10),
   @cPKSLIP_Cnt     NVARCHAR( 5) ,
   @cCountry        NVARCHAR( 20),
   @cFromLOC        NVARCHAR( 10),
   @cToLOC          NVARCHAR( 10),
   @cT_PickSlipNo1  NVARCHAR( 10),
   @cT_PickSlipNo2  NVARCHAR( 10),
   @cT_PickSlipNo3  NVARCHAR( 10),
   @cT_PickSlipNo4  NVARCHAR( 10),
   @cT_PickSlipNo5  NVARCHAR( 10),
   @cT_PickSlipNo6  NVARCHAR( 10),
   @cT_PickSlipNo7  NVARCHAR( 10),
   @cT_PickSlipNo8  NVARCHAR( 10),
   @cT_PickSlipNo9  NVARCHAR( 10),
   @cPickSlipNo     NVARCHAR( 10),
   @cS_LOC          NVARCHAR( 10),
   @cSKU            NVARCHAR( 20),
   @cLottable01     NVARCHAR( 18),
   @cLottable02     NVARCHAR( 18),
   @cLottable03     NVARCHAR( 18),
   @dLottable04     DATETIME     ,
   @nQtyToPick      INT          ,
   @nActQty         INT          ,
   @nCartonNo       INT          ,
   @cLabelNo        NVARCHAR( 20),
   @cOption         NVARCHAR( 1) ,
   @nErrNo          INT OUTPUT   ,
   @cErrMsg         NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 950
   BEGIN
      IF @nStep = 5 
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF NOT EXISTS ( SELECT 1 FROM PickDetail PD WITH (NOLOCK)
                            JOIN dbo.PICKHEADER PH WITH (NOLOCK) ON PD.OrderKey = PH.OrderKey
                            WHERE PD.StorerKey = @cStorerKey
                            AND   PD.SKU = @cSKU
                            AND   PD.Status < '5'
                            AND   PH.PickHeaderKey = @cPickSlipNo
                            AND   PH.WaveKey = @cWaveKey)
            BEGIN
               SET @nErrNo = 122801
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU Not In Ord
               GOTO Quit
            END
         END
      END
   END

Quit:

END

GO
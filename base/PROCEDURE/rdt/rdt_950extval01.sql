SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_950ExtVal01                                           */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date        Rev  Author   Purposes                                         */
/* 14-Sep-2016 1.0  Ung      SOS375224 Created                                */
/******************************************************************************/

CREATE PROC [RDT].[rdt_950ExtVal01] (
    @nMobile         INT
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR( 3)
   ,@nStep           INT
   ,@nInputKey       INT
   ,@cFacility       NVARCHAR( 5)
   ,@cStorerKey      NVARCHAR( 15)
   ,@cWaveKey        NVARCHAR( 10)
   ,@cLoadKey        NVARCHAR( 10)
   ,@cPickZone       NVARCHAR( 10)
   ,@cPKSLIP_Cnt     NVARCHAR( 5)
   ,@cCountry        NVARCHAR( 20)
   ,@cFromLOC        NVARCHAR( 10)
   ,@cToLOC          NVARCHAR( 10)
   ,@cT_PickSlipNo1  NVARCHAR( 10)
   ,@cT_PickSlipNo2  NVARCHAR( 10)
   ,@cT_PickSlipNo3  NVARCHAR( 10)
   ,@cT_PickSlipNo4  NVARCHAR( 10)
   ,@cT_PickSlipNo5  NVARCHAR( 10)
   ,@cT_PickSlipNo6  NVARCHAR( 10)
   ,@cT_PickSlipNo7  NVARCHAR( 10)
   ,@cT_PickSlipNo8  NVARCHAR( 10)
   ,@cT_PickSlipNo9  NVARCHAR( 10)
   ,@cPickSlipNo     NVARCHAR( 10)
   ,@cS_LOC          NVARCHAR( 10)
   ,@cSKU            NVARCHAR( 20)
   ,@cLottable01     NVARCHAR( 18)
   ,@cLottable02     NVARCHAR( 18)
   ,@cLottable03     NVARCHAR( 18)
   ,@dLottable04     DATETIME
   ,@nQtyToPick      INT
   ,@nActQty         INT
   ,@nCartonNo       INT
   ,@cLabelNo        NVARCHAR( 20)
   ,@cOption         NVARCHAR( 1)
   ,@nErrNo          INT           OUTPUT
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF


   IF @nFunc = 950 -- Dynamic pick and pack
   BEGIN
      IF @nStep = 1 -- Wave, LoadKey
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Check blank
            IF @cPickZone = ''
            BEGIN
               SET @nErrNo = 103901
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need PickZone
               EXEC rdt.rdtSetFocusField @nMobile, 2
            END
         END
      END
   END
END

GO
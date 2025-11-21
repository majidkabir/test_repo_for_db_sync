SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispVFDPExtUpd                                       */
/* Purpose: Send command to Junheinrich direct equipment to location    */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2013-02-21   Ung       1.0   SOS256104 Created                       */
/* 2016-09-23   Ung       1.1   Performance tuning                      */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdtVFDPExtUpd]
    @nMobile         INT
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR( 3)
   ,@nStep           INT
   ,@cFacility       NVARCHAR( 5)
   ,@cStorerKey      NVARCHAR( 15)
   ,@cWaveKey        NVARCHAR( 10)
   ,@cPWZone         NVARCHAR( 10)
   ,@cPKSLIP_Cnt     NVARCHAR(5)
   ,@cCountry        NVARCHAR( 20)
   ,@cFromLoc        NVARCHAR( 10)
   ,@cToLoc          NVARCHAR( 10)
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
   ,@nErrNo          INT       OUTPUT
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_Success   INT
   DECLARE @n_err       INT
   DECLARE @c_errmsg    NVARCHAR( 250)

   -- Dynamic pick and pack
   IF @nFunc = 950
   BEGIN
      IF @nStep = 3 -- Total QTY, CBM
      BEGIN
         /*
         1= wave released
         2= replenishment In Progress
         3= replenishment  completed
         4= picking started
         */
         IF EXISTS( SELECT 1 FROM dbo.Wave WITH (NOLOCK) WHERE WaveKey = @cWaveKey AND Status < '4')
         BEGIN
            UPDATE dbo.Wave SET
               Status = '4' -- Picking started
            WHERE WaveKey = @cWaveKey 
               AND Status < '4'
         END
      END

      IF @nStep = 6 -- LabelNo
      BEGIN
         IF LEFT( @cLabelNo, 2) <> 'VF'
         BEGIN
            SET @nErrNo = 83001
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidLabelNo
            GOTO Quit
         END
         
         -- Check if new carton
         IF NOT EXISTS( SELECT 1 
            FROM PackDetail WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo
               AND LabelNo = @cLabelNo
               AND QTY > 0)
         BEGIN
            EXEC dbo.ispJungheinrich @nMobile, @nFunc, @cLangCode, @nStep, '', @nErrNo OUTPUT, @cErrMsg OUTPUT, @cLabelNo, @cStorerKey, @cSKU
         END
      END
   END
END

Quit:

GO
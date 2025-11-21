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
/* 2013-04-25   Ung       1.0   SOS262114 Created                       */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdtVFUDPExtUpd]
    @nMobile         INT
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR( 3)
   ,@nStep           INT
   ,@cFacility       NVARCHAR( 5)
   ,@cStorerKey      NVARCHAR( 15)
   ,@cWaveKey        NVARCHAR( 10)
   ,@cPWZone         NVARCHAR( 10)
   ,@cFromLoc        NVARCHAR( 10)
   ,@cToLoc          NVARCHAR( 10)
   ,@cSuggestedLOC   NVARCHAR( 10)
   ,@cSKU            NVARCHAR( 20)
   ,@cLottable01     NVARCHAR( 18)
   ,@cLottable02     NVARCHAR( 18)
   ,@cLottable03     NVARCHAR( 18)
   ,@dLottable04     DATETIME
   ,@nQTY            INT
   ,@nBalQTY         INT
   ,@nTotalQTY       INT
   ,@cUCCNo          NVARCHAR( 20)
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

   -- Dynamic UCC pick and pack
   IF @nFunc = 949
   BEGIN
/*
      IF @nStep = 1 -- WaveKey
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
*/

      IF @nStep = 3 -- UCC
         EXEC dbo.ispJungheinrich @nMobile, @nFunc, @cLangCode, @nStep, '', @nErrNo OUTPUT, @cErrMsg OUTPUT, @cUCCNo
   END
END

Quit:

GO
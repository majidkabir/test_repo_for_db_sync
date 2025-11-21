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

CREATE PROCEDURE [RDT].[rdtVFMoveToIDExtUpd]
    @nMobile     INT
   ,@nFunc       INT
   ,@cLangCode   NVARCHAR( 3)
   ,@nStep       INT
   ,@cStorerKey  NVARCHAR( 15)
   ,@cToID       NVARCHAR( 18)
   ,@cFromLOC    NVARCHAR( 10)
   ,@cSKU        NVARCHAR( 20)
   ,@nQTY        INT
   ,@cToLOC      NVARCHAR( 10)
   ,@nErrNo      INT       OUTPUT
   ,@cErrMsg     NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_Success   INT
   DECLARE @n_err       INT
   DECLARE @c_errmsg    NVARCHAR( 250)

   -- Move To ID
   IF @nFunc = 534
   BEGIN
      IF @nStep = 5 -- To LOC
         EXEC dbo.ispJungheinrich @nMobile, @nFunc, @cLangCode, @nStep, '', @nErrNo OUTPUT, @cErrMsg OUTPUT, @cToID, @cStorerKey, @cSKU
   END
END

Quit:

GO
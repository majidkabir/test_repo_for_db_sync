SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_UAMoveCheck                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 26-03-2020  1.0  Ung      WMS-12631 Created                          */
/************************************************************************/

CREATE PROC [RDT].[rdt_UAMoveCheck] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nInputKey     INT,
   @cStorerKey    NVARCHAR( 15),
   @cFacility     NVARCHAR( 5),
   @cFromLOC      NVARCHAR( 10),
   @cToLOC        NVARCHAR( 10),
   @cType         NVARCHAR( 10), -- M or P. M=Move, P=Putaway
   @cSwapLOT      NVARCHAR( 1)  OUTPUT,
   @cChkQuality   NVARCHAR( 10) OUTPUT,
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cFromHWCode NVARCHAR( 10)
   DECLARE @cToHWCode   NVARCHAR( 10)

   -- Get host warehouse
   SELECT @cFromHWCode = HostWHCode FROM LOC WITH (NOLOCK) WHERE LOC = @cFromLOC
   SELECT @cToHWCode = HostWHCode FROM LOC WITH (NOLOCK) WHERE LOC = @cToLOC

   -- Get cross host warehouse setting
   SELECT 
      @cSwapLOT = ISNULL( Short, ''), 
      @cChkQuality = ISNULL( Long, '')
   FROM CodeLKUP WITH (NOLOCK)
   WHERE ListName = 'UAMOVECFG'
      AND StorerKey = @cStorerKey
      AND UDF01 = @cFromHWCode
      AND UDF02 = @cToHWCode
      AND Code2 = @nFunc

   -- Cross host warehouse not setup
   IF @@ROWCOUNT = 0
   BEGIN
      IF @cType = 'P'
      BEGIN
         SET @nErrNo = 150201
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PA not allow
      END

      IF @cType = 'M'
      BEGIN
         SET @nErrNo = 150202
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Move not allow
      END
      
      GOTO Quit
   END

Quit:

END

GO
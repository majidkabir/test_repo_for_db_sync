SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_514ExtVal06                                           */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: UA custom move check                                              */
/*                                                                            */
/* Date        Rev  Author   Purposes                                         */
/* 26-03-2020  1.0  Ung      WMS-12637 Created                                */
/* 20-01-2023  1.1  Ung      WMS-21577 Add unlimited UCC to move              */ 
/******************************************************************************/

CREATE   PROC [RDT].[rdt_514ExtVal06] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cStorerKey     NVARCHAR( 15),
   @cToID          NVARCHAR( 18),
   @cToLoc         NVARCHAR( 10),
   @cFromLoc       NVARCHAR( 10),
   @cFromID        NVARCHAR( 18),
   @cUCC           NVARCHAR( 20),
   @cUCC1          NVARCHAR( 20),
   @cUCC2          NVARCHAR( 20),
   @cUCC3          NVARCHAR( 20),
   @cUCC4          NVARCHAR( 20),
   @cUCC5          NVARCHAR( 20),
   @cUCC6          NVARCHAR( 20),
   @cUCC7          NVARCHAR( 20),
   @cUCC8          NVARCHAR( 20),
   @cUCC9          NVARCHAR( 20),
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 514 -- Move by UCC
   BEGIN
      IF @nStep = 2 -- To Loc/To ID
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            DECLARE @curUCC CURSOR
            SET @curUCC = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT DISTINCT UCC.LOC
               FROM UCC WITH (NOLOCK)
                  JOIN rdt.rdtMoveUCCLog T WITH (NOLOCK) ON (T.UCCNo = UCC.UCCNo AND T.StorerKey = @cStorerKey AND T.AddWho = SUSER_SNAME())
               WHERE UCC.StorerKey = @cStorerKey
            OPEN @curUCC
            FETCH NEXT FROM @curUCC INTO @cFromLOC
            WHILE @@FETCH_STATUS = 0
            BEGIN
               EXEC rdt.rdt_UAMoveCheck @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, ''
                  ,@cFromLOC 
                  ,@cToLOC 
                  ,'M' -- Type
                  ,''  -- SwapLOT
                  ,''  -- ChkQuality
                  ,@nErrNo  OUTPUT
                  ,@cErrMsg OUTPUT
               
               IF @nErrNo <> 0
                  GOTO Quit
               
               FETCH NEXT FROM @curUCC INTO @cFromLOC
            END
         END
      END
   END

Quit:

END

GO
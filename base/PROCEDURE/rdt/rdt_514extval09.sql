SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_514ExtVal09                                           */
/* Copyright      : Maersk                                                    */
/*                                                                            */
/* Purpose: Check same SKU UCC                                                */
/*                                                                            */
/* Date        Rev  Author   Purposes                                         */
/* 2023-05-06  1.0  Ung      WMS-22401 Created                                */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_514ExtVal09] (
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

   DECLARE @cChkUCCSKU NVARCHAR( 20)
   DECLARE @cUCCSKU    NVARCHAR( 20) = ''

   IF @nFunc = 514 -- Move by UCC
   BEGIN
      IF @nStep = 1 -- UCC
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Adding an UCC
            IF @cUCC <> ''
            BEGIN
               -- Get SKU of existing UCC
               SELECT TOP 1 
                  @cUCCSKU = UCC.SKU
               FROM rdt.rdtMoveUCCLog L WITH (NOLOCK)
                  JOIN dbo.UCC WITH (NOLOCK) ON (L.UCCNo = UCC.UCCNo AND L.StorerKey = @cStorerKey AND L.AddWho = SUSER_SNAME())
               WHERE L.StorerKey = @cStorerKey
                  AND L.AddWho = SUSER_SNAME()

               -- There is existing UCC
               IF @cUCCSKU <> ''
               BEGIN
                  -- Get SKU of newly added UCC 
                  SELECT TOP 1 
                     @cChkUCCSKU = SKU 
                  FROM dbo.UCC WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                     AND UCCNo = @cUCC
                  
                  -- Check same SKU
                  IF @cUCCSKU <> @cChkUCCSKU
                  BEGIN
                     SET @nErrNo = 200651
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Different SKU
                     GOTO Quit
                  END
               END
            END
         END
      END
   
      IF @nStep = 2 -- TO LOC
      BEGIN
         -- Check lose UCC LOC
         IF EXISTS( SELECT 1 FROM dbo.LOC WITH (NOLOCK) WHERE LOC = @cToLoc AND LoseUCC = '1')
         BEGIN
            SET @nErrNo = 200652
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Lose UCC LOC
            GOTO Quit
         END
      END
   END

Quit:

END

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/**************************************************************************/
/* Store procedure: rdt_1819ExtVal17                                      */
/*                                                                        */
/* Purpose:            Ace Turtle                                         */
/*                                                                        */
/* Date        Rev  Author   Purposes                                     */
/* 09-05-2024  1.0  JHU151   FCR-650. Created                             */
/**************************************************************************/

CREATE   PROC [RDT].[rdt_1819ExtVal17] (
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @nInputKey       INT,
   @cFromID         NVARCHAR( 18),
   @cSuggLOC        NVARCHAR( 10),
   @cPickAndDropLOC NVARCHAR( 10),
   @cToLOC          NVARCHAR( 10),
   @nErrNo          INT           OUTPUT,
   @cErrMsg         NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE 
      @nRowCount           INT,
      @cStorerKey          NVARCHAR(15),
      @cComingleCheck      NVARCHAR(30),
      @cSKU                NVARCHAR(20),
      @cSKU1               NVARCHAR(20)
               
              
   SELECT @cStorerKey = StorerKey
   FROM rdt.RDTMOBREC WITH(NOLOCK)
   WHERE Mobile = @nMobile

   IF @nFunc = 1819 -- Putaway by ID
   BEGIN
      IF @nStep = 2 -- to loc
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            --SET @cComingleCheck = rdt.RDTGetConfig( @nFunc, 'ComingleCheck', @cStorerKey)

            --IF @cComingleCheck = '1'
            --BEGIN
               IF @cSuggLOC <> @cToLOC
               AND EXISTS (SELECT 1
                           FROM LOC WITH(NOLOCK)
                           WHERE Loc = @cToLOC
                           AND CommingleSku = 0)
               BEGIN
                  SELECT TOP 1 @cSku = Sku
                  FROM dbo.LotxLocxID WITH(NOLOCK)
                  WHERE ID = @cFromID
                  AND qty > 0 

                  SELECT TOP 1 @cSku1 = Sku
                  FROM dbo.LotxLocxID WITH(NOLOCK)
                  WHERE Loc = @cToLOC
                  AND Qty > 0
                  
                  IF @@ROWCOUNT > 0
                  BEGIN
                     IF @cSku <> @cSKU1
                     BEGIN
                        SET @nErrNo = 222901
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Loc is not commingle     
                        GOTO Quit
                     END
                  END
               END
            --END            
         END
      END
   END

Quit:

END

GO
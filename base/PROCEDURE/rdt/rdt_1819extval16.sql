SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_1819ExtVal16                                    */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 04-06-2024  1.0  NLT013   FCR-267. Created                           */
/*                           If any SKU.PrePackIndicator=Y, throw error */
/* 13-08-2024  1.1  WyeChun  FCR-728. Ensure pallet close status in       */
/*                           RDTSTDEventLog before putaway process (WC01) */   
/************************************************************************/

CREATE   PROC [RDT].[rdt_1819ExtVal16] (
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
      @cStorerKey          NVARCHAR(15)

   SELECT @cStorerKey = StorerKey
   FROM rdt.RDTMOBREC WITH(NOLOCK)
   WHERE Mobile = @nMobile

   IF @nFunc = 1819 -- Putaway by ID
   BEGIN
      IF @nStep = 1 -- From ID
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            SELECT @nRowCount = COUNT(1)
            FROM dbo.UCC ucc WITH(NOLOCK)
            INNER JOIN dbo.SKU sku WITH(NOLOCK)
               ON ucc.StorerKey = sku.StorerKey
               AND ucc.Sku = sku.Sku
            WHERE Id = @cFromID
               AND ISNULL(sku.PrePackIndicator, '') = 'Y'
               AND sku.StorerKey = @cStorerKey
      
            IF @nRowCount > 0
            BEGIN
               SET @nErrNo = 216001
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NoPutawayStrategy      
               GOTO Quit
            END
       
            /*WC01 Start*/
            SELECT @nRowCount = COUNT(1)
            FROM RDT.RDTSTDEVENTLOG WITH (NOLOCK)
                     WHERE FUNCTIONID = '898'
                     AND STORERKEY = @cStorerKey
                     AND REFNO1 = 'CLOSE'
                     AND ID = @cFromID
                         
            IF @nRowCount = 0
            BEGIN
               SET @nErrNo = 216002
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PalletNotClose
               GOTO Quit
            END
            /*WC01 End*/
         END
      END
   END

Quit:

END

GO
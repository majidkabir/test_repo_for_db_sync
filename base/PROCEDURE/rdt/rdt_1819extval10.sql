SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1819ExtVal10                                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Validate pallet id before putaway (Check mix sku ucc)       */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2020-05-19   James     1.0   WMS-12964. Created                      */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1819ExtVal10]
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
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @cStorerKey NVARCHAR( 15),
           @cSKU       NVARCHAR( 20),
           @cUCC       NVARCHAR( 20) 

   DECLARE @cur_Chk    CURSOR

   SELECT @cStorerKey = StorerKey
   FROM rdt.RDTMOBREC WITH (NOLOCK) 
   WHERE Mobile = @nMobile

   IF @nInputKey = 1 
   BEGIN
      IF @nStep = 1 
      BEGIN
         SET @cur_Chk = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
         SELECT DISTINCT UCCNo, SKU 
         FROM dbo.UCC WITH (NOLOCK) 
         WHERE Storerkey = @cStorerKey
         AND   ID = @cFromID
         AND   [Status] = '1'
         OPEN @cur_Chk
         FETCH NEXT FROM @cur_Chk INTO @cUCC, @cSKU
         WHILE @@FETCH_STATUS = 0
         BEGIN
            IF EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK)
                        WHERE StorerKey = @cStorerKey
                        AND   UCCNo = @cUCC 
                        AND   [Status] = '1'
                        GROUP BY UCCNo 
                        HAVING COUNT( DISTINCT SKU) > 1)
            BEGIN
               SET @nErrNo = 152351
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Mix ucc sku
               BREAK
            END

            FETCH NEXT FROM @cur_Chk INTO @cUCC, @cSKU
         END
      END
   END

Quit:

END

GO
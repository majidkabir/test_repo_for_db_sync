SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_523ExtInfo07                                    */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2022-09-01 1.0  yeekung  WMS-20683. Created                          */
/* 2022-12-09 1.1  James    WMS-21307 Afterstep = 2 display (james01)   */
/*                          Add ItemClass at Afterstep = 3              */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_523ExtInfo07]
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @nAfterStep      INT,
   @nInputKey       INT,
   @cStorerKey      NVARCHAR( 15),
   @cFacility       NVARCHAR( 5),
   @cLOC            NVARCHAR( 10),
   @cID             NVARCHAR( 18),
   @cSKU            NVARCHAR( 20),
   @nQTY            INT,
   @cSuggestedLOC   NVARCHAR( 10),
   @cFinalLOC       NVARCHAR( 10),
   @cOption         NVARCHAR( 1),
   @cExtendedInfo1  NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cUserdefine01 NVARCHAR(20)
   DECLARE @cData NVARCHAR(20)
   DECLARE @nQtyOnID       INT = 0
   DECLARE @cItemClass     NVARCHAR( 10) = ''
   
   IF @nFunc = 523 -- Putaway by SKU
   BEGIN
   	IF @nAfterStep = 2
   	BEGIN
   		SELECT @nQtyOnID = ISNULL( SUM( Qty), 0)
   		FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
   		JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
   		WHERE LLI.StorerKey = @cStorerKey
   		AND   LLI.Loc = @cLOC
   		AND   LLI.Id = @cID
   		AND   LOC.Facility = @cFacility
   		
   		SET @cExtendedInfo1 = 'QTY ON ID: '+  CAST( @nQtyOnID AS NVARCHAR( 5))
   	END
   	
      IF @nAfterStep = 3  -- QTY PWY, QTY ACT
      BEGIN
         SELECT @cUserdefine01=userdefine01,
                @cData = data
         FROM SKUconfig (NOLOCK)
         WHERE SKU=@cSKU
            AND  storerkey=@cStorerKey

         SELECT @cItemClass = itemclass
         FROM dbo.SKU WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   Sku= @cSKU
         
         SET @cExtendedInfo1 = RTRIM( @cUserdefine01) + ' ' +  
                               RTRIM( @cData) + ' ' + 
                               @cItemClass
      END
   END

Quit:

END

GO
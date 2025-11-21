SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1819ExtInfo02                                   */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Purpose: Display final location                                      */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2020-08-14 1.0  Chermaine  WMS-14664 Created                         */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1819ExtInfo02] (
   @nMobile         INT,          
   @nFunc           INT,          
   @cLangCode       NVARCHAR( 3), 
   @nStep           INT,          
   @nAfterStep      INT, 
   @nInputKey       INT,          
   @cFromID         NVARCHAR( 18),
   @cSuggLOC        NVARCHAR( 10),
   @cPickAndDropLOC NVARCHAR( 10),
   @cToLOC          NVARCHAR( 10),
   @cExtendedInfo   NVARCHAR( 20) OUTPUT,
   @nErrNo          INT           OUTPUT,
   @cErrMsg         NVARCHAR( 20) OUTPUT
) AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @cSKU        NVARCHAR( 20)
   DECLARE @cStorerKey  NVARCHAR( 15)

   IF @nStep = 1 -- FromID
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         IF @cFromID <> ''
         
            SELECT 
               @cStorerKey = V_StorerKey               
            FROM rdt.RDTMOBREC WITH (NOLOCK)
            WHERE mobile = @nMobile
            
            SELECT TOP 1 @cSKU = LLI.SKU
            FROM LOTxLOCxID LLI WITH (NOLOCK)   
            JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)  
            WHERE LLI.StorerKey = @cStorerKey  
            AND LLI.ID = @cFromID  
            AND LLI.QTY -   
               (CASE WHEN rdt.rdtGetConfig( @nFunc, 'MoveQTYAlloc', LLI.StorerKey) = '0' THEN LLI.QTYAllocated ELSE 0 END) -   
               (CASE WHEN rdt.rdtGetConfig( @nFunc, 'MoveQTYPick', LLI.StorerKey) = '0' THEN LLI.QTYPicked ELSE 0 END) > 0 
            ORDER BY LLI.SKU
               
            SET @cExtendedInfo = @cSKU
      END
   END

GO
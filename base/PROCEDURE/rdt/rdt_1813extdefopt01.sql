SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_1813ExtDefOpt01                                 */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Purpose: Set the default option. Display shall be defaulted to       */
/*          whichever group has Most Qty                                */    
/*                                                                      */    
/* Called from: rdtfnc_PalletConsolidate                                */    
/*                                                                      */    
/* Exceed version: 5.4                                                  */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date        Rev  Author      Purposes                                */    
/* 22-06-2015  1.0  James       SOS315975 Created                       */   
/************************************************************************/    
    
CREATE PROCEDURE [RDT].[rdt_1813ExtDefOpt01]    
   @nMobile         INT,       
   @nFunc           INT,       
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,       
   @nInputKey       INT,       
   @cStorerKey      NVARCHAR( 15), 
   @cFromID         NVARCHAR( 20), 
   @cOption         NVARCHAR( 1), 
   @cSKU            NVARCHAR( 20), 
   @nQty            INT, 
   @cToID           NVARCHAR( 20), 
   @cDefaultOpt     NVARCHAR( 1) OUTPUT
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
   
   DECLARE @nQTY_Avail  INT, 
           @nQTY_Alloc  INT, 
           @nQTY_Pick   INT, 
           @cFacility   NVARCHAR( 5)

   SET @cDefaultOpt = ''
   SELECT @cFacility = Facility FROM RDT.RDTMOBREC WITH (NOLOCK) WHERE Mobile = @nMobile
   
   SELECT @nQTY_Avail = ISNULL( SUM( QTY - QTYAllocated - QTYPicked), 0),
            @nQTY_Alloc = ISNULL( SUM( QTYAllocated), 0),
            @nQTY_Pick = ISNULL( SUM( QTYPicked), 0)
   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
   JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
   WHERE LLI.StorerKey = @cStorerKey 
   AND   LLI.ID = @cFromID 
   AND   LOC.Facility = @cFacility
   AND   SKU = @cSKU

   IF @nQTY_Avail >= @nQTY_Alloc
   BEGIN
      IF @nQTY_Avail >= @nQTY_Pick
         SET @cDefaultOpt = '1'
      ELSE
         SET @cDefaultOpt = '3'
   END
   ELSE
   BEGIN
      IF @nQTY_Alloc >= @nQTY_Pick
         SET @cDefaultOpt = '2'
      ELSE
         SET @cDefaultOpt = '3'
   END

   QUIT:

END -- End Procedure    

GO
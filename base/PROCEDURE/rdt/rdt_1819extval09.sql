SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1819ExtVal09                                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Validate pallet id before putaway                           */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2020-05-12   James     1.0   WMS13070. Created                       */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1819ExtVal09]
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
   
   DECLARE @cFacility      NVARCHAR( 5)  
   DECLARE @cStorerKey     NVARCHAR( 15)
   DECLARE @nMaxSKU        INT
   DECLARE @nSKUCount      INT
   
   -- Change ID  
   IF @nFunc = 1819  
   BEGIN  
      IF @nStep = 2 -- To Loc  
      BEGIN  
         IF @nInputKey = 1 -- ENTER  
         BEGIN  
            -- Get Facility, Storer  
            SELECT @cFacility = Facility, 
                   @cStorerKey = StorerKey
            FROM rdt.rdtMobRec WITH (NOLOCK) 
            WHERE Mobile = @nMobile  

            SET @nMaxSKU = 0
            SELECT @nMaxSKU = MaxSKU
            FROM dbo.LOC WITH (NOLOCK)
            WHERE Loc = @cToLOC
            AND   Facility = @cFacility

            -- If MaxSKU setup only check
            IF @nMaxSKU > 0
            BEGIN
               IF OBJECT_ID('tempdb..#SKU') IS NOT NULL  
                  DROP TABLE #SKU

               CREATE TABLE #SKU  (  
                  RowRef      BIGINT IDENTITY(1,1)  Primary Key,  
                  SKU         NVARCHAR( 20))  

               INSERT INTO #SKU ( SKU)
               SELECT DISTINCT LLI.SKU
               FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
               JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
               WHERE LLI.Id = @cFromID
               AND   LOC.Facility = @cFacility
               GROUP BY LLI.SKU
               HAVING ISNULL( SUM( LLI.Qty - LLI.QtyPicked), 0) > 0
 
               INSERT INTO #SKU ( SKU)
               SELECT DISTINCT LLI.SKU
               FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
               JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
               WHERE LOC.LOC = @cToLOC
               AND   LOC.Facility = @cFacility
               GROUP BY LLI.SKU
               HAVING ISNULL( SUM( LLI.Qty - LLI.QtyPicked), 0) > 0

               SET @nSKUCount = 0
               SELECT @nSKUCount = COUNT( DISTINCT SKU)
               FROM #SKU

               -- Check if To Loc over Loc.MaxSKU
               IF @nSKUCount >  @nMaxSKU
               BEGIN  
                  SET @nErrNo = 151951  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pending Putaway  
                  GOTO Quit  
               END  
            END   -- IF @nMaxSKU > 0
         END
      END  
   END  

Quit:

END

GO
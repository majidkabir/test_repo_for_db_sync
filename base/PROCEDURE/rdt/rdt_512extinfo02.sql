SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_512ExtInfo02                                    */
/* Purpose: Move By LOC Extended Info                                   */
/*                                                                      */
/* Called from: rdtfnc_Move_LOC                                         */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 2020-04-29  1.0  James      WMS13071- Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_512ExtInfo02] (
   @nMobile          INT,
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3), 
   @nStep            INT, 
   @nInputKey        INT, 
   @cStorerKey       NVARCHAR( 15), 
   @cFromLOC         NVARCHAR( 10),
   @cToLOC           NVARCHAR( 10),
   @cToID            NVARCHAR( 18),
   @cSKU             NVARCHAR( 20),
   @cOption          NVARCHAR( 1), 
   @cExtendedInfo    NVARCHAR( 20) OUTPUT
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @cFromID     NVARCHAR( 18)
   DECLARE @cFacility   NVARCHAR( 5)
   DECLARE @cSuggLOC    NVARCHAR( 10)
   DECLARE @cPAStrategyKey    NVARCHAR(10)
   DECLARE @nErrNo      INT
   
   SELECT @cFacility = Facility 
   FROM rdt.RDTMOBREC WITH (NOLOCK) 
   WHERE Mobile = @nMobile
   
   IF @nStep IN ( 1, 2)
   BEGIN
      IF @nInputKey = 1
      BEGIN
         IF EXISTS ( SELECT 1 FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
                     WHERE LOC.Facility = @cFacility
                     AND   LOC.LOC = @cFromLOC
                     AND   LOC.LocationCategory = 'STAGE'
                     AND   (LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0
                     GROUP BY LLI.Loc
                     HAVING COUNT( DISTINCT SKU) = 1)
            SET @cPAStrategyKey = 'DSJPPA1'
         ELSE
            SET @cPAStrategyKey = 'DSJPPA2'
         
         -- 1 pallet 1 loc
         SELECT TOP 1 @cFromID = LLI.Id
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
         JOIN dbo.LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
         WHERE LLI.StorerKey = @cStorerKey
         AND   LLI.LOC = @cFromLOC
         AND   LLI.Sku = @cSKU
         AND  (LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0
         ORDER BY 1

         -- Suggest LOC  
         SET @nErrNo = 0
         EXEC @nErrNo = [dbo].[nspRDTPASTD]  
              @c_userid          = 'RDT'  
            , @c_storerkey       = @cStorerKey  
            , @c_lot             = ''  
            , @c_sku             = @cSKU  
            , @c_id              = @cFromID  
            , @c_fromloc         = @cFromLOC  
            , @n_qty             = 0  
            , @c_uom             = '' -- not used  
            , @c_packkey         = '' -- optional, if pass-in SKU  
            , @n_putawaycapacity = 0  
            , @c_final_toloc     = @cSuggLOC          OUTPUT  
            , @c_PAStrategyKey   = @cPAStrategyKey  

         IF @nErrNo <> 0
            SET @cExtendedInfo = 'NO SUGGEST LOC'
         ELSE
            SET @cExtendedInfo = 'SUGG LOC: ' + @cSuggLOC
            
      END
   END

QUIT:

GO
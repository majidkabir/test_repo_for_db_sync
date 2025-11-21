SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1797ExtPASP01                                   */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 01-10-2014  1.0  Ung      SOS322241. Created                         */
/* 27-02-2017  1.1  Ung      WMS-1143 Add Odd size cases                */
/************************************************************************/

CREATE PROC [RDT].[rdt_1797ExtPASP01] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @cStorerKey       NVARCHAR( 15),
   @cFromLOC         NVARCHAR( 10),
   @cFromID          NVARCHAR( 18),
   @cSuggToLOC       NVARCHAR( 10) OUTPUT,
   @cPickAndDropLOC  NVARCHAR( 10) OUTPUT,
   @cFitCasesInAisle NVARCHAR( 1)  OUTPUT,
   @nErrNo           INT           OUTPUT,
   @cErrMsg          NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cPalletType    NVARCHAR(30)
   DECLARE @cPAStrategyKey NVARCHAR(10)
   DECLARE @cNotes1        NVARCHAR(10)

   SET @cPalletType = ''
   SET @cPAStrategyKey = ''
   SET @cNotes1 = ''

   -- Get SKU notes1
   SELECT TOP 1 
      @cNotes1 = 'ODDSIZE'
   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
      JOIN dbo.SKU WITH (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
   WHERE LLI.LOC = @cFromLOC
      AND LLI.ID = @cFromID
      AND LLI.QTY - LLI.QTYPicked > 0
      AND CONVERT( NVARCHAR( 10), SKU.Notes1) = 'ODDSIZE'

   -- Check single SKU pallet
   IF EXISTS( SELECT 1  
      FROM dbo.UCC WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND LOC = @cFromLOC
         AND ID = @cFromID
         AND Status = '1'
      HAVING COUNT( DISTINCT SKU) = 1 
         AND COUNT( DISTINCT QTY) = 1)
   BEGIN         
      IF @cNotes1 = 'ODDSIZE'
         SET @cPalletType = 'OddSizeSKUPallet'
      ELSE
         SET @cPalletType = 'SingleSKUPallet'
   END
   
   -- Check if multi SKU pallet
   ELSE IF EXISTS( 
      SELECT 1 
      FROM dbo.UCC WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
         AND LOC = @cFromLOC   
         AND ID = @cFromID   
         AND UCC.Status = '1'  
      HAVING COUNT( DISTINCT UCC.SKU) > 1 -- Multi SKU on pallet  
         OR (COUNT( DISTINCT UCC.SKU) = 1 AND COUNT( DISTINCT QTY) > 1))  -- Same SKU diff QTY pallet
   AND NOT EXISTS( 
      SELECT 1   
      FROM dbo.UCC WITH (NOLOCK)   
      WHERE UCC.StorerKey = @cStorerKey
         AND UCC.LOC = @cFromLOC   
         AND UCC.ID = @cFromID   
         AND UCC.Status = '1'  
      GROUP BY UCCNo   
      HAVING COUNT( DISTINCT UCC.SKU) > 1) -- But not multi SKU UCC  
   BEGIN            
      IF @cNotes1 = 'ODDSIZE'
         SET @cPalletType = 'OddSizeSKUCases'
      ELSE
         SET @cPalletType = 'MultiSKUPallet'
   END
      
   -- Check if multi SKU UCC pallet
   ELSE IF EXISTS( 
      SELECT 1  
      FROM dbo.UCC WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey 
         AND UCC.LOC = @cFromLOC
         AND UCC.ID = @cFromID
         AND UCC.Status = '1'
      GROUP BY UCCNo
      HAVING COUNT( DISTINCT UCC.SKU) > 1)  -- Multi SKU UCC
   BEGIN
      SET @cPalletType = 'MultiSKUUCC'
   END
   
   -- Check putaway strategy
   IF @cPalletType = ''
   BEGIN
      SET @nErrNo = 50701
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Bad PalletType
      GOTO Quit
   END
   
   -- Get putaway strategy
   SELECT @cPAStrategyKey = ISNULL( Short, '')
   FROM CodeLkup WITH (NOLOCK)
   WHERE ListName = 'RDTExtPA'
      AND Code = @cPalletType
      AND StorerKey = @cStorerKey

   -- Check blank putaway strategy
   IF @cPAStrategyKey = ''
   BEGIN
      SET @nErrNo = 50702
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- StrategyNotSet
      GOTO Quit
   END

   -- Check putaway strategy valid
   IF NOT EXISTS( SELECT 1 FROM PutawayStrategy WITH (NOLOCK) WHERE PutawayStrategyKey = @cPAStrategyKey)
   BEGIN
      SET @nErrNo = 50703
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- BadStrategyKey
      GOTO Quit
   END
   
   -- Suggest LOC
   EXEC @nErrNo = [dbo].[nspRDTPASTD]
        @c_userid          = 'RDT'
      , @c_storerkey       = @cStorerKey
      , @c_lot             = ''
      , @c_sku             = ''
      , @c_id              = @cFromID
      , @c_fromloc         = @cFromLOC
      , @n_qty             = 0
      , @c_uom             = '' -- not used
      , @c_packkey         = '' -- optional, if pass-in SKU
      , @n_putawaycapacity = 0
      , @c_final_toloc     = @cSuggToLOC        OUTPUT
      , @c_PickAndDropLoc  = @cPickAndDropLOC   OUTPUT
      , @c_FitCasesInAisle = @cFitCasesInAisle  OUTPUT
      , @c_PAStrategyKey   = @cPAStrategyKey

Quit:

END

GO
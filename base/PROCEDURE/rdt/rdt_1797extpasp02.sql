SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1797ExtPASP02                                   */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 12-04-2017  1.0  Ung      WMS-1223 Created                           */
/************************************************************************/

CREATE PROC [RDT].[rdt_1797ExtPASP02] (
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

   SET @cPalletType = 'MultiSKUPallet'
   SET @cPAStrategyKey = ''
   
   -- Get putaway strategy
   SELECT @cPAStrategyKey = ISNULL( Short, '')
   FROM CodeLkup WITH (NOLOCK)
   WHERE ListName = 'RDTExtPA'
      AND Code = @cPalletType
      AND StorerKey = @cStorerKey

   -- Check blank putaway strategy
   IF @cPAStrategyKey = ''
   BEGIN
      SET @nErrNo = 107752
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- StrategyNotSet
      GOTO Quit
   END

   -- Check putaway strategy valid
   IF NOT EXISTS( SELECT 1 FROM PutawayStrategy WITH (NOLOCK) WHERE PutawayStrategyKey = @cPAStrategyKey)
   BEGIN
      SET @nErrNo = 107753
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
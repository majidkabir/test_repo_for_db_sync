SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_1804ExtUpd02                                    */
/* Purpose: Print pallet label                                          */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2017-03-24   Ung       1.0   WMS-1371 Created                        */
/************************************************************************/
CREATE PROCEDURE [RDT].[rdt_1804ExtUpd02]
    @nMobile         INT
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR( 3)
   ,@nStep           INT
   ,@cStorerKey      NVARCHAR( 15)
   ,@cFacility       NVARCHAR(  5)
   ,@cFromLOC        NVARCHAR( 10)
   ,@cFromID         NVARCHAR( 18)
   ,@cSKU            NVARCHAR( 20)
   ,@nQTY            INT
   ,@cUCC            NVARCHAR( 20)
   ,@cToID           NVARCHAR( 18)
   ,@cToLOC          NVARCHAR( 10)
   ,@nErrNo          INT           OUTPUT
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT

   -- Move To UCC
   IF @nFunc = 1804
   BEGIN
      IF @nStep = 8 -- Close Pallet
      BEGIN
         IF @cToID <> ''
         BEGIN
            -- Get login info
            DECLARE @cLabelPrinter NVARCHAR(10)
            SELECT @cLabelPrinter = Printer FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile

            IF @cLabelPrinter <> ''
            BEGIN
               -- Get report info
               DECLARE @cDataWindow   NVARCHAR( 50)
               DECLARE @cTargetDB     NVARCHAR( 20)
               SELECT
                  @cDataWindow = ISNULL( RTRIM( DataWindow), ''),
                  @cTargetDB = ISNULL( RTRIM( TargetDB), '')
               FROM RDT.RDTReport WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND ReportType = 'PALLETLbL3'

               IF @cDataWindow <> ''
               BEGIN
                  -- Insert print job
                  SET @nErrNo = 0
                  EXEC RDT.rdt_BuiltPrintJob
                     @nMobile,
                     @cStorerKey,
                     'PALLETLbL3',       --@cReportType
                     'Print_PALLETLbL3', --@cPrintJobName
                     @cDataWindow,
                     @cLabelPrinter,
                     @cTargetDB,
                     @cLangCode,
                     @nErrNo  OUTPUT,
                     @cErrMsg OUTPUT,
                     @cToID,
                     @cStorerKey
               END
            END
         END
      END
   END

Quit:

END

GO
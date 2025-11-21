SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_523ExtUpd01                                     */  
/* Copyright      : LF Logistics                                        */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2018-05-28 1.0  Ung        WMS-5183 Created                          */
/* 2018-08-13 1.1  James      Add param InputKey (james01)              */
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_523ExtUpd01] (  
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @nInputKey       INT, 
   @cStorerKey      NVARCHAR( 15),
   @cFacility       NVARCHAR( 5),
   @cID             NVARCHAR( 18),
   @cUCC            NVARCHAR( 20),
   @cLOC            NVARCHAR( 10),
   @cSuggestSKU     NVARCHAR( 20),
   @cSKU            NVARCHAR( 20),
   @nQTY            INT,
   @cSuggestedLOC   NVARCHAR( 10),
   @cFinalLOC       NVARCHAR( 10),
   @nErrNo          INT           OUTPUT,
   @cErrMsg         NVARCHAR( 20) OUTPUT
)  
AS  
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    

   SET @nErrNo = 0
   SET @cErrMsg = ''    

   IF @nFunc = 523 -- Putaway by SKU
   BEGIN
      IF @nStep = 4  -- Suggest LOC, final LOC
      BEGIN
         -- IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Get storer config
            DECLARE @cPutawayLabel NVARCHAR(10)
            SET @cPutawayLabel = rdt.RDTGetConfig( @nFunc, 'PutawayLabel', @cStorerKey)
            IF @cPutawayLabel = '0'
               SET @cPutawayLabel = ''
            
            -- Ship label
            IF @cPutawayLabel <> '' 
            BEGIN
               -- Get session info
               DECLARE @cLabelPrinter NVARCHAR(10)
               DECLARE @cPaperPrinter NVARCHAR(10)
               SELECT
                  @cLabelPrinter = Printer, 
                  @cPaperPrinter = Printer_Paper
               FROM rdt.rdtMobRec WITH (NOLOCK) 
               WHERE Mobile = @nMobile
               
               -- Common params
               DECLARE @tPutawayLabel AS VariableTable
               INSERT INTO @tPutawayLabel (Variable, Value) VALUES 
                  ( '@cStorerKey',  @cStorerKey), 
                  ( '@cFacility',   @cFacility), 
                  ( '@cID',         @cID), 
                  ( '@cUCC',        @cUCC), 
                  ( '@cLOC',        @cLOC), 
                  ( '@cSKU',        @cSKU), 
                  ( '@nQTY',        CAST( @nQTY AS NVARCHAR(10))), 
                  ( '@cFinalLOC',   @cFinalLOC)

               -- Print label
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, 1, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter, 
                  @cPutawayLabel, -- Report type
                  @tPutawayLabel, -- Report params
                  'rdt_523ExtUpdSP01', 
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT
               
               SET @nErrNo = 0
               -- IF @nErrNo <> 0
               --   GOTO Quit
            END
         END
      END
   END
   
Quit:  
 

GO
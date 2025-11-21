SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_653ExtVal01                                     */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Ad-hoc check LOC integrity                                  */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 03-Aug-2016 1.0  Ung        WMS-20334 Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_653ExtVal01] (
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @nInputKey       INT,
   @cFacility       NVARCHAR( 5),
   @cStorerKey      NVARCHAR( 15),
   @cLOC            NVARCHAR( 10),
   @cSKU            NVARCHAR( 20),
   @nQTYScan        INT,
   @tVar            VariableTable  READONLY,
   @nErrNo          INT            OUTPUT,
   @cErrMsg         NVARCHAR( 20)  OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 653 -- Audit LOC
   BEGIN
      IF @nStep = 1 -- LOC
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF EXISTS( SELECT 1
               FROM dbo.TaskDetail WITH (NOLOCK)
               WHERE Status < '9' 
                  AND FromLOC = @cLOC)
            BEGIN
               SET @nErrNo = 192301
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOC InProcess
               GOTO Quit
            END
         END
      END
      
      IF @nStep = 2 -- SKU
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Get QTY avail
            DECLARE @nQTYAvail INT = 0
            SELECT @nQTYAvail = QTY - QTYPicked
            FROM dbo.SKUxLOC WITH (NOLOCK)
            WHERE LOC = @cLOC
               AND SKU = @cSKU

            -- Get QTY scanned
            SET @nQTYScan = 0
            SELECT @nQTYScan = QTY
            FROM rdt.rdtAuditLOCLog WITH (NOLOCK)
            WHERE LOC = @cLOC
               AND SKU = @cSKU
            
            -- SKU over
            IF (@nQTYScan + 1) > @nQTYAvail 
            BEGIN
               DECLARE @cMsg NVARCHAR(20) 
               SET @cMsg = rdt.rdtgetmessage( 192302, @cLangCode, 'DSP') --SKU Over
               EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', '', @cMsg
               GOTO Quit
            END
         END
      END
   END
   
Quit:


GO
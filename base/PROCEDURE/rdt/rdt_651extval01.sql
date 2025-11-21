SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_651ExtVal01                                     */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2022-07-28 1.0  Ung      WMS-20345 Created                           */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_651ExtVal01] (
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @nInputKey       INT,
   @cStorerKey      NVARCHAR( 15),
   @cFacility       NVARCHAR(  5),
   @cFromLOC        NVARCHAR( 10),
   @cRefNo          NVARCHAR( 20),
   @nQTY            INT,
   @cToID           NVARCHAR( 18),
   @cToLOC          NVARCHAR( 10),
   @tExtVal         VariableTable READONLY, 
   @nErrNo          INT           OUTPUT,
   @cErrMsg         NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 651 -- Move prepack carton
   BEGIN
      IF @nStep = 2 -- RefNo
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Get one of the order (with the prepack code)
            IF NOT EXISTS( SELECT TOP 1 1
               FROM dbo.Orders WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND Notes2 = @cRefNo)
            BEGIN
               SET @nErrNo = 188951
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid RefNo
               GOTO Quit
            END
         END
      END
      
      IF @nStep = 3 -- QTY
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            DECLARE @cOrderKey      NVARCHAR( 10)
            DECLARE @cSKU           NVARCHAR( 20)
            DECLARE @nOriginalQTY   INT
            DECLARE @nQTYAvail      INT

            -- Get one of the order (with the prepack code)
            SELECT TOP 1 
               @cOrderKey = OrderKey
            FROM dbo.Orders WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND Notes2 = @cRefNo

            -- Check the content
            DECLARE @curContent CURSOR
            SET @curContent = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT SKU, SUM( OriginalQTY)
               FROM dbo.OrderDetail WITH (NOLOCK)
               WHERE OrderKey = @cOrderKey
               GROUP BY SKU
            OPEN @curContent
            FETCH NEXT FROM @curContent INTO @cSKU, @nOriginalQTY
            WHILE @@FETCH_STATUS = 0
            BEGIN
               -- Get QTY available 
               SELECT @nQTYAvail = ISNULL( SUM( QTY-QTYAllocated-QTYPicked), 0)
               FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
               WHERE LOC = @cFromLOC
                  AND StorerKey = @cStorerKey
                  AND SKU = @cSKU
               
               -- Check QTY enough
               IF @nQTYAvail < (@nOriginalQTY * @nQTY)
               BEGIN
                  SET @nErrNo = 188952
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QTY NotEnuf
                  GOTO Quit
               END
               
               FETCH NEXT FROM @curContent INTO @cSKU, @nOriginalQTY
            END
         END
      END
   END

 Quit:

END

GO
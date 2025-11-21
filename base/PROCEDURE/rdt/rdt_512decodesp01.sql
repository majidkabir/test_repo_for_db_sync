SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/******************************************************************************/
/* Store procedure: rdt_512DecodeSP01                                        */
/* Copyright: Maersk                                                          */
/*                                                                            */
/* Purpose: Decode for PMI case                                               */
/*                                                                            */
/* Date        Author   Ver.  Purposes                                        */
/* 2024-10-17  XLL045   1.0   FCR-759 ID and UCC Length Issue                 */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_512DecodeSP01] ( 
  @nMobile      INT,               
  @nFunc        INT,               
  @cLangCode    NVARCHAR( 3),      
  @nStep        INT,               
  @nInputKey    INT,               
  @cStorerKey   NVARCHAR( 15),        
  @cBarcode     NVARCHAR( 60),
--   @cSKU         NVARCHAR( 20)  OUTPUT,
--   @nQTY         INT            OUTPUT,
  @cToID		    NVARCHAR( 18)  OUTPUT,
  @cFromLOC     NVARCHAR( 10)  OUTPUT,
  @cToLOC       NVARCHAR( 10)  OUTPUT,
  @nErrNo       INT            OUTPUT,
  @cErrMsg      NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @nStep_LOC     INT
   DECLARE  @cID           NVARCHAR(18)

   SET @nStep_LOC       = 2

   IF @nFunc = 512

   BEGIN
      IF @nStep = @nStep_LOC
      BEGIN
         IF @nInputKey = 1
         BEGIN
            IF @cBarcode <> ''
            BEGIN
               IF LEN(LTRIM(RTRIM(@cBarcode))) = 18
               BEGIN
                  SET @cToID = LTRIM(RTRIM(@cBarcode))
                  GOTO Quit
               END
               
               IF LEN(LTRIM(RTRIM(@cBarcode))) <> 25
               BEGIN
                  SET @nErrNo =  226401
                  SET @cErrMsg = [rdt].[rdtgetmessage]( @nErrNo, @cLangCode, N'DSP') -- Invalid ID(25 digit)
                  GOTO Quit
               END
               
               SET @cToID = RIGHT(LTRIM(RTRIM(@cBarcode)), 18)
             
               GOTO Quit
            END
         END
      END
   END

   Quit:

END
GO
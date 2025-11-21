SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/******************************************************************************/
/* Store procedure: rdt_521Decode01                                           */
/* Copyright: Maersk                                                          */
/*                                                                            */
/* Purpose: Decode For PMI case                                               */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 2024-10-17  ShaoAn    1.0   FCR-759 ID and UCC Length Issue                */
/******************************************************************************/
CREATE   PROC [RDT].[rdt_521Decode01] (
    @nMobile            INT
   ,@nFunc              INT
   ,@cLangCode          NVARCHAR(3)
   ,@nStep              INT
   ,@nInputKey          INT
   ,@cStorerKey         NVARCHAR( 15)
   ,@cFacility          NVARCHAR( 20)
   ,@cBarcode           NVARCHAR( 60)
   ,@cUCCNo             NVARCHAR( 60) OUTPUT
   ,@nErrNo             INT OUTPUT
   ,@cErrMsg            NVARCHAR(20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 521 -- UCC
      BEGIN
         IF @nStep = 1 --UCC
         BEGIN
            IF @nInputKey = 1 -- ENTER
            BEGIN
              IF LEN(@cBarcode) <> 40
              BEGIN
                  SET @nErrNo = 226551
                  SET @cErrMsg = [rdt].[rdtgetmessage]( @nErrNo, @cLangCode, N'DSP') -- Invalid UCC(40 digit)
                  GOTO Quit
              END
              SET @cUCCNo = RIGHT(@cBarcode, 20)
              GOTO Quit
            END
         END
      END

   Quit:
END


GO
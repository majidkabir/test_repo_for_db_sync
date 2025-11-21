SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/******************************************************************************/
/* Store procedure: rdt_553Decode01                                          */
/* Copyright: Maersk                                                          */
/*                                                                            */
/* Purpose: Decode PMI GS1 ID/UCC Label                                       */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 08-10-2024  CYU027    1.0   Created                                        */
/******************************************************************************/
CREATE   PROC [RDT].[rdt_553Decode01] (
    @nMobile            INT
   ,@nFunc              INT
   ,@cLangCode          NVARCHAR(3)
   ,@nStep              INT
   ,@nInputKey          INT
   ,@cStorerKey         NVARCHAR(15)
   ,@cIDBarcode         NVARCHAR(2000) OUTPUT
   ,@cUserDefine08      NVARCHAR(30) OUTPUT
   ,@cUserDefine09      NVARCHAR(30) OUTPUT
   ,@nErrNo             INT OUTPUT
   ,@cErrMsg            NVARCHAR(20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cLocalUCC AS NVARCHAR(20)
   DECLARE @cID AS NVARCHAR(18)

   IF @nFunc = 553 -- UCC receiving
      BEGIN
         IF @nStep = 2 -- ToID
         BEGIN
            IF @nInputKey = 1 -- ENTER
            BEGIN
               IF @cIDBarcode <> '' --Barcode
               BEGIN
                  IF LEN( RTRIM( @cIDBarcode)) < 25
                  BEGIN
                     SET @nErrNo = 227051
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Required SSCC
                     GOTO Quit
                  END

                  SET @cID = SUBSTRING( @cIDBarcode, 8, 25)
                  SET @cUserDefine08 = SUBSTRING( @cIDBarcode,1 ,7)
                  SET @cIDBarcode = @cID

                  GOTO Quit
               END
            END
         END

         IF @nStep = 3 -- UCC
         BEGIN
            IF @nInputKey = 1 -- ENTER
            BEGIN
               IF @cIDBarcode <> ''
               BEGIN
                  IF LEN( rtrim( @cIDBarcode)) < 40
                  BEGIN
                     SET @nErrNo = 227052
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Required SSCC
                     GOTO Quit
                  END

                  SET @cLocalUCC = SUBSTRING( @cIDBarcode, 21, 40)
                  SET @cUserDefine09 = SUBSTRING( @cIDBarcode,1 ,20)
                  SET @cIDBarcode = @cLocalUCC

                  GOTO Quit
               END
            END
         END
      END

   Quit:
END

GO
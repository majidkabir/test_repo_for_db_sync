SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/******************************************************************************/
/* Store procedure: rdt_523Decode01                                           */
/* Copyright: Maersk                                                          */
/*                                                                            */
/* Purpose: Decode For PMI case                                               */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 2024-10-22  ShaoAn    1.0   FCR-759-999 ID and UCC Length Issue            */
/******************************************************************************/
CREATE   PROC [RDT].[rdt_523Decode01] (
    @nMobile            INT
   ,@nFunc              INT
   ,@cLangCode          NVARCHAR( 3)
   ,@nStep              INT
   ,@nInputKey          INT
   ,@cStorerKey         NVARCHAR( 15)
   ,@cFacility          NVARCHAR( 20)
   ,@c_ID               NVARCHAR( 60)
   ,@c_UCC              NVARCHAR( 60)
   ,@cID                NVARCHAR( 60) OUTPUT
   ,@cUCC               NVARCHAR( 60) OUTPUT
   ,@nErrNo             INT           OUTPUT
   ,@cErrMsg            NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 523 -- UCC
   BEGIN
      IF @nStep = 1 --UCC
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- ID  Decode
            If @c_ID <> ''
            BEGIN
               IF LEN(@c_ID) = 18
               BEGIN
                  SET @cID = @c_ID
               END
               ELSE
               BEGIN
                  IF LEN(@c_ID) <> 25
                  BEGIN
                     SET @nErrNo = 227101
                     SET @cErrMsg = [rdt].[rdtgetmessage]( @nErrNo, @cLangCode, N'DSP') -- Invalid ID(25 digit)
                     GOTO Quit
                  END
                  SET @cID = RIGHT(@c_ID, 18)
               END
            END

            IF @c_UCC <> ''
            BEGIN
               IF LEN(@c_UCC) = 20
               BEGIN
                  SET @cUCC = @c_UCC
                  GOTO Quit
               END

               IF LEN(@c_UCC) <> 40
               BEGIN
                  SET @nErrNo = 227102
                  SET @cErrMsg = [rdt].[rdtgetmessage]( @nErrNo, @cLangCode, N'DSP') -- Invalid UCC(40 digit)
                  SET @cUCC = LEFT(@c_UCC, 20)
                  GOTO Quit
               END
               SET @cUCC = RIGHT(@c_UCC, 20)
               GOTO Quit
            END
         END
      END
   END

   Quit:
END


GO
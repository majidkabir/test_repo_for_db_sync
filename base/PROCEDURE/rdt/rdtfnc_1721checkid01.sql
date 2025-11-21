SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_1721CheckID01                                */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Called from: rdtfnc_Pallet_Move                                      */
/*                                                                      */
/* Purpose: Check ID                                                    */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author   Purposes                                   */
/* 2024-07-16  1.0  CYU027   FCR-575                                    */
/************************************************************************/

CREATE   PROC [RDT].[rdtfnc_1721CheckID01] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cID            NVARCHAR( 40),
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
) AS
BEGIN

   DECLARE    @cStatus          NVARCHAR( 10)

   -- Check blank ID
   IF @cID = ''
   BEGIN
      SET @nErrNo = 219301
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need ID
      GOTO Quit
   END

   -- Get ID info
   SET @cStatus = ''
   SELECT @cStatus = Status
   FROM dbo.PalletDetail WITH (NOLOCK)
   WHERE Palletkey = @cID
   AND storerkey = @cStorerKey

   -- Check valid ID
   IF @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = 219302
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid ID
      GOTO Quit
   END

   -- Check if ID shipped
   IF @cStatus = '9'
   BEGIN
      SET @nErrNo = 219303
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ID had shipped
      GOTO Quit
   END


   Quit:


END

GO
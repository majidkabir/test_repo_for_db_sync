SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_Pallet_Move_check_ID                         */
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

CREATE   PROC [RDT].[rdtfnc_Pallet_Move_check_ID] (
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

   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL           NVARCHAR( MAX)
   DECLARE @cSQLParam      NVARCHAR( MAX)
   DECLARE @cPalletMoveCheckID NVARCHAR( 20)

   -- Get storer config
   SET @cPalletMoveCheckID= rdt.RDTGetConfig( @nFunc, 'PalletMoveCheckID', @cStorerKey)
   IF @cPalletMoveCheckID= '0'
      SET @cPalletMoveCheckID= ''

   /***********************************************************************************************
                                              Custom Check ID
   ***********************************************************************************************/
   DECLARE    @cStatus          NVARCHAR( 10)
   DECLARE    @cLOC             NVARCHAR( 10)

      -- Check confirm SP blank
   IF @cPalletMoveCheckID<> ''
      BEGIN
         -- Confirm SP
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cPalletMoveCheckID) +
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cID,' +
                     ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam =
                 ' @nMobile        INT,           ' +
                 ' @nFunc          INT,           ' +
                 ' @cLangCode      NVARCHAR( 3),  ' +
                 ' @nStep          INT,           ' +
                 ' @nInputKey      INT,           ' +
                 ' @cFacility      NVARCHAR( 5) , ' +
                 ' @cStorerKey     NVARCHAR( 15), ' +
                 ' @cID            NVARCHAR( 40), ' +
                 ' @nErrNo         INT           OUTPUT, ' +
                 ' @cErrMsg        NVARCHAR(250) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
              @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cID,
              @nErrNo OUTPUT, @cErrMsg OUTPUT

         GOTO Quit
      END

   /***********************************************************************************************
                                              Standard Check ID
   ***********************************************************************************************/

   -- Check blank ID
   IF @cID = ''
   BEGIN
      SET @nErrNo = 78401
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need ID
      GOTO Quit
   END

   -- Get ID info
   SET @cStatus = ''
   SET @cLOC = ''
   SELECT @cLOC = DropLOC,
          @cStatus = Status
   FROM dbo.DropID WITH (NOLOCK)
   WHERE DropID = @cID

   -- Check valid ID
   IF @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = 78402
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid ID
      GOTO Quit
   END

   -- Check if ID shipped
   IF @cStatus = '9'
   BEGIN
      SET @nErrNo = 78403
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ID had shipped
      GOTO Quit
   END


   Quit:
END

GO
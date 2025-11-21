SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_Pallet_Move_update_ID                         */
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

CREATE   PROC [RDT].[rdtfnc_Pallet_Move_update_ID] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cID            NVARCHAR( 40),
   @cToLOC         NVARCHAR( 40),
   @cLocationCategory VARCHAR( 10),
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
   DECLARE @cPalletMoveUpdateID NVARCHAR( 30)

   -- Get storer config
   SET @cPalletMoveUpdateID= rdt.RDTGetConfig( @nFunc, 'PalletMoveUpdateID', @cStorerKey)
   IF @cPalletMoveUpdateID= '0'
      SET @cPalletMoveUpdateID= ''

   /***********************************************************************************************
                                              Custom Update ID
   ***********************************************************************************************/

   IF @cPalletMoveUpdateID<> ''
   BEGIN
      SET @cSQL = 'EXEC rdt.' + RTRIM( @cPalletMoveUpdateID) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cID, @cToLOC, @cLocationCategory, ' +
                  ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
      SET @cSQLParam =
              ' @nMobile            INT,           ' +
              ' @nFunc              INT,           ' +
              ' @cLangCode          NVARCHAR( 3),  ' +
              ' @nStep              INT,           ' +
              ' @nInputKey          INT,           ' +
              ' @cFacility          NVARCHAR( 5) , ' +
              ' @cStorerKey         NVARCHAR( 15), ' +
              ' @cID                NVARCHAR( 40), ' +
              ' @cToLOC             NVARCHAR( 40), ' +
              ' @cLocationCategory  VARCHAR( 10),  ' +
              ' @nErrNo         INT           OUTPUT, ' +
              ' @cErrMsg        NVARCHAR(250) OUTPUT  '

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
           @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cID, @cToLOC, @cLocationCategory,
           @nErrNo OUTPUT, @cErrMsg OUTPUT

      GOTO Quit
   END

   /***********************************************************************************************
                                              Standard Update ID
   ***********************************************************************************************/
   DECLARE    @cDropID_Status   NVARCHAR( 10)
   DECLARE    @nTranCount       INT


   -- Get DropID status from Codelkup table because
   -- user can move pallet anywhere. Location type determine
   -- DropID status
   SELECT @cDropID_Status = ISNULL(Short, '')
   FROM dbo.CodeLkUp WITH (NOLOCK)
   WHERE ListName = 'DROPIDSTAT'
     AND   CODE = @cLocationCategory

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN UPD_DROPID

   -- Update DropID
   -- If Codelkup is not setup then use existing DropID status
   UPDATE DropID WITH (ROWLOCK) SET
     [Status] = CASE WHEN ISNULL(@cDropID_Status, '') = '' THEN [Status] ELSE @cDropID_Status END,
     DropLOC = @cToLOC,
     EditWho = 'rdt.' + sUser_sName(),
     EditDate = GETDATE()
   WHERE DropID = @cID

   IF @@ERROR <> 0
   BEGIN
      ROLLBACK TRAN UPD_DROPID
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN UPD_DROPID

      SET @nErrNo = 78407
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Upd toloc fail
      GOTO Quit
   END

   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN UPD_DROPID

   Quit:
END

GO
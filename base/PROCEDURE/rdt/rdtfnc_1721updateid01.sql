SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_1721UpdateID01                                */
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

CREATE   PROC [RDT].[rdtfnc_1721UpdateID01] (
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
   DECLARE    @cDropID_Status   NVARCHAR( 10)
   DECLARE    @nTranCount       INT


   -- Get DropID status from Codelkup table because
   -- user can move pallet anywhere. Location type determine
   -- DropID status
   SELECT @cDropID_Status = ISNULL(Code, '0')
   FROM dbo.CodeLkUp WITH (NOLOCK)
   WHERE ListName = 'SHIPSTATUS'
     AND   Short = @cLocationCategory

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN UPD_DROPID

   -- Update DropID
   -- If Codelkup is not setup then use existing DropID status
   UPDATE PalletDetail WITH (ROWLOCK) SET
        [Status] = CASE WHEN ISNULL(@cDropID_Status, '') = '' THEN [Status] ELSE @cDropID_Status END,
        LOC = @cToLOC,
        EditWho = 'rdt.' + sUser_sName(),
        EditDate = GETDATE()
   WHERE PalletKey = @cID

   IF @@ERROR <> 0
   BEGIN
      ROLLBACK TRAN UPD_DROPID
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN UPD_DROPID

      SET @nErrNo = 219304
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Upd PalletDetail fail
      GOTO Quit
   END

   UPDATE LOTxLOCxID WITH (ROWLOCK) SET
      Loc = @cToLOC,
      EditWho = SUSER_SNAME(),
      EditDate = GETDATE()
   WHERE ID = @cID AND StorerKey = @cStorerKey

   IF @@ERROR <> 0
   BEGIN
      ROLLBACK TRAN UPD_DROPID
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN UPD_DROPID

      SET @nErrNo = 219305
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Upd LOTxLOCxID fail
      GOTO Quit
   END


   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN UPD_DROPID

   Quit:


END

GO
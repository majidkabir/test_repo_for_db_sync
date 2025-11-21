SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_EcomReturn_Finalize                                */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Date       Rev  Author  Purposes                                        */
/* 2019-11-14 1.0  James   WMS-10952. Created                              */
/* 2019-12-10 1.1  Ung     WMS-10952 Fix Receipt.Status                    */
/* 2020-07-29 1.2  Ung     WMS-13555 Change params                         */
/*                         Add FinalizeSP                                  */
/*                         Add Exceed finalize logic (default)             */
/* 2020-09-03 1.3  Ung     WMS-14617 Remove save tran. Some Exceed post    */
/*                         finalize involve cross DB tran                  */
/* 2021-04-15 1.4  James   WMS-16668 Add RefNo param (james01)             */
/* 2021-02-18 1.5  Ung     WMS-15663 Remove tran, as some POST finalize SP */
/*                         rollback all                                    */
/***************************************************************************/
CREATE PROC [RDT].[rdt_EcomReturn_Finalize](
   @nFunc         INT,
   @nMobile       INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5),
   @cStorerKey    NVARCHAR( 15),
   @cReceiptKey   NVARCHAR( 10),
   @cRefNo        NVARCHAR( 20),
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT

) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount  INT
   DECLARE @cSQL        NVARCHAR( MAX)
   DECLARE @cSQLParam   NVARCHAR( MAX)
   DECLARE @cFinalizeSP NVARCHAR( 30)

   SET @nTranCount = @@TRANCOUNT   

   -- Get storer configure
   SET @cFinalizeSP = rdt.RDTGetConfig( @nFunc, 'FinalizeSP', @cStorerKey)
   IF @cFinalizeSP = '0'
      SET @cFinalizeSP = ''

   /***********************************************************************************************
                                              Custom finalize
   ***********************************************************************************************/
   IF @cFinalizeSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cFinalizeSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cFinalizeSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
            ' @cReceiptKey, @cRefNo, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            
         SET @cSQLParam =
            '@nMobile       INT,           ' +
            '@nFunc         INT,           ' +
            '@cLangCode     NVARCHAR( 3),  ' +
            '@nStep         INT,           ' +
            '@nInputKey     INT,           ' +
            '@cFacility     NVARCHAR( 5),  ' +
            '@cStorerKey    NVARCHAR( 15), ' +
            '@cReceiptKey    NVARCHAR( 10),  ' +
            '@cRefNo        NVARCHAR( 20),  ' +
            '@nErrNo         INT           OUTPUT, ' +
            '@cErrMsg        NVARCHAR( 20) OUTPUT  '
            
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
            @cReceiptKey, @cRefNo, @nErrNo OUTPUT, @cErrMsg OUTPUT 

         GOTO Quit
      END
   END

   /***********************************************************************************************
                                            Standard finalize
   ***********************************************************************************************/
   -- Cross DB trans will hit "Cannot promote the transaction to a distributed transaction because there is an active save point in this transaction."
   -- BEGIN TRAN
   -- SAVE TRAN rdt_EcomReturn_Finalize

   DECLARE @bSuccess INT
   EXEC ispFinalizeReceipt
      @c_ReceiptKey = @cReceiptKey, 
      @b_Success    = @bSuccess OUTPUT, 
      @n_err        = @nErrNo   OUTPUT, 
      @c_ErrMsg     = @cErrMsg  OUTPUT
   IF @bSuccess = 0
   BEGIN
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
      -- GOTO RollBackTran
   END
   
   -- COMMIT TRAN rdt_EcomReturn_Finalize
   GOTO Quit

-- RollBackTran:
--    ROLLBACK TRAN -- rdt_EcomReturn_Finalize -- Only rollback change made here
Quit:
--    WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
--       COMMIT TRAN
END

GO
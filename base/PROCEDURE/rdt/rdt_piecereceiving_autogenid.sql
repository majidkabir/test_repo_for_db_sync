SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_PieceReceiving_AutoGenID                        */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Auto generate ID                                            */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 30-04-2013  1.0  Ung         SOS273208. Created                      */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_PieceReceiving_AutoGenID]
   @nMobile     INT, 
   @nFunc       INT, 
   @nStep       INT, 
   @cLangCode   NVARCHAR( 3), 
   @cAutoGenID  NVARCHAR(20),
   @cReceiptKey NVARCHAR(10), 
   @cPOKey      NVARCHAR(10), 
   @cLOC        NVARCHAR(10),
   @cID         NVARCHAR(18), 
   @cOption     NVARCHAR( 1),
   @cAutoID     NVARCHAR(18)  OUTPUT,   
   @nErrNo      INT           OUTPUT, 
   @cErrMsg     NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   SET @cAutoID = ''

   IF @cAutoGenID = '1'
   BEGIN
      DECLARE @b_success INT
      SET @b_success = 0
      EXECUTE dbo.nspg_GetKey
         'ID',
         10 ,
         @cAutoID    OUTPUT,
         @b_success  OUTPUT,
         @nErrNo     OUTPUT,
         @cErrMsg    OUTPUT
      IF @b_success <> 1
      BEGIN
         SET @nErrNo = 64265
         SET @cErrMsg = rdt.rdtgetmessage( 64265, @cLangCode, 'DSP') --GetAutoID Fail
         GOTO Fail
      END
   END
   ELSE
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cAutoGenID AND type = 'P')
      BEGIN
         DECLARE @cSQL NVARCHAR(1000)
         DECLARE @cSQLParam NVARCHAR(1000)

         SET @cSQL = 'EXEC rdt.' + RTRIM( @cAutoGenID) + ' @nMobile, @nFunc, @nStep, @cLangCode, ' + 
            '@cReceiptKey, @cPOKey, @cLOC, @cID, @cOption, @cAutoID OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
         SET @cSQLParam =
            '@nMobile     INT,           ' +
            '@nFunc       INT,           ' +
            '@nStep       INT,           ' +
            '@cLangCode   NVARCHAR( 3),  ' +
            '@cReceiptKey NVARCHAR( 10), ' +
            '@cPOKey      NVARCHAR( 10), ' +
            '@cLOC        NVARCHAR( 10), ' +
            '@cID         NVARCHAR( 18), ' +
            '@cOption     NVARCHAR( 1),  ' + 
            '@cAutoID     NVARCHAR( 18) OUTPUT, ' +
            '@nErrNo      INT           OUTPUT, ' + 
            '@cErrMsg     NVARCHAR( 20) OUTPUT'
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @nMobile, @nFunc, @nStep, @cLangCode
            ,@cReceiptKey
            ,@cPOKey
            ,@cLOC
            ,@cID
            ,@cOption
            ,@cAutoID  OUTPUT
            ,@nErrNo   OUTPUT
            ,@cErrMsg  OUTPUT
      END
   END

Fail:
END


GO
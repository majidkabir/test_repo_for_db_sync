SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_1804AutoGenID01                                 */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Auto generate ID                                            */
/*                                                                      */
/* Date        Rev  Author    Purposes                                  */
/* 2017-03-24  1.0  Ung       WMS-1371 Created                          */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1804AutoGenID01]
   @nMobile     INT, 
   @nFunc       INT, 
   @nStep       INT, 
   @nInputKey   INT, 
   @cLangCode   NVARCHAR( 3), 
   @cStorerKey  NVARCHAR(15),
   @cFacility   NVARCHAR(5), 
   @cAutoGenID  NVARCHAR(20),
   @cFromLOC    NVARCHAR(10),
   @cFromID     NVARCHAR(18),
   @cSKU        NVARCHAR(20),
   @nQTY        INT,
   @cUCC        NVARCHAR(20),
   @cToID       NVARCHAR(18),
   @cToLOC      NVARCHAR(10),
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
      SET @nErrNo = 107401
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetAutoID Fail
      GOTO Fail
   END

   SET @cAutoID = 'ID' + @cAutoID

Fail:
END


GO
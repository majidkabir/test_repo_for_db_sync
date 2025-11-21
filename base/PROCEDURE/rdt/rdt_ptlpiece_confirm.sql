SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_PTLPiece_Confirm                                */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 26-04-2016 1.0  Ung         SOS368861 Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_PTLPiece_Confirm] (
    @nMobile      INT
   ,@nFunc        INT
   ,@cLangCode    NVARCHAR( 3)
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cFacility    NVARCHAR( 5)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cLight       NVARCHAR( 1)
   ,@cStation     NVARCHAR( 10)
   ,@cMethod      NVARCHAR( 1) 
   ,@cSKU         NVARCHAR( 20)
   ,@cIPAddress   NVARCHAR( 40) OUTPUT
   ,@cPosition    NVARCHAR( 10) OUTPUT
   ,@nErrNo       INT           OUTPUT
   ,@cErrMsg      NVARCHAR(250) OUTPUT
   ,@cResult01    NVARCHAR( 20) OUTPUT
   ,@cResult02    NVARCHAR( 20) OUTPUT
   ,@cResult03    NVARCHAR( 20) OUTPUT
   ,@cResult04    NVARCHAR( 20) OUTPUT
   ,@cResult05    NVARCHAR( 20) OUTPUT
   ,@cResult06    NVARCHAR( 20) OUTPUT
   ,@cResult07    NVARCHAR( 20) OUTPUT
   ,@cResult08    NVARCHAR( 20) OUTPUT
   ,@cResult09    NVARCHAR( 20) OUTPUT
   ,@cResult10    NVARCHAR( 20) OUTPUT
)               
AS              
BEGIN           
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
                
   DECLARE @cSQL      NVARCHAR( MAX)
   DECLARE @cSQLParam NVARCHAR( MAX)
   
   -- Get method info
   DECLARE @cConfirmSP SYSNAME
   SET @cConfirmSP = ''
   SELECT @cConfirmSP = ISNULL( UDF02, '')
   FROM CodeLKUP WITH (NOLOCK)
   WHERE ListName = 'PTLPiece'
      AND Code = @cMethod
      AND StorerKey = @cStorerKey

   -- Check confirm SP blank
   IF @cConfirmSP = ''
   BEGIN
      SET @nErrNo = 99601
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SetupConfirmSP
      GOTO Quit
   END

   -- Check confirm SP valid
   IF NOT EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cConfirmSP AND type = 'P')
   BEGIN
      SET @nErrNo = 99602
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Confirm SP
      GOTO Quit
   END

   -- Confirm SP
   SET @cSQL = 'EXEC rdt.' + RTRIM( @cConfirmSP) +
      ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLight, ' +
      ' @cStation, @cMethod, @cSKU, @cIPAddress OUTPUT, @cPosition OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT, ' + 
      ' @cResult01 OUTPUT, @cResult02 OUTPUT, @cResult03 OUTPUT, @cResult04 OUTPUT, @cResult05 OUTPUT, ' +
      ' @cResult06 OUTPUT, @cResult07 OUTPUT, @cResult08 OUTPUT, @cResult09 OUTPUT, @cResult10 OUTPUT  '
   SET @cSQLParam =
      ' @nMobile      INT,           ' + 
      ' @nFunc        INT,           ' + 
      ' @cLangCode    NVARCHAR( 3),  ' + 
      ' @nStep        INT,           ' + 
      ' @nInputKey    INT,           ' + 
      ' @cFacility    NVARCHAR( 5) , ' + 
      ' @cStorerKey   NVARCHAR( 15), ' + 
      ' @cLight       NVARCHAR( 1),  ' + 
      ' @cStation     NVARCHAR( 10), ' + 
      ' @cMethod      NVARCHAR( 1) , ' + 
      ' @cSKU         NVARCHAR( 20), ' + 
      ' @cIPAddress   NVARCHAR( 40) OUTPUT, ' + 
      ' @cPosition    NVARCHAR( 10) OUTPUT, ' + 
      ' @nErrNo       INT           OUTPUT, ' + 
      ' @cErrMsg      NVARCHAR(250) OUTPUT, ' + 
      ' @cResult01    NVARCHAR( 20) OUTPUT, ' +
      ' @cResult02    NVARCHAR( 20) OUTPUT, ' +
      ' @cResult03    NVARCHAR( 20) OUTPUT, ' +
      ' @cResult04    NVARCHAR( 20) OUTPUT, ' +
      ' @cResult05    NVARCHAR( 20) OUTPUT, ' +
      ' @cResult06    NVARCHAR( 20) OUTPUT, ' +
      ' @cResult07    NVARCHAR( 20) OUTPUT, ' +
      ' @cResult08    NVARCHAR( 20) OUTPUT, ' +
      ' @cResult09    NVARCHAR( 20) OUTPUT, ' +
      ' @cResult10    NVARCHAR( 20) OUTPUT  '

   EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
      @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLight, 
      @cStation, @cMethod, @cSKU, @cIPAddress OUTPUT, @cPosition OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
      @cResult01 OUTPUT, @cResult02 OUTPUT, @cResult03 OUTPUT, @cResult04 OUTPUT, @cResult05 OUTPUT,
      @cResult06 OUTPUT, @cResult07 OUTPUT, @cResult08 OUTPUT, @cResult09 OUTPUT, @cResult10 OUTPUT

Quit:
END

GO
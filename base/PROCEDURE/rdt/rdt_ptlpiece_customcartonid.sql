SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_PTLPiece_CustomCartonID                         */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 23-11-2022 1.0  Ung         WMS-21112 Created                        */
/************************************************************************/

CREATE   PROC [RDT].[rdt_PTLPiece_CustomCartonID] (
    @nMobile      INT
   ,@nFunc        INT
   ,@cLangCode    NVARCHAR( 3)
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cFacility    NVARCHAR( 5)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cStation     NVARCHAR( 10)
   ,@cPosition    NVARCHAR( 10)
   ,@cMethod      NVARCHAR( 1) 
   ,@cSKU         NVARCHAR( 20)
   ,@nErrNo       INT           OUTPUT
   ,@cErrMsg      NVARCHAR(250) OUTPUT
   ,@cNewCartonID NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @bSuccess  INT
   DECLARE @cSQL      NVARCHAR( MAX)
   DECLARE @cSQLParam NVARCHAR( MAX)
   DECLARE @cCustomCartonIDSP NVARCHAR(20)
   
   SET @cCustomCartonIDSP = rdt.rdtGetConfig( @nFunc, 'CustomCartonIDSP', @cStorerKey)
   IF @cCustomCartonIDSP = '0'
      SET @cCustomCartonIDSP = ''

   -- Custom carton ID
   IF @cCustomCartonIDSP = ''
      GOTO Quit
   
   ELSE IF @cCustomCartonIDSP = '1'
   BEGIN
      EXEC nspg_GetKey
         'PACKNO', 
         10 ,
         @cNewCartonID  OUTPUT,
         @bSuccess      OUTPUT,
         @nErrNo        OUTPUT,
         @cErrMsg       OUTPUT
   END
   
   ELSE IF @cCustomCartonIDSP = 'isp_GenUCCLabelNo'
   BEGIN
      EXEC isp_GenUCCLabelNo
         @cStorerKey,
         @cNewCartonID  OUTPUT, 
         @bSuccess      OUTPUT,
         @nErrNo        OUTPUT,
         @cErrMsg       OUTPUT
   END
   
   ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cCustomCartonIDSP AND type = 'P')
   BEGIN 
      SET @cSQL = 'EXEC rdt.' + RTRIM( @cCustomCartonIDSP) +
         ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
         ' @cStation, @cPosition, @cMethod, @cSKU, ' + 
         ' @nErrNo OUTPUT, @cErrMsg OUTPUT, @cNewCartonID OUTPUT ' 
      SET @cSQLParam =
         ' @nMobile      INT,           ' + 
         ' @nFunc        INT,           ' + 
         ' @cLangCode    NVARCHAR( 3),  ' + 
         ' @nStep        INT,           ' + 
         ' @nInputKey    INT,           ' + 
         ' @cFacility    NVARCHAR( 5) , ' + 
         ' @cStorerKey   NVARCHAR( 15), ' + 
         ' @cStation     NVARCHAR( 10), ' + 
         ' @cPosition    NVARCHAR( 10), ' + 
         ' @cMethod      NVARCHAR( 1),  ' + 
         ' @cSKU         NVARCHAR( 20), ' + 
         ' @nErrNo       INT           OUTPUT, ' + 
         ' @cErrMsg      NVARCHAR(250) OUTPUT, ' + 
         ' @cNewCartonID NVARCHAR( 20) OUTPUT  '
   
      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
         @cStation, @cPosition, @cMethod, @cSKU, 
         @nErrNo OUTPUT, @cErrMsg OUTPUT, @cNewCartonID OUTPUT
   END

Quit:

END

GO
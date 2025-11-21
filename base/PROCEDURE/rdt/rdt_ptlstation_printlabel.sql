SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_PTLStation_PrintLabel                           */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 09-03-2016 1.0  Ung         SOS361967 Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_PTLStation_PrintLabel] (
    @nMobile      INT
   ,@nFunc        INT
   ,@cLangCode    NVARCHAR( 3)
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cFacility    NVARCHAR( 5)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cType        NVARCHAR( 15) -- ID=confirm ID, CLOSETOTE/SHORTTOTE = confirm tote
   ,@cStation1    NVARCHAR( 10)
   ,@cStation2    NVARCHAR( 10)
   ,@cStation3    NVARCHAR( 10)
   ,@cStation4    NVARCHAR( 10)
   ,@cStation5    NVARCHAR( 10)
   ,@cMethod      NVARCHAR( 1) 
   ,@cCartonID    NVARCHAR( 20)
   ,@nErrNo       INT           OUTPUT
   ,@cErrMsg      NVARCHAR(250) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL      NVARCHAR( MAX)
   DECLARE @cSQLParam NVARCHAR( MAX)
   
   -- Storer configure
   DECLARE @cPrintLabelSP NVARCHAR(20)
   SELECT @cPrintLabelSP = rdt.rdtGetConfig( @nFunc, 'PrintLabelSP', @cStorerKey)
   IF @cPrintLabelSP = '0'
      SET @cPrintLabelSP = ''

   IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cPrintLabelSP AND type = 'P')
   BEGIN
      SET @cSQL = 'EXEC rdt.' + RTRIM( @cPrintLabelSP) +
         ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cType, ' +
         ' @cStation1, @cStation2, @cStation3, @cStation4, @cStation5, @cMethod, @cCartonID, ' + 
         ' @nErrNo OUTPUT, @cErrMsg OUTPUT' 
      SET @cSQLParam =
         ' @nMobile      INT,           ' + 
         ' @nFunc        INT,           ' + 
         ' @cLangCode    NVARCHAR( 3),  ' + 
         ' @nStep        INT,           ' + 
         ' @nInputKey    INT,           ' + 
         ' @cFacility    NVARCHAR( 5) , ' + 
         ' @cStorerKey   NVARCHAR( 15), ' + 
         ' @cType        NVARCHAR( 15), ' +  
         ' @cStation1    NVARCHAR( 10), ' + 
         ' @cStation2    NVARCHAR( 10), ' + 
         ' @cStation3    NVARCHAR( 10), ' + 
         ' @cStation4    NVARCHAR( 10), ' + 
         ' @cStation5    NVARCHAR( 10), ' + 
         ' @cMethod      NVARCHAR( 1),  ' + 
         ' @cCartonID    NVARCHAR( 20), ' + 
         ' @nErrNo       INT           OUTPUT, ' + 
         ' @cErrMsg      NVARCHAR(250) OUTPUT  '  
   
      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cType, 
         @cStation1, @cStation2, @cStation3, @cStation4, @cStation5, @cMethod, @cCartonID, 
         @nErrNo OUTPUT, @cErrMsg OUTPUT
   END
   
Quit:
END

GO
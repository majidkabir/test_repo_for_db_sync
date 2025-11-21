SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_PTLStation_Confirm                              */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 29-02-2016 1.0  Ung         SOS361967 Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_PTLStation_Confirm] (
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
   ,@cScanID      NVARCHAR( 20) 
   ,@cSKU         NVARCHAR( 20)
   ,@nQTY         INT
   ,@nErrNo       INT           OUTPUT
   ,@cErrMsg      NVARCHAR(250) OUTPUT
   ,@cCartonID    NVARCHAR( 20) = ''
   ,@nCartonQTY   INT           = 0
   ,@cNewCartonID NVARCHAR( 20) = '' -- For close carton with balance
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
   SELECT @cConfirmSP = ISNULL( UDF03, '')
   FROM CodeLKUP WITH (NOLOCK)
   WHERE ListName = 'PTLMethod'
      AND Code = @cMethod
      AND StorerKey = @cStorerKey

   -- Check confirm SP blank
   IF @cConfirmSP = ''
   BEGIN
      SET @nErrNo = 54651
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SetupConfirmSP
      GOTO Quit
   END

   -- Check confirm SP valid
   IF NOT EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cConfirmSP AND type = 'P')
   BEGIN
      SET @nErrNo = 54652
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Confirm SP
      GOTO Quit
   END

   -- Confirm SP
   SET @cSQL = 'EXEC rdt.' + RTRIM( @cConfirmSP) +
      ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
      ' @cType, @cStation1, @cStation2, @cStation3, @cStation4, @cStation5, @cMethod, @cScanID, @cSKU, @nQTY, ' + 
      ' @nErrNo OUTPUT, @cErrMsg OUTPUT, @cCartonID, @nCartonQTY, @cNewCartonID ' 
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
      ' @cScanID      NVARCHAR( 20), ' +  
      ' @cSKU         NVARCHAR( 20), ' + 
      ' @nQTY         INT,           ' + 
      ' @nErrNo       INT           OUTPUT, ' + 
      ' @cErrMsg      NVARCHAR(250) OUTPUT, ' + 
      ' @cCartonID    NVARCHAR( 20), ' + 
      ' @nCartonQTY   INT,           ' + 
      ' @cNewCartonID NVARCHAR( 20)  '

   EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
      @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
      @cType, @cStation1, @cStation2, @cStation3, @cStation4, @cStation5, @cMethod, @cScanID, @cSKU, @nQTY, 
      @nErrNo OUTPUT, @cErrMsg OUTPUT, @cCartonID, @nCartonQTY, @cNewCartonID 

Quit:
END

GO
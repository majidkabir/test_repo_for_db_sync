SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_PTLStation_CreateTask                           */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 16-02-2016  1.0  Ung         SOS361967 Created                       */
/* 12-07-2017  1.1  Ung         WMS-2410 Clear scan ID if not task      */
/************************************************************************/

CREATE PROC [RDT].[rdt_PTLStation_CreateTask] (
    @nMobile      INT
   ,@nFunc        INT
   ,@cLangCode    NVARCHAR(3)
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cFacility    NVARCHAR(5)
   ,@cStorerKey   NVARCHAR(15)
   ,@cType        NVARCHAR(20) 
   ,@cLight       NVARCHAR(1)   -- 0 = no light, 1 = use light
   ,@cStation1    NVARCHAR(10)  
   ,@cStation2    NVARCHAR(10)  
   ,@cStation3    NVARCHAR(10)  
   ,@cStation4    NVARCHAR(10)  
   ,@cStation5    NVARCHAR(10)  
   ,@cMethod      NVARCHAR(10)
   ,@cScanID      NVARCHAR(20)      OUTPUT
   ,@cCartonID    NVARCHAR(20)
   ,@nErrNo       INT               OUTPUT
   ,@cErrMsg      NVARCHAR(20)      OUTPUT
   ,@cSKU         NVARCHAR(20) = '' OUTPUT
   ,@cSKUDescr    NVARCHAR(60) = '' OUTPUT
   ,@nQTY         INT          = 0  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL      NVARCHAR( MAX)
   DECLARE @cSQLParam NVARCHAR( MAX)
   DECLARE @bSuccess INT

   -- Get method info
   DECLARE @cCreateTaskSP SYSNAME
   SET @cCreateTaskSP = ''
   SELECT @cCreateTaskSP = ISNULL( UDF02, '')
   FROM CodeLKUP WITH (NOLOCK)
   WHERE ListName = 'PTLMethod'
      AND Code = @cMethod
      AND StorerKey = @cStorerKey

   -- Check get task SP blank
   IF @cCreateTaskSP = ''
   BEGIN
      SET @nErrNo = 97151
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SetupGenTaskSP
      GOTO Quit
   END

   -- Check get task SP valid
   IF NOT EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cCreateTaskSP AND type = 'P')
   BEGIN
      SET @nErrNo = 97152
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad GenTask SP
      GOTO Quit
   END

   -- Gen task SP
   SET @cSQL = 'EXEC rdt.' + RTRIM( @cCreateTaskSP) +
      ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
      ' @cType, @cLight, @cStation1, @cStation2, @cStation3, @cStation4, @cStation5, @cMethod, @cScanID OUTPUT, @cCartonID, ' +
      ' @nErrNo OUTPUT, @cErrMsg OUTPUT, @cSKU OUTPUT, @cSKUDescr OUTPUT, @nQTY OUTPUT '
   SET @cSQLParam =
      ' @nMobile    INT,          ' +
      ' @nFunc      INT,          ' +
      ' @cLangCode  NVARCHAR( 3), ' +
      ' @nStep      INT,          ' +
      ' @nInputKey  INT,          ' +
      ' @cFacility  NVARCHAR(5),  ' +
      ' @cStorerKey NVARCHAR(15), ' +
      ' @cType      NVARCHAR(20), ' +
      ' @cLight     NVARCHAR(1),  ' +
      ' @cStation1  NVARCHAR(10), ' +  
      ' @cStation2  NVARCHAR(10), ' +  
      ' @cStation3  NVARCHAR(10), ' +  
      ' @cStation4  NVARCHAR(10), ' +  
      ' @cStation5  NVARCHAR(10), ' +  
      ' @cMethod    NVARCHAR(10), ' +
      ' @cScanID    NVARCHAR(20) OUTPUT, ' +
      ' @cCartonID  NVARCHAR(10),        ' +
      ' @nErrNo     INT          OUTPUT, ' +
      ' @cErrMsg    NVARCHAR(20) OUTPUT, ' +
      ' @cSKU       NVARCHAR(20) OUTPUT, ' +
      ' @cSKUDescr  NVARCHAR(60) OUTPUT, ' +
      ' @nQTY       INT          OUTPUT  '

   EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
      @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
      @cType, @cLight, @cStation1, @cStation2, @cStation3, @cStation4, @cStation5, @cMethod, @cScanID OUTPUT, @cCartonID, 
      @nErrNo OUTPUT, @cErrMsg OUTPUT, @cSKU OUTPUT, @cSKUDescr OUTPUT, @nQTY OUTPUT 

Quit:

END

GO
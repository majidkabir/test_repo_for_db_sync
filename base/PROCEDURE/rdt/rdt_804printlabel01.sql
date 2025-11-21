SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_804PrintLabel01                                 */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 11-03-2016 1.0  Ung         SOS363160 Created                        */
/* 2016-10-07 1.1  ChewKP      WMS-490 Add 1 more options (ChewKP01)    */
/* 2017-03-29 1.2  ChewKP      Fixes from WMS-924 (CheWKP02)            */
/************************************************************************/

CREATE PROC [RDT].[rdt_804PrintLabel01] (
    @nMobile      INT
   ,@nFunc        INT
   ,@cLangCode    NVARCHAR( 3)
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cFacility    NVARCHAR( 5)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cType        NVARCHAR( 15) 
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
   
   
   DECLARE @cPasscode     NVARCHAR(20) -- (ChewKP02) 
   
   SELECT @cPassCode = Long 
   FROM dbo.Codelkup WITH (NOLOCK) 
   WHERE ListName = '593-UA'
   AND Code = 'Passcode'
    

   EXEC rdt.rdtUALabel
      @nMobile    = @nMobile,
      @nFunc      = @nFunc,
      @nStep      = @nStep,
      @cLangCode  = @cLangCode,
      @cStorerKey = @cStorerKey,
      @cOption    = '2',         -- Not used -- (ChewKP01) 
      @cParam1    = @cCartonID, -- LabelNo
      @cParam2    = '',
      @cParam3    = @cPassCode,  
      @cParam4    = '',
      @cParam5    = '',
      @nErrNo     = @nErrNo  OUTPUT,
      @cErrMsg    = @cErrMsg OUTPUT

Quit:
END

GO
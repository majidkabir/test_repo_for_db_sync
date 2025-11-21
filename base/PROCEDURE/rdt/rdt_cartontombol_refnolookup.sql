SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_CartonToMBOL_RefNoLookup                              */
/* Copyright      : Mearsk                                                    */
/*                                                                            */
/* Date         Rev  Author   Purposes                                        */
/* 2023-07-17   1.0  Ung      WMS-22678 Created                               */
/******************************************************************************/
CREATE   PROC [RDT].[rdt_CartonToMBOL_RefNoLookup](
    @nMobile         INT
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR( 3)
   ,@nStep           INT
   ,@nInputKey       INT
   ,@cFacility       NVARCHAR( 5)
   ,@cStorerKey      NVARCHAR( 15)
   ,@cStorerGroup    NVARCHAR( 20)
   ,@cMBOLKey        NVARCHAR( 10)  OUTPUT
   ,@cRefNo          NVARCHAR( 20)  OUTPUT
   ,@nErrNo          INT            OUTPUT
   ,@cErrMsg         NVARCHAR( 20)  OUTPUT
) 
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL           NVARCHAR( MAX)
   DECLARE @cSQLParam      NVARCHAR( MAX)
   DECLARE @cRefNoLookupSP NVARCHAR( 20)

   -- Get storer config
   SET @cRefNoLookupSP = rdt.RDTGetConfig( @nFunc, 'RefNoLookupSP', @cStorerKey)
   IF @cRefNoLookupSP = '0'
      SET @cRefNoLookupSP = ''
 
   /***********************************************************************************************
                                              Custom confirm
   ***********************************************************************************************/
   IF @cRefNoLookupSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cRefNoLookupSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cRefNoLookupSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cStorerGroup, ' +
            ' @cMBOLKey OUTPUT, @cRefNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT ' 
         SET @cSQLParam =
            '  @nMobile         INT            ' + 
            ' ,@nFunc           INT            ' + 
            ' ,@cLangCode       NVARCHAR( 3)   ' + 
            ' ,@nStep           INT            ' + 
            ' ,@nInputKey       INT            ' + 
            ' ,@cFacility       NVARCHAR( 5)   ' + 
            ' ,@cStorerKey      NVARCHAR( 15)  ' + 
            ' ,@cStorerGroup    NVARCHAR( 20)  ' + 
            ' ,@cMBOLKey        NVARCHAR( 10) OUTPUT ' + 
            ' ,@cRefNo          NVARCHAR( 20) OUTPUT ' + 
            ' ,@nErrNo          INT           OUTPUT ' + 
            ' ,@cErrMsg         NVARCHAR( 20) OUTPUT ' 

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cStorerGroup, 
            @cMBOLKey OUTPUT, @cRefNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT 

         GOTO Quit
      END
   END

   /***********************************************************************************************
                                             Standard lookup
   ***********************************************************************************************/
   IF @cStorerGroup = ''
      SELECT @cMBOLKey = MBOLKey
      FROM rdt.rdtCartonToMBOLLog WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND CartonID = @cRefNo
   ELSE
      SELECT TOP 1 
         @cMBOLKey = MBOLKey
      FROM rdt.rdtCartonToMBOLLog L WITH (NOLOCK)
         JOIN dbo.StorerGroup SG WITH (NOLOCK) ON (SG.StorerKey = L.StorerKey AND SG.StorerGroup = @cStorerGroup)
      WHERE CartonID = @cRefNo
         
Quit:

END

GO
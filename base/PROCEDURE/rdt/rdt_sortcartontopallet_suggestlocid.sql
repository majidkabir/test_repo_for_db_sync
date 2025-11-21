SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_SortCartonToPallet_SuggestLOCID                    */
/* Copyright      : Maersk                                                 */
/*                                                                         */
/* Purpose: Save carton to pallet                                          */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date         Rev  Author   Purposes                                     */
/* 2023-07-18   1.0  Ung      WMS-22855 Created                            */
/***************************************************************************/

CREATE   PROC [RDT].[rdt_SortCartonToPallet_SuggestLOCID](
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5),
   @cStorerKey    NVARCHAR( 15),
   @cUpdateTable  NVARCHAR( 20), -- DROPID/PALLET
   @cCartonID     NVARCHAR( 20),
   @cPalletID     NVARCHAR( 20),
   @cCartonUDF01  NVARCHAR( 30), 
   @cCartonUDF02  NVARCHAR( 30), 
   @cCartonUDF03  NVARCHAR( 30), 
   @cCartonUDF04  NVARCHAR( 30), 
   @cCartonUDF05  NVARCHAR( 30), 
   @cSuggID       NVARCHAR( 18) OUTPUT,
   @cSuggLOC      NVARCHAR( 10) OUTPUT,
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL              NVARCHAR(MAX)
   DECLARE @cSQLParam         NVARCHAR(MAX)
   DECLARE @cSuggestLOCIDSP   NVARCHAR(20) = ''

   SET @cSuggestLOCIDSP = rdt.rdtGetConfig( @nFunc, 'SuggestLOCIDSP', @cStorerKey)
   IF @cSuggestLOCIDSP = '0'
      SET @cSuggestLOCIDSP = ''

   /***********************************************************************************************
                                              Custom logic
   ***********************************************************************************************/
   IF @cSuggestLOCIDSP <> '' 
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cSuggestLOCIDSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cSuggestLOCIDSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
            ' @cUpdateTable, @cCartonID, @cPalletID, ' +
            ' @cCartonUDF01, @cCartonUDF02, @cCartonUDF03, @cCartonUDF04, @cCartonUDF05, ' + 
            ' @cSuggID OUTPUT, @cSuggLOC OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam =
            ' @nMobile        INT,           ' + 
            ' @nFunc          INT,           ' + 
            ' @cLangCode      NVARCHAR( 3),  ' + 
            ' @nStep          INT,           ' + 
            ' @nInputKey      INT,           ' + 
            ' @cFacility      NVARCHAR( 5),  ' + 
            ' @cStorerKey     NVARCHAR( 15), ' +   
            ' @cUpdateTable   NVARCHAR( 20), ' + 
            ' @cCartonID      NVARCHAR( 20), ' + 
            ' @cPalletID      NVARCHAR( 20), ' + 
            ' @cCartonUDF01   NVARCHAR( 30), ' + 
            ' @cCartonUDF02   NVARCHAR( 30), ' + 
            ' @cCartonUDF03   NVARCHAR( 30), ' + 
            ' @cCartonUDF04   NVARCHAR( 30), ' + 
            ' @cCartonUDF05   NVARCHAR( 30), ' + 
            ' @cSuggID        NVARCHAR( 18) OUTPUT, ' + 
            ' @cSuggLOC       NVARCHAR( 10) OUTPUT, ' + 
            ' @nErrNo         INT           OUTPUT, ' + 
            ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
            
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
            @cUpdateTable, @cCartonID, @cPalletID, 
            @cCartonUDF01, @cCartonUDF02, @cCartonUDF03, @cCartonUDF04, @cCartonUDF05, 
            @cSuggID OUTPUT, @cSuggLOC OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

         GOTO Quit
      END
   END

   /***********************************************************************************************
                                             Standard logic
   ***********************************************************************************************/
   IF @cUpdateTable = 'DROPID'
      SELECT TOP 1 
         @cSuggID = DropID, 
         @cSuggLOC = DropLOC
      FROM dbo.DropID WITH (NOLOCK)
      WHERE DropIDType = CAST( @nFunc AS NVARCHAR( 4))
         AND Status = '0'
         AND UDF01 = @cCartonUDF01
         AND UDF02 = @cCartonUDF02
         AND UDF03 = @cCartonUDF03
         AND UDF04 = @cCartonUDF04
         AND UDF05 = @cCartonUDF05
      ORDER BY EditDate DESC
   ELSE
      SELECT TOP 1 
         @cSuggID = PD.PalletKey, 
         @cSuggLOC = PD.LOC
      FROM dbo.Pallet P WITH (NOLOCK)
         JOIN dbo.PalletDetail PD WITH (NOLOCK) ON (P.PalletKey = PD.PalletKey)
      WHERE P.PalletType = CAST( @nFunc AS NVARCHAR( 4))
         AND P.Status = '0'
         AND PD.UserDefine01 = @cCartonUDF01
         AND PD.UserDefine02 = @cCartonUDF02
         AND PD.UserDefine03 = @cCartonUDF03
         AND PD.UserDefine04 = @cCartonUDF04
         AND PD.UserDefine05 = @cCartonUDF05
      ORDER BY P.EditDate DESC

Quit:

END

GO
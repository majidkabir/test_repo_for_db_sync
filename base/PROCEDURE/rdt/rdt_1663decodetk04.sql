SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1663DecodeTK04                                        */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Decode tracking no                                                */
/*                                                                            */
/* Date        Author   Ver.  Purposes                                        */
/* 2020-06-11  James    1.0   WMS-13458 Created                               */
/* 2021-11-11  Chermain 1.1   WMS-18330 Remove @nRefField checking (cc01)     */  
/* 2023-10-10  James    1.2   JSM-185342 Add output variable TrackNo (james01)*/
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1663DecodeTK04]
   @nMobile       INT,  
   @nFunc         INT,  
   @cLangCode     NVARCHAR( 3),  
   @nStep         INT,  
   @nInputKey     INT,  
   @cFacility     NVARCHAR( 5),  
   @cStorerKey    NVARCHAR( 15),  
   @cPalletKey    NVARCHAR( 20),   
   @cPalletLOC    NVARCHAR( 10),   
   @cMBOLKey      NVARCHAR( 10),   
   @cTrackNo      NVARCHAR( 20) OUTPUT,   
   @cOrderKey     NVARCHAR( 10) OUTPUT,   
   @nErrNo        INT           OUTPUT,  
   @cErrMsg       NVARCHAR( 20) OUTPUT  
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nRowCount      INT
   DECLARE @cSQL           NVARCHAR( MAX)
   DECLARE @cSQLParam      NVARCHAR( MAX)
   DECLARE @cShipperKey    NVARCHAR( 15)
   DECLARE @cUDF02         NVARCHAR( 60)
   DECLARE @nRefField      INT
   DECLARE @nOrderField    INT
   DECLARE @curColumn      CURSOR
   DECLARE @cFunc          NVARCHAR(10)
   
   SET @nRefField = 0
   SET @nOrderField = 0
   
   IF @nStep = 3
   BEGIN
      IF @nInputKey = 1
      BEGIN
         SET @cOrderKey = ''
         SET @cFunc = CONVERT(NVARCHAR(10),@nFunc)

         SET @curColumn = CURSOR FOR
            SELECT UDF01, UDF02
            FROM CodeLKUP WITH (NOLOCK) 
            WHERE ListName = 'SCN2PLT' 
               AND StorerKey = @cStorerKey 
               AND Code2 = @cFunc
            ORDER BY Short
            OPEN @curColumn
            FETCH NEXT FROM @curColumn INTO @cShipperKey, @cUDF02
            WHILE @@FETCH_STATUS = 0
            BEGIN
               ---- Check max lookup field (for performance, ref field might not indexed)
               --SET @nRefField = @nRefField + 1
               --IF @nRefField > 5
               --BEGIN
               --   SET @nErrNo = 153501
               --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Max 3 RefField
               --   GOTO Quit
               --END

               IF ISNULL( @cUDF02, '') = ''
                  SET @cUDF02 = ''

               SET @cSQL = 
                  ' SELECT @cOrderKey = OrderKey ' + 
                  ' FROM dbo.ORDERS WITH (NOLOCK) ' + 
                  ' WHERE StorerKey = @cStorerKey ' + 
                     ' AND ShipperKey = @cShipperKey ' +
                     ' AND Status NOT IN (''9'', ''CANC'') ' + 
                     ' AND SOStatus <> ''CANC'' ' + 
                     ' AND Facility = @cFacility ' + 
                     CASE WHEN @cUDF02 = '' THEN ' AND ISNULL( TrackingNo, '''') = @cTrackNo ' 
                           ELSE ' AND TrackingNo = ' + @cUDF02 END +
                     ' AND TrackingNo <> '''' ' +
                  ' SELECT @nErrNo = @@ERROR, @nRowCount = @@ROWCOUNT ' 
               SET @cSQLParam =
                  ' @nMobile      INT, ' + 
                  ' @cFacility    NVARCHAR(5),  ' + 
                  ' @cStorerKey   NVARCHAR(15), ' + 
                  ' @cShipperKey  NVARCHAR(15), ' +
                  ' @cTrackNo     NVARCHAR(20), ' + 
                  ' @cOrderKey    NVARCHAR(10) OUTPUT, ' + 
                  ' @nRowCount    INT          OUTPUT, ' + 
                  ' @nErrNo       INT          OUTPUT  '
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 
                  @nMobile, 
                  @cFacility, 
                  @cStorerKey, 
                  @cShipperKey,
                  @cTrackNo, 
                  @cOrderKey   OUTPUT, 
                  @nRowCount   OUTPUT, 
                  @nErrNo      OUTPUT
   
               IF @nErrNo <> 0
                  GOTO Quit
   
               -- Check RefNo in Orders
               IF @nRowCount > 1
               BEGIN
                  SET @nErrNo = 153502
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Multi Orders
                  GOTO Quit
               END

               IF ISNULL( @cOrderKey, '') <> ''
                  BREAK            
            
               FETCH NEXT FROM @curColumn INTO @cShipperKey, @cUDF02
            END
      END
   END
   
   -- Receipt not found
   IF @cOrderKey = ''
   BEGIN
      SET @nErrNo = 153503
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Orders Found
      GOTO Quit
   END
   GOTO Quit
   
END

Quit:


GO
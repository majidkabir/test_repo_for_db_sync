SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1641ExtValidSP20                                      */
/* Purpose: Validate Pallet DropID                                            */
/*                                                                            */
/* Modifications log:                                                         */
/*  rdt_1641ExtValidSP09->rdt_1641ExtValidSP20                                */                     
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2023-06-15 1.0  yeekung  WMS-22812. Created                                */
/******************************************************************************/

CREATE    PROC [RDT].[rdt_1641ExtValidSP20] (
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR(3),
   @nStep        INT,
   @nInputKey    INT, 
   @cStorerKey   NVARCHAR(15),
   @cDropID      NVARCHAR(20),
   @cUCCNo       NVARCHAR(20),
   @cPrevLoadKey NVARCHAR(10),
   @cParam1      NVARCHAR(20),
   @cParam2      NVARCHAR(20),
   @cParam3      NVARCHAR(20),
   @cParam4      NVARCHAR(20),
   @cParam5      NVARCHAR(20),
   @nErrNo       INT          OUTPUT,
   @cErrMsg      NVARCHAR(20) OUTPUT
)
AS

SET NOCOUNT ON  
SET QUOTED_IDENTIFIER OFF  
SET ANSI_NULLS OFF  
SET CONCAT_NULL_YIELDS_NULL OFF  

IF @nFunc = 1641
BEGIN
   DECLARE @cColumnName       NVARCHAR( 20), 
           @cTableName        NVARCHAR( 20), 
           @cExecStatements   NVARCHAR( 4000), 
           @cExecArguments    NVARCHAR( 4000),
           @cCode             NVARCHAR( 10),
           @cDataType         NVARCHAR( 128),
           @cValue            NVARCHAR( 60),
           @cPrefixLen        NVARCHAR( 60),
           @cUDF01            NVARCHAR( 60),
           @cUDF02            NVARCHAR( 60),
           @cUDF03            NVARCHAR( 60),
           @cPalletCriteria   NVARCHAR( 20),
           @cNotes            NVARCHAR( 60),
           @cCurRoute         NVARCHAR( 30),
           @nCount            INT, 
           @nDebug            INT, 
           @nStart            INT,
           @nLen              INT,
           @cSUSR1            NVARCHAR( 20),
           @cConsigneeKey     NVARCHAR( 15),
           @cOrderKey         NVARCHAR( 10)

   DECLARE @cOrderGroup       NVARCHAR( 20) = '',
           @cC_ISOCntryCode   NVARCHAR( 10) = '',
           @cUserDefine01     NVARCHAR( 30) = '',
           @cOrders_M_Company   NVARCHAR( 45) = '',
           @cShipperKey       NVARCHAR( 15) = ''

   DECLARE @cTrackOrderKey    NVARCHAR( 10) = ''
   DECLARE @cPalletOrderKey   NVARCHAR( 10) = ''
   
   SET @nDebug = 0
   
   SET @nErrNo = 0

   IF @nStep = 1 -- Drop id
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         IF EXISTS ( SELECT 1 FROM dbo.Pallet WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                     AND   PalletKey = @cDropID
                     AND  [Status] = '9')
         BEGIN
            SET @nErrNo = 202701
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Pallet closed
            GOTO Quit               
         END
      END
   END

   IF @nStep = 3 -- UCC
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
      	SELECT @cTrackOrderKey = OrderKey
      	FROM dbo.ORDERS WITH (NOLOCK)
      	WHERE StorerKey = @cStorerKey
      	AND   M_Address1 = @cUCCNo
         
         IF @cTrackOrderKey <> ''
         BEGIN
            SELECT TOP 1 @cPalletOrderKey = UserDefine02
            FROM dbo.PALLETDETAIL WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            AND   PalletKey = @cDropID
            AND  [Status] < '9'
            ORDER BY 1
            
            IF @cPalletOrderKey <> ''
            BEGIN
            	IF @cPalletOrderKey <> @cTrackOrderKey
               BEGIN
                  SET @nErrNo = 202712
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Plt Mix Orders
                  GOTO Quit               
               END
            END
         END
      	ELSE
      	BEGIN
            SELECT TOP 1 @cOrderKey = OrderKey
            FROM dbo.PackHeader AS ph WITH (NOLOCK)
            JOIN dbo.PackDetail AS pd WITH (NOLOCK) ON ( ph.PickSlipNo = pd.PickSlipNo)
            WHERE pd.StorerKey = @cStorerKey
            AND   pd.LabelNo = @cUCCNo
            ORDER BY 1
         
            IF @@ROWCOUNT = 0
            BEGIN
               SET @nErrNo = 202702
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Inv carton id
               GOTO Quit               
            END
                  
            SELECT @cConsigneeKey = ConsigneeKey, 
                   @cOrderGroup = OrderGroup, 
                   @cC_ISOCntryCode = C_ISOCntryCode,
                   @cOrders_M_Company = M_Company,
                   @cShipperKey = o.ShipperKey
            FROM dbo.ORDERS AS o WITH (NOLOCK)
            WHERE o.OrderKey = @cOrderKey
         
            -- Check if case id scanned before
            IF EXISTS ( SELECT 1 FROM dbo.PalletDetail WITH (NOLOCK)
                        WHERE StorerKey = @cStorerKey
                        AND   CaseID = @cUCCNo
                        AND   PalletKey = @cDropID
                        AND  [Status] < '9')
            BEGIN
               SET @nErrNo = 202704
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- carton scan b4
               GOTO Quit               
            END

            -- Check if case scanned to other pallet before no matter the status
            IF EXISTS ( SELECT 1 FROM dbo.PALLETDETAIL WITH (NOLOCK)
                        WHERE StorerKey = @cStorerKey
                        AND   CaseID = @cUCCNo
                        AND   PalletKey <> @cDropID)
            BEGIN
               SET @nErrNo = 202705
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ctn in other plt
               GOTO Quit               
            END

            -- Existing route
            SELECT TOP 1 @cCurRoute = UserDefine01
            FROM dbo.PalletDetail WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            AND   PalletKey = @cDropID
            AND   [Status] < '9'

            IF @cOrderGroup <> 'ECOM'
            BEGIN
               SELECT @cSUSR1 = SUSR1 
               FROM dbo.Storer WITH (NOLOCK)
               WHERE StorerKey = @cConsigneeKey
               AND  [TYPE] = '2'
         
               IF ISNULL( @cSUSR1, '') = '' 
               BEGIN
                  SET @nErrNo = 202703
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SUSR1 Blank
                  GOTO Quit               
               END
         
               -- Not 1st time scan carton
               IF ISNULL( @cCurRoute, '') <> ''
               BEGIN
                  IF ISNULL( @cCurRoute, '') <> ISNULL( @cSUSR1, '')
                  BEGIN
                     SET @nErrNo = 202706
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Wrong route
                     GOTO Quit               
                  END
               END
            END
            ELSE  -- Ecom
            BEGIN
               -- Existing route
               SELECT TOP 1 @cCurRoute = UserDefine01
               FROM dbo.PalletDetail WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
               AND   PalletKey = @cDropID
               AND   [Status] < '9'

               -- Not 1st time scan carton
               IF ISNULL( @cCurRoute, '') <> ''
               BEGIN
                  SET @cUserDefine01 = SUBSTRING( RTRIM( @cC_ISOCntryCode) + 
                                       RTRIM( @cOrders_M_Company) + 
                                       RTRIM( @cShipperKey), 1, 30)

                  IF ISNULL( @cCurRoute, '') <> ISNULL( @cUserDefine01, '')
                  BEGIN
                     SET @nErrNo = 202711
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Wrong route
                     GOTO Quit               
                  END
               END

            END
         END

         IF (SELECT COUNT(DISTINCT userdefine02)
             FROM dbo.PALLETDETAIL WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            AND   PalletKey = @cDropID
            AND  [Status] < '9') > 100
         BEGIN
            SET @nErrNo = 202713
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ExceedOrders
            GOTO Quit
         END
      END
   END

   IF @nStep = 5 -- PALLET CRITERIA
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         -- pallet build criteria rules
         -- UDF01 = 1 meaning mandatory field and cannot be empty
         -- UDF02 0 = exact match; 1 = match prefix; 2 = match datetime

         -- Check mandatory field
         DECLARE CUR_REQ CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
         SELECT Code, Notes, UDF01, UDF02, UDF03
         FROM dbo.CODELKUP WITH (NOLOCK)
         WHERE ListName = 'PLTBLDCRIT'
         AND   StorerKey = @cStorerKey
         AND   (ISNULL( UDF01, '') <> '' OR 
                ISNULL( UDF02, '') <> '')
         ORDER BY 1
         OPEN CUR_REQ
         FETCH NEXT FROM CUR_REQ INTO @cCode, @cNotes, @cUDF01, @cUDF02, @cUDF03
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            SELECT @nStart = CHARINDEX( '.', @cNotes) + 1
            SELECT @nLen = LEN( @cNotes) - CHARINDEX( '.', @cNotes) + 1
            SELECT @cTableName = SUBSTRING( @cNotes, 1, @nStart - 2)
            SELECT @cColumnName = SUBSTRING( @cNotes, @nStart, @nLen)

            IF @nDebug = 1
            BEGIN
               PRINT @cTableName
               PRINT @cColumnName
            END

            SELECT @cDataType = DATA_TYPE 
            FROM INFORMATION_SCHEMA.COLUMNS 
            WHERE TABLE_NAME = @cTableName 
            AND COLUMN_NAME = @cColumnName

            IF @cDataType = ''            
            BEGIN
               SET @nErrNo = 202707
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Inv field name
               CLOSE CUR_REQ
               DEALLOCATE CUR_REQ
               GOTO Quit               
            END                            

            IF @cUDF02 = '2' AND @cDataType <> 'datetime'
            BEGIN
               SET @nErrNo = 202708
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Inv field type
               CLOSE CUR_REQ
               DEALLOCATE CUR_REQ
               GOTO Quit               
            END                 

            SET @cValue = ''
            SET @cValue = CASE 
                          WHEN @cCode = 'REFNO2' THEN @cParam1
                          ELSE '' END
            IF @nDebug = 1
            BEGIN
               PRINT @cCode
               PRINT @cNotes
               PRINT @cValue
            END
            
            -- Check empty
            IF ISNULL( @cUDF01, '') = '1' AND ISNULL( @cValue, '') = ''
            BEGIN
               SET @nErrNo = 202709
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Value required
               CLOSE CUR_REQ
               DEALLOCATE CUR_REQ
               GOTO Quit               
            END   --Check empty

            -- No velue key in then no validation req
            -- Check blank value in step 1
            IF ISNULL( @cValue, '') = '' AND 
               @cPalletCriteria NOT IN ('', '0')
               GOTO FETCH_NEXT   -- Continue next record to validate

            -- How to validate against table field
            IF ISNULL( @cUDF02, '') <> '' 
            BEGIN
               SET @cExecStatements = ''
               SET @cExecArguments = ''
               SET @nCount = 0

               SET @cExecStatements = 'SELECT @nCount = 1 ' + 
                                      'FROM dbo.' + @cTableName + ' WITH (NOLOCK) ' +
                                      'WHERE StorerKey = ''' + RTRIM(@cStorerKey)  + ''' ' 

               -- Exact match
               IF @cUDF02 = '0'
               BEGIN
                  SET @cExecStatements = @cExecStatements + 
                                       CASE WHEN @cDataType IN ('int', 'float') 
                                            THEN ' AND ISNULL( ' + @cColumnName + ', 0) = CAST( ' + @cValue + ' AS INT)'
                                            ELSE ' AND ISNULL( ' + @cColumnName + ', '''') = ''' + @cValue + ''' '
                                       END 

               END

               -- Prefix match
               IF @cUDF02 = '1'
               BEGIN 
                  SET @cPrefixLen = LEN( RTRIM( @cValue))
                  
                  SET @cExecStatements = @cExecStatements + 
                                       ' AND SUBSTRING( ' + @cColumnName + ', 1, ' + @cPrefixLen + ') = ''' + @cValue + ''' ' 
               END

               -- Date match
               IF @cUDF02 = '2'
               BEGIN 
                  SET @cExecStatements = @cExecStatements + 
                                       ' AND CONVERT( NVARCHAR( 20), ' + @cColumnName + ', 103) = ''' + 
                                       CONVERT( NVARCHAR( 20), CONVERT( DATETIME, @cValue, 103), 103) + ''' '
               END

               SET @cExecArguments = N'@nCount            INT      OUTPUT ' 

               IF @nDebug = 1
               BEGIN
                  PRINT @cExecStatements
                  PRINT @cExecArguments
               END

               EXEC sp_ExecuteSql @cExecStatements
                                , @cExecArguments
                                , @nCount          OUTPUT

               IF ISNULL( @nCount, 0) = 0
               BEGIN
                  SET @nErrNo = 202710
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Inv route code
                  CLOSE CUR_REQ
                  DEALLOCATE CUR_REQ
                  GOTO Quit               
               END

            END

            FETCH_NEXT:
            FETCH NEXT FROM CUR_REQ INTO @cCode, @cNotes, @cUDF01, @cUDF02, @cUDF03
         END
         CLOSE CUR_REQ
         DEALLOCATE CUR_REQ


      END   -- ENTER
   END   -- PALLET CRITERIA
END

Quit:



GO
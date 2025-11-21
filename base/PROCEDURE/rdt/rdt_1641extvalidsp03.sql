SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdt_1641ExtValidSP03                                      */
/* Purpose: Validate Pallet DropID                                            */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2016-03-11 1.0  James    SOS364611 Created                                 */
/******************************************************************************/

CREATE PROC [RDT].[rdt_1641ExtValidSP03] (
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

IF @nFunc = 1641
BEGIN
   DECLARE @cPickSlipNo       NVARCHAR( 10),
           @cOrderKey         NVARCHAR( 10), 
           @cColumnName       NVARCHAR( 20), 
           @cExecStatements   NVARCHAR( 4000), 
           @cExecArguments    NVARCHAR( 4000),
           @cCode             NVARCHAR( 10),
           @cDataType         NVARCHAR( 128),
           @cValue            NVARCHAR( 60),
           @cPrefixLen        NVARCHAR( 60),
           @cUDF01            NVARCHAR( 60),
           @cUDF02            NVARCHAR( 60),
           @cUDF03            NVARCHAR( 60),
           @cUDF04            NVARCHAR( 60),
           @cUDF05            NVARCHAR( 60),
           @cParamLabel1      NVARCHAR( 20),
           @cParamLabel2      NVARCHAR( 20),
           @cParamLabel3      NVARCHAR( 20),
           @cParamLabel4      NVARCHAR( 20),
           @cParamLabel5      NVARCHAR( 20),
           @cPalletCriteria   NVARCHAR( 20),
           @nCount            INT, 
           @nDebug            INT 

   SET @nDebug = 0
   
   DECLARE @cErrMsg1          NVARCHAR( 20),
           @cErrMsg2          NVARCHAR( 20),
           @cErrMsg3          NVARCHAR( 20),
           @cErrMsg4          NVARCHAR( 20),
           @cErrMsg5          NVARCHAR( 20)

   SET @nErrNo = 0

   IF @nStep = 1 -- Drop ID
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         -- Get DropID info
         SELECT
            @cUDF01 = LEFT( ISNULL( UDF01, ''), 20), 
            @cUDF02 = LEFT( ISNULL( UDF02, ''), 20), 
            @cUDF03 = LEFT( ISNULL( UDF03, ''), 20), 
            @cUDF04 = LEFT( ISNULL( UDF04, ''), 20), 
            @cUDF05 = LEFT( ISNULL( UDF05, ''), 20)
         FROM DropID WITH (NOLOCK) 
         WHERE DropID = @cDropID
         
         IF @@ROWCOUNT = 1
         BEGIN
            -- Check pallet criteria different
            IF @cParam1 <> @cUDF01 OR 
               @cParam2 <> @cUDF02 OR 
               @cParam3 <> @cUDF03 OR 
               @cParam4 <> @cUDF04 OR 
               @cParam5 <> @cUDF05
            BEGIN
               -- Get storer config
               SET @cPalletCriteria = rdt.RDTGetConfig( @nFunc, 'PalletCriteria', @cStorerKey)
               IF @cPalletCriteria = '0'
                  SET @cPalletCriteria = ''
      
               -- Get pallet criteria label
               SELECT
                  @cParamLabel1 = UDF01,
                  @cParamLabel2 = UDF02,
                  @cParamLabel3 = UDF03,
                  @cParamLabel4 = UDF04,
                  @cParamLabel5 = UDF05
              FROM dbo.CodeLKUP WITH (NOLOCK)
               WHERE ListName = 'RDTBuildPL'
                  AND Code = @cPalletCriteria
                  AND StorerKey = @cStorerKey
   
               -- Prompt alert
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
                  'WARNING:            ', 
                  'DIFFERENT CRITERIA: ',
                  @cParamLabel1, 
                  @cUDF01, 
                  @cParamLabel2, 
                  @cUDF02, 
                  @cParamLabel3, 
                  @cUDF03, 
                  @cParamLabel4, 
                  @cUDF04 
               SET @nErrNo = 0
            END
         END
      END
   END
   
   IF @nStep = 3 -- UCC Step
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         SET @cPickSlipNo = ''
         SET @cOrderKey = ''

         -- Get PickSlipNo 
         IF rdt.RDTGetConfig( @nFunc, 'CheckPackDetailDropID', @cStorerKey) = '1'
            SELECT @cPickSlipNo = PickSlipNo FROM dbo.PackDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND DropID = @cUCCNo
         ELSE 
            IF rdt.RDTGetConfig( @nFunc, 'CheckPickDetailDropID', @cStorerKey) = '1'
               SELECT @cOrderKey = OrderKey FROM dbo.PickDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND DropID = @cUCCNo
            ELSE
               SELECT @cPickSlipNo = PickSlipNo FROM PackDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND LabelNo = @cUCCNo
         
         -- Get OrderKey
         IF @cPickSlipNo <> '' 
            SELECT @cOrderKey = OrderKey FROM PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo

         IF ISNULL( @cOrderKey, '') = ''
         BEGIN
            SET @nErrNo = 97351
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No OrderKey'
            GOTO Quit
         END                         

         SET @cPalletCriteria = rdt.RDTGetConfig( @nFunc, 'PalletCriteria', @cStorerKey)
   
         -- Check mandatory field
         DECLARE CUR_VALIDATE CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
         SELECT Code, Notes, UDF02
         FROM dbo.CODELKUP WITH (NOLOCK)
         WHERE ListName = 'PLTBLDCRIT'
         AND   StorerKey = @cStorerKey
         AND   ISNULL( UDF02, '') <> '' 
         ORDER BY 1
         OPEN CUR_VALIDATE
         FETCH NEXT FROM CUR_VALIDATE INTO @cCode, @cColumnName, @cUDF02
         WHILE @@FETCH_STATUS <> -1
         BEGIN

            SELECT @cDataType = DATA_TYPE 
            FROM INFORMATION_SCHEMA.COLUMNS 
            WHERE TABLE_NAME = 'Orders' 
            AND COLUMN_NAME = @cColumnName

            IF @cDataType = ''            
            BEGIN
               SET @nErrNo = 0
               SET @cErrMsg1 = '97352'
               SET @cErrMsg2 = 'INVALID COLUMN NAME'
               SET @cErrMsg3 = @cColumnName
               SET @cErrMsg4 = ''
               SET @cErrMsg5 = ''
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
               @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5
               IF @nErrNo = 1
               BEGIN
                  SET @cErrMsg1 = ''
                  SET @cErrMsg2 = ''
                  SET @cErrMsg3 = ''
                  SET @cErrMsg4 = ''
                  SET @cErrMsg5 = ''
               END
               CLOSE CUR_VALIDATE
               DEALLOCATE CUR_VALIDATE
               GOTO Quit
            END                            

            IF @cUDF02 = '2' AND @cDataType <> 'datetime'
            BEGIN
               SET @nErrNo = 0
               SET @cErrMsg1 = '97353'
               SET @cErrMsg2 = 'INVALID COLUMN TYPE'
               SET @cErrMsg3 = @cColumnName
               SET @cErrMsg4 = 'TYPE: ' + @cDataType
               SET @cErrMsg5 = 'REQUIRED: DATETIME'
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
               @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5
               IF @nErrNo = 1
               BEGIN
                  SET @cErrMsg1 = ''
                  SET @cErrMsg2 = ''
                  SET @cErrMsg3 = ''
                  SET @cErrMsg4 = ''
                  SET @cErrMsg5 = ''
               END
               CLOSE CUR_VALIDATE
               DEALLOCATE CUR_VALIDATE
               GOTO Quit               
            END                                        

            SET @cValue = ''
            SET @cValue = CASE 
                          WHEN @cCode = 'UDF01' THEN @cParam1
                          WHEN @cCode = 'UDF02' THEN @cParam2
                          WHEN @cCode = 'UDF03' THEN @cParam3
                          WHEN @cCode = 'UDF04' THEN @cParam4
                          WHEN @cCode = 'UDF05' THEN @cParam5
                          ELSE '' END
            IF @nDebug = 1
            BEGIN
               PRINT @cColumnName
               PRINT @cValue
            END

               IF @nDebug = 1
               BEGIN
                  PRINT @cCode
                  PRINT @cValue
                  PRINT @cPalletCriteria
               END

            -- No velue key in then no validation req
            -- Check blank value in step 1
            IF ISNULL( @cValue, '') = '' AND 
               @cPalletCriteria NOT IN ('', '0')
               GOTO FETCH_NEXT   -- Continue next record to validate

            -- How to validate against Orders 
            IF ISNULL( @cUDF02, '') <> ''
            BEGIN
               SET @cExecStatements = ''
               SET @cExecArguments = ''
               SET @nCount = 0

               SET @cExecStatements = 'SELECT @nCount = 1 ' + 
                                      'FROM dbo.ORDERS WITH (NOLOCK) ' +
                                      'WHERE StorerKey = ''' + RTRIM(@cStorerKey)  + ''' ' +
                                      'AND   OrderKey = ''' + RTRIM(@cOrderKey)  + ''' ' 

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
                  SET @nErrNo = 0
                  SET @cErrMsg1 = '97354'
                  SET @cErrMsg2 = @cColumnName
                  SET @cErrMsg3 = CASE 
                                     WHEN @cUDF02 = '0' THEN 'VALUE NOT MATCH.'
                                     WHEN @cUDF02 = '1' THEN 'PREFIX NOT MATCH.'
                                     WHEN @cUDF02 = '2' THEN 'VALUE NOT MATCH.'
                                  END
                  SET @cErrMsg4 = ''
                  SET @cErrMsg5 = ''
                  EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
                  @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5
                  IF @nErrNo = 1
                  BEGIN
                     SET @cErrMsg1 = ''
                     SET @cErrMsg2 = ''
                     SET @cErrMsg3 = ''
                     SET @cErrMsg4 = ''
                     SET @cErrMsg5 = ''
                  END
                  CLOSE CUR_VALIDATE
                  DEALLOCATE CUR_VALIDATE
                  GOTO Quit
               END
            END

            FETCH_NEXT:
            FETCH NEXT FROM CUR_VALIDATE INTO @cCode, @cColumnName, @cUDF02
         END
         CLOSE CUR_VALIDATE
         DEALLOCATE CUR_VALIDATE               
      END   -- -- ENTER
   END   -- UCC STEP

   IF @nStep = 5 -- PALLET CRITERIA
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         -- Check mandatory field
         DECLARE CUR_REQ CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
         SELECT Code, Notes, UDF01, UDF02
         FROM dbo.CODELKUP WITH (NOLOCK)
         WHERE ListName = 'PLTBLDCRIT'
         AND   StorerKey = @cStorerKey
         AND   (ISNULL( UDF01, '') <> '' OR 
                ISNULL( UDF02, '') <> '')
         ORDER BY 1
         OPEN CUR_REQ
         FETCH NEXT FROM CUR_REQ INTO @cCode, @cColumnName, @cUDF01, @cUDF02
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            SET @cValue = ''
            SET @cValue = CASE 
                          WHEN @cCode = 'UDF01' THEN @cParam1
                          WHEN @cCode = 'UDF02' THEN @cParam2
                          WHEN @cCode = 'UDF03' THEN @cParam3
                          WHEN @cCode = 'UDF04' THEN @cParam4
                          WHEN @cCode = 'UDF05' THEN @cParam5
                          ELSE '' END
            IF @nDebug = 1
            BEGIN
               PRINT @cColumnName
               PRINT @cValue
            END
            
            -- Check empty
            IF ISNULL( @cUDF01, '') = '1' AND ISNULL( @cValue, '') = ''
            BEGIN
               SET @nErrNo = 0
               SET @cErrMsg1 = '97355'
               SET @cErrMsg2 = @cColumnName
               SET @cErrMsg3 = 'IS REQUIRED BUT'
               SET @cErrMsg4 = 'NOW IS EMPTY.'
               SET @cErrMsg5 = ''
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
               @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5
               IF @nErrNo = 1
               BEGIN
                  SET @cErrMsg1 = ''
                  SET @cErrMsg2 = ''
                  SET @cErrMsg3 = ''
                  SET @cErrMsg4 = ''
                  SET @cErrMsg5 = ''
               END
               CLOSE CUR_REQ
               DEALLOCATE CUR_REQ
               GOTO Quit
            END   --Check empty

            IF ISNULL( @cUDF02, '') = '2' AND ISNULL( @cValue, '') <> ''
            BEGIN
               IF rdt.rdtIsValidDate( @cValue) = 0
               BEGIN
                  SET @nErrNo = 97356
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid date
                  CLOSE CUR_REQ
                  DEALLOCATE CUR_REQ
                  GOTO Quit               
               END            
            END

            FETCH NEXT FROM CUR_REQ INTO @cCode, @cColumnName, @cUDF01, @cUDF02
         END
         CLOSE CUR_REQ
         DEALLOCATE CUR_REQ
      END   -- ENTER
   END   -- PALLET CRITERIA
END

Quit:



GO
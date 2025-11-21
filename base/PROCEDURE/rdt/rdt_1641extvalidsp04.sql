SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/    
/* Store procedure: rdt_1641ExtValidSP04                                      */    
/* Purpose: Validate Pallet DropID                                            */    
/*                                                                            */    
/* Modifications log:                                                         */    
/*                                                                            */    
/* Date       Rev  Author   Purposes                                          */    
/* 2016-06-07 1.0  James    SOS370791 Created                                 */    
/* 2020-10-28 1.1  YeeKung  WMS-15617 Add Validation(yeekung01)               */ 
/* 2020-11-20 1.2  YeeKung  Tune the performance (yeekung02)                  */     
/* 2022-12-20 1.3  YeeKung  Tune the performance (yeekung03)                  */   
/* 2022-12-20 1.4  YeeKung  Tune the performance (yeekung03)                  */   
/******************************************************************************/    
    
CREATE    PROC [RDT].[rdt_1641ExtValidSP04] (    
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
           @cUDF04            NVARCHAR( 60),    
           @cUDF05            NVARCHAR( 60),    
           @cParamLabel1      NVARCHAR( 20),    
           @cParamLabel2      NVARCHAR( 20),    
           @cParamLabel3      NVARCHAR( 20),    
           @cParamLabel4      NVARCHAR( 20),    
           @cParamLabel5      NVARCHAR( 20),    
           @cPalletCriteria   NVARCHAR( 20),    
           @cNotes            NVARCHAR( 60),    
           @cRoute            NVARCHAR( 30),    
           @cCurRoute         NVARCHAR( 30),    
           @cCaseID           NVARCHAR( 20),    
           @nCount            INT,     
           @nDebug            INT,     
           @nStart            INT,    
           @nLen              INT    
    
   SET @nDebug = 0    
       
   DECLARE @cErrMsg1          NVARCHAR( 20),    
           @cErrMsg2          NVARCHAR( 20),    
           @cErrMsg3          NVARCHAR( 20),    
           @cErrMsg4          NVARCHAR( 20),    
           @cErrMsg5          NVARCHAR( 20)    
    
--if suser_sname() = 'wmsgt'    
--set @nDebug = 1    
    
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
            SET @nErrNo = 101051    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Pallet closed    
            GOTO Quit       
         END    
      END    
   END    
    
   IF @nStep = 3 -- UCC    
   BEGIN    
      IF @nInputKey = 1 -- ENTER    
      BEGIN    
         SELECT TOP 1 @cRoute = RefNo2    
         FROM dbo.PackDetail WITH (NOLOCK)    
         WHERE StorerKey = @cStorerKey    
         AND   RefNo = @cUCCNo    
    
         IF ISNULL( @cRoute, '') = ''    
         BEGIN    
            SET @nErrNo = 101052    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Inv carton id    
            GOTO Quit                   
         END    
    
         IF EXISTS ( SELECT 1 FROM dbo.PackDetail PD WITH (NOLOCK)    
            join Packheader PH (NOLOCK) ON PD.PickSlipNo=PH.PickSlipNo    
            WHERE PD.StorerKey = @cStorerKey    
            AND   PD.RefNo = @cUCCNo    
            AND   PH.[Status] NOT IN ('9'))    
         BEGIN    
            SET @nErrNo = 101060    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --  OrderNotPacked   
            GOTO Quit                   
         END    
    
         IF EXISTS ( SELECT 1 FROM dbo.PalletDetail WITH (NOLOCK)    
                     WHERE StorerKey = @cStorerKey    
                     AND   CaseID = @cUCCNo    
                     AND  [Status] < '9')    
         BEGIN    
            SET @nErrNo = 101053    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- carton scan b4    
            GOTO Quit                   
         END    
  
         IF EXISTS ( SELECT 1 FROM dbo.PalletDetail WITH (NOLOCK)    
            WHERE StorerKey = @cStorerKey    
            AND   CaseID = @cUCCNo  
            AND  [Status] ='9')    
         BEGIN    
            SET @nErrNo = 101061    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- carton scan b4    
            GOTO Quit                   
         END   
    
             
         IF EXISTS (SELECT 1 FROM dbo.PalletDetail PAD WITH (NOLOCK)        --(yeekung02)                                
                     WHERE PAD.PalletKey <> @cDropID      
                        AND EXISTS ( select 1
                                    from packheader PH(nolock)
                                    join packdetail PD (nolock)
                                    on PH.pickslipno=PD.pickslipno AND PH.storerkey=PD.storerkey
                                    where  PD.refno=@cUCCNo
                                    AND PD.refno <> ''
                                    AND PD.storerkey=@cstorerkey
                                    AND PAD.UserDefine02 = PH.orderkey
                                    )    
                        AND PAD.storerkey=@cstorerkey       )   
         BEGIN    
            SET @nErrNo = 101059    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- OrderinMultiID   
            GOTO Quit                   
         END    
    
         -- Existing route    
         SELECT TOP 1 @cCurRoute = UserDefine01    
         FROM dbo.PalletDetail WITH (NOLOCK)    
         WHERE StorerKey = @cStorerKey    
         AND   PalletKey = @cDropID    
         AND   [Status] < '9'    
    
         -- Not 1st time scan carton    
         IF ISNULL( @cCurRoute, '') <> ''    
         BEGIN    
            IF ISNULL( @cCurRoute, '') <> ISNULL( @cRoute, '')    
            BEGIN    
               SET @nErrNo = 101054    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Wrong route    
               GOTO Quit                   
            END    
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
               SET @nErrNo = 101055    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Inv field name    
               CLOSE CUR_REQ    
               DEALLOCATE CUR_REQ    
               GOTO Quit                   
            END                                
    
            IF @cUDF02 = '2' AND @cDataType <> 'datetime'    
            BEGIN    
               SET @nErrNo = 101056    
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
               SET @nErrNo = 101057    
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
                  SET @nErrNo = 101058    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Inv route code    
                  CLOSE CUR_REQ    
                  DEALLOCATE CUR_REQ    
                  GOTO Quit                   
               END    
    
            END    
    
            /*    
            -- Extra validation    
            -- Check valid route code    
            IF @cCode = 'REFNO2'    
            BEGIN    
               IF NOT EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)    
                               WHERE StorerKey = @cStorerKey    
                               AND   REFNO2 = @cValue)    
               BEGIN    
                  SET @nErrNo = 101056    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Inv route code    
                  CLOSE CUR_REQ    
                  DEALLOCATE CUR_REQ    
                  GOTO Quit                   
               END    
            END    
            */    
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
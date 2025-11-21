SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
          
/******************************************************************************/                
/* Store procedure: rdt_1641ExtValidSP14                                      */                
/* Purpose: Validate Pallet DropID                                            */                
/*                                                                            */                
/* Modifications log:                                                         */                
/*                                                                            */                
/* Date       Rev  Author   Purposes                                          */                 
/* 2020-01-05 1.0  YeeKung  WMS15919 Created                                  */  
/* 2021-05-24 1.1  YeeKung  WMS-17087  Add codelkup in delivery mode (yeekung01)*/   
/* 2023-02-22 1.2  YeeKung  WMS-21797 add insertmsgqueue (yeekung02)          */
/******************************************************************************/                
                
CREATE   PROC [RDT].[rdt_1641ExtValidSP14] (                  
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
           @nLen              INT,    
           @cCartontype       NVARCHAR (20) ,    
           @cCartonNo         NVARCHAR( 20),
           @cPalletType       NVARCHAR( 20)


    DECLARE @cOtherPallet     NVARCHAR(20),
            @cOtherPalletType      NVARCHAR(20)
                  
   SET @nDebug = 0                  
                     
   DECLARE  @cErrMsg1          NVARCHAR( 20),                  
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
            SET @nErrNo = 163601                  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Pallet closed                  
            GOTO Quit                                 
         END                  
      END                  
   END                  
                  
   IF @nStep = 3 -- UCC               
   BEGIN                  
      IF @nInputKey = 1 -- ENTER                  
      BEGIN                  
         SELECT TOP 1 @cRoute = RefNo2,        
                      @cPickSlipNo = PickSlipNo 
         FROM dbo.PackDetail WITH (NOLOCK)                  
         WHERE StorerKey = @cStorerKey                         
         AND   RefNo = @cUCCNo     
         
         SELECT @cCartontype=cartontype    
         FROM dbo.packinfo (NOLOCK)    
         where pickslipno=@cpickslipno  

         SELECT @cPalletType = pallettype
         FROM Pallet (NOLOCK)
         WHERE storerkey=@cStorerKey 
            AND PalletKey=@cDropID

                  
         IF ISNULL( @cRoute, '') = ''                  
         BEGIN                  
            SET @nErrNo = 163602                  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Inv carton id                  
            GOTO Quit                                 
         END       
           
         IF NOT EXISTS (SELECT 1 FROM dbo.PackHeader PH   
            WHERE pickslipno=@cPickSlipNo  
            AND storerkey=@cStorerKey  
            AND status IN ('9'))  
         BEGIN                
            SET @nErrNo = 163615                
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Pack Not completed               
            GOTO Quit                               
         END            
                         
         IF @cRoute='JPYamato'    --(yeekung02)            
         BEGIN                  
                
            IF EXISTS (SELECT 1 FROM dbo.PackDetail PD WITH (NOLOCK)                 
                     JOIN dbo.sku SKU WITH (NOLOCK) ON SKU.SKU=PD.SKU              
                        AND PD.storerkey=SKU.storerkey  --(yeekung02)            
                     WHERE  PD.StorerKey = @cStorerKey                  
                        AND   PD.RefNo = @cUCCNo                  
                        AND   SKU.itemclass='LIQUID')  --(yeekung01)                
            BEGIN                       
               IF (SUBSTRING(@cdropid,1,4) NOT IN ('PTHL','PBEL'))   --(yeekung04)             
               BEGIN                
                  SET @nErrNo = 163610                
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- invalid Pallet                
                  GOTO Quit                 
               END                   
            END                
            ELSE                
            BEGIN                
               IF (SUBSTRING(@cdropid,1,4)IN ('PTHL','PBEL'))    --yeekung04            
               BEGIN                
                  SET @nErrNo = 163611                
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- invalid Pallet                 
                  GOTO Quit                   
               END                
            END                
         END                
         ELSE                
         BEGIN                    
            IF (SUBSTRING(@cdropid,1,4)IN('PTHL','PBEL'))     --yeekung04           
            BEGIN                
               SET @nErrNo = 163612                
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- invalid Pallet                 
               GOTO Quit                   
            END                
         END                
                
                  
         IF EXISTS ( SELECT 1 FROM dbo.PalletDetail WITH (NOLOCK)                  
                     WHERE StorerKey = @cStorerKey                  
                     AND   CaseID = @cUCCNo                  
                     AND  [Status] < '9')                  
         BEGIN                  
            SET @nErrNo = 163603                  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- carton scan b4  


            SELECT @cOtherPallet=Palletkey
            FROM dbo.PalletDetail WITH (NOLOCK)                  
            WHERE StorerKey = @cStorerKey                  
            AND   CaseID = @cUCCNo                  
            AND  [Status] < '9'

            SELECT @cOtherPalletType = pallettype
            FROM Pallet (NOLOCK)
            WHERE storerkey=@cStorerKey 
               AND PalletKey=@cOtherPallet
            
            SET @cErrMsg1 = 'S2'
                           +'^'+SUBSTRING(@cOtherPallet,1,1)+SUBSTRING(@cOtherPallet,4,6)
                           +'^'+ CASE WHEN ISNULL(@cOtherPalletType,'') ='MIX' THEN 'MIX' 
                                 ELSE SUBSTRING (@cCartontype,1,1) + RIGHT(@cCartontype,2)  END
            
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,  --(yeekung02)  
            @cErrMsg,  
            @cErrMsg1,
            '',
            '',
            '',
            '',
            '',
            '',
            '',
            '',
            '',
            '',
            '',
            ''

            GOTO Quit                                 
         END                  
                  
         -- carton exists in another closed pallet, prompt error         
         IF EXISTS ( SELECT 1 FROM dbo.PALLETDETAIL WITH (NOLOCK)                  
                     WHERE StorerKey = @cStorerKey                  
                     AND   CaseID = @cUCCNo                  
                     AND   [Status] = '9'                  
                     AND   PalletKey <> @cDropID)                  
         BEGIN                  
            SET @nErrNo = 163604                  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- carton scan b4   
            
            SELECT @cOtherPallet=Palletkey
            FROM dbo.PalletDetail WITH (NOLOCK)                  
            WHERE StorerKey = @cStorerKey                  
            AND   CaseID = @cUCCNo                  
            AND  [Status] < '9'

            SELECT @cOtherPalletType = pallettype
            FROM Pallet (NOLOCK)
            WHERE storerkey=@cStorerKey 
               AND PalletKey=@cOtherPallet
            
            SET @cErrMsg1 = 'S2'
               +'^'+SUBSTRING(@cOtherPallet,1,1)+SUBSTRING(@cOtherPallet,4,6)
               +'^'+ CASE WHEN ISNULL(@cOtherPalletType,'') ='MIX' THEN 'MIX' 
                     ELSE SUBSTRING (@cCartontype,1,1) + RIGHT(@cCartontype,2)  END
            
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,  --(yeekung02)  
            @cErrMsg,  
            @cErrMsg1,
            '',
            '',
            '',
            '',
            '',
            '',
            '',
            '',
            '',
            '',
            '',
            ''
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
               SET @nErrNo = 163605                  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Wrong route                  
               GOTO Quit                                 
            END                  
         END                
                 
         SELECT @cOrderKey = OrderKey  --(yeekung03)        
         FROM dbo.PackHeader WITH (NOLOCK)          
         WHERE StorerKey = @cStorerKey          
         AND   PickSlipNo = @cPickSlipNo           
                 
         IF EXISTS (SELECT 1 from pallet (NOLOCK) WHERE storerkey=@cStorerKey AND PalletKey=@cDropID)        
         BEGIN        
            IF ISNULL(OBJECT_ID('tempdb..#temp_deliverymode'), '') <> ''             
            BEGIN                   
               DROP TABLE #temp_deliverymode             
            END             
            
            CREATE TABLE #temp_deliverymode (                
               RowRef INT IDENTITY (1,1) NOT NULL,   
               long NVARCHAR(20),                
               short NVARCHAR(20),                
               UDF01 nvarchar(20),                
               UDF02 nvarchar(20),                
               UDF03 NVARCHAR(20),                
               UDF04 NVARCHAR(20),                
               UDF05 NVARCHAR(20)             
             ) 

            INSERT INTO #temp_deliverymode(long,short,UDF01,UDF02,UDF03,UDF04,UDF05)  
            SELECT long,short,CD.UDF01,CD.UDF02,CD.UDF03,CD.UDF04,CD.UDF05  
            FROM orderinfo OI (NOLOCK) LEFT JOIN codelkup CD (NOLOCK)  
            ON (OI.DeliveryMode=CD.Long OR OI.DeliveryMode=CD.short OR OI.DeliveryMode=CD.UDF01 OR OI.DeliveryMode=CD.udf02  
               OR OI.DeliveryMode=CD.udf03  OR OI.DeliveryMode=CD.udf04 OR OI.DeliveryMode=CD.udf05)  
            WHERE oi.OrderKey=@cOrderKey  
            AND listname = 'THGCUSVCID'   
            and code = 'CUSERVICEID'   
            AND cd.Storerkey=@cStorerKey  
  
            IF EXISTS (SELECT 1 from PALLETDETAIL pd(NOLOCK)   
                        WHERE pd.palletkey=@cDropID        
                           AND pd.StorerKey=@cStorerKey     
                           AND NOT EXISTS (SELECT 1 FROM #temp_deliverymode (NOLOCK)   
                                           WHERE pd.UserDefine03=long or pd.UserDefine03=short  
                                           or pd.UserDefine03=udf01 or pd.UserDefine03=udf02   
                                           or pd.UserDefine03 =udf03 or pd.UserDefine03=UDF04  
                                           or pd.UserDefine03=udf05)   
                      )   
            BEGIN        
               SET @nErrNo = 163613                  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- carton scan b4                  
               GOTO Quit          
            END        
         END        
    
         IF NOT EXISTS (SELECT 1 FROM PALLET (NOLOCK) WHERE PALLETTYPE='MIX' AND storerkey=@cStorerKey AND PalletKey=@cDropID)    
         BEGIN      
    
            SELECT TOP 1 @cCartonNo=caseid     
            from palletdetail (NOLOCK)    
            WHERE storerkey=@cStorerKey     
            AND PalletKey=@cDropID    
    
            IF EXISTS (SELECT 1 from       
                       PACKDETAIL PD(NOLOCK) JOIN     
                       PACKINFO PIF (NOLOCK)    
                       ON PD.pickslipno=PIF.pickslipno    
                       WHERE PD.storerkey=@cstorerkey    
                       AND PD.RefNo = @cCartonNo      
                       AND PIF.cartontype<>@cCartontype)    
            BEGIN                  
               SET @nErrNo = 163614                 
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
               SET @nErrNo = 163606                  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Inv field name                  
               CLOSE CUR_REQ                  
               DEALLOCATE CUR_REQ                  
               GOTO Quit                                 
            END                                              
                  
            IF @cUDF02 = '2' AND @cDataType <> 'datetime'                  
            BEGIN                  
               SET @nErrNo = 163607                  
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
               SET @nErrNo = 163608                  
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
                  
               -- Date match             IF @cUDF02 = '2'                  
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
                  SET @nErrNo = 163609                  
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
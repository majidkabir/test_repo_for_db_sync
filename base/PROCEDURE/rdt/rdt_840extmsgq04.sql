SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
 
/************************************************************************/      
/* Store procedure: rdt_840ExtMsgQ04                                    */      
/* Copyright: LF Logistics                                              */      
/*                                                                      */      
/* Date       Rev  Author     Purposes                                  */      
/* 2023-03-21 1.0  yeekung    WMS-21979. Created                        */      
/************************************************************************/      
      
CREATE    PROC [RDT].[rdt_840ExtMsgQ04] (      
   @nMobile          INT,      
   @nFunc            INT,      
   @cLangCode        NVARCHAR( 3),      
   @nStep            INT,      
   @nAfterStep       INT,      
   @nInputKey        INT,      
   @cStorerkey       NVARCHAR( 15),      
   @cOrderKey        NVARCHAR( 10),      
   @cPickSlipNo      NVARCHAR( 10),      
   @cTrackNo         NVARCHAR( 20),      
   @cSKU             NVARCHAR( 20),      
   @nCartonNo        INT,      
   @nErrNo           INT           OUTPUT,      
   @cErrMsg          NVARCHAR( 20) OUTPUT      
)      
AS      
   SET NOCOUNT ON      
   SET QUOTED_IDENTIFIER OFF      
   SET ANSI_NULLS OFF      
      
   DECLARE  @nFragileChk   INT,      
            @nPackaging    INT,      
            @nVAS          INT,              
            @cBUSR4        NVARCHAR( 20),      
            @cOVAS         NVARCHAR( 20),      
            @cUDF01        NVARCHAR( 60),      
            @cDescr        NVARCHAR( 250),      
            @dOrderDate    DATETIME,
            @cLottable01   NVARCHAR( 20)
      
   DECLARE @cLine01        NVARCHAR( 20),      
           @cLine02        NVARCHAR( 20),      
           @cLine03        NVARCHAR( 20),      
           @cLine04        NVARCHAR( 20),      
           @cLine05        NVARCHAR( 20),      
           @cLine06        NVARCHAR( 20),      
           @cLine07        NVARCHAR( 20),      
           @cLine08        NVARCHAR( 20),      
           @cLine09        NVARCHAR( 20),      
           @cLine10        NVARCHAR( 20),      
           @cLine11        NVARCHAR( 20),      
           @cLine12        NVARCHAR( 20),      
           @cLine13        NVARCHAR( 20),      
           @cLine14        NVARCHAR( 20),      
           @cLine15        NVARCHAR( 20)      
      
      SET @cLine01 = ''      
      SET @cLine02 = ''      
      SET @cLine03 = ''      
      SET @cLine04 = ''      
      SET @cLine05 = ''      
      SET @cLine06 = ''      
      SET @cLine07 = ''      
      SET @cLine08 = ''      
      SET @cLine09 = ''      
      SET @cLine10 = ''      
      SET @cLine11 = ''      
      SET @cLine12 = ''      
      SET @cLine13 = ''      
      SET @cLine14 = ''      
      SET @cLine15 = ''      
      
   IF @nFunc = 840 -- Pack by track no      
   BEGIN      
      IF @nStep = 1      
      BEGIN      
         -- (james01)      
         IF EXISTS ( SELECT 1 FROM dbo.ORDERDETAIL OD WITH (NOLOCK)      
                     JOIN dbo.SKU WITH (NOLOCK) ON ( OD.Sku = SKU.Sku AND OD.StorerKey = SKU.StorerKey)      
                     WHERE OD.OrderKey = @cOrderKey      
                     AND   OD.StorerKey = @cStorerKey      
                     AND   SKU.SUSR3 = '2')      
         BEGIN      
            SET @cLine01 = rdt.rdtgetmessage( 198006, @cLangCode, 'DSP')      
      
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cLine01      
            SET @nErrNo = 0   -- Reset error no      
         END      
      END      
      
      IF @nStep = 2      
      BEGIN      
         SET @nFragileChk = 0      
      
         IF rdt.RDTGetConfig( @nFunc, 'FRAGILECHK', @cStorerKey) = 1 AND      
            EXISTS ( SELECT 1 FROM dbo.Orders WITH (NOLOCK)      
                     WHERE [Stop] = 'Y'      
             AND   OrderKey = @cOrderKey      
                     AND   StorerKey = @cStorerKey)      
         BEGIN      
            SET @nErrNo = 0      
            SET @cLine01 = rdt.rdtgetmessage( 198001, @cLangCode, 'DSP')      
            SET @cLine02 = rdt.rdtgetmessage( 198002, @cLangCode, 'DSP')      
            SET @cLine03 = rdt.rdtgetmessage( 198003, @cLangCode, 'DSP')      
      
            SET @nFragileChk = 1      
         END      
      
         -- Nothing to display then no need display msg queue      
         IF @nFragileChk = 0      
            GOTO Quit      
      
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,      
            @cLine01, @cLine02, @cLine03, @cLine04, @cLine05      
         SET @nErrNo = 0   -- Reset error no      
      END      
      
      IF @nStep = 3      
      BEGIN      
         DECLARE @cCompany NVARCHAR(20)      
         DECLARE @cVASKey   NVARCHAR(20)      
         DECLARE @cVAS      NVARCHAR(20)      
         DECLARE @cPrev_VAS NVARCHAR(20)   = ''
         DECLARE @cRefDescr NVARCHAR(60)      
         DECLARE @cUserdefine01 NVARCHAR(60)      
         DECLARE @cUserdefine02 NVARCHAR(60)      
         DECLARE @cUserdefine03 NVARCHAR(60)      
         DECLARE @cUserdefine04 NVARCHAR(60)      
         DECLARE @cUserdefine05 NVARCHAR(60)      
         DECLARE @cRefOpt     NVARCHAR(20) = ''  
         DECLARE @nExpectedQty INT
         DECLARE @nPackedQty INT
      
         SET @nPackaging = 0      
      
         SET @cLine01 = ''      
         SET @cLine02 = ''      
         SET @cLine03 = ''      
         SET @cLine04 = ''      
         SET @cLine05 = ''      
         SET @cLine06 = ''      
         SET @cLine07 = ''      
         SET @cLine08 = ''      
         SET @cLine09 = ''      
         SET @cLine10 = ''      
         SET @cLine11 = ''      
         SET @cLine12 = ''      
         SET @cLine13 = ''      
         SET @cLine14 = ''      
         SET @cLine15 = ''  
         SET @cVAS      ='N'  

         SET @nExpectedQty = 0  
         SELECT @nExpectedQty = ISNULL(SUM(Qty), 0) FROM PickDetail WITH (NOLOCK)  
         WHERE Orderkey = @cOrderkey  
            AND Storerkey = @cStorerkey  
            AND Status < '9'  
  
         SET @nPackedQty = 0  
         SELECT @nPackedQty = ISNULL(SUM(Qty), 0) FROM dbo.PackDetail WITH (NOLOCK)  
         WHERE PickSlipNo = @cPickSlipNo  
  
               
      
         SELECT @dOrderDate = ISNULL( OrderDate, 0),      
                @cCompany   = ISNULL(C_Company,'')      
         FROM dbo.Orders WITH (NOLOCK)      
         WHERE StorerKey = @cStorerKey      
         AND   OrderKey = @cOrderKey      
      
         SELECT @cBUSR4 = BUSR4,      
                @cOVAS = OVAS      
         FROM dbo.SKU WITH (NOLOCK)      
         WHERE StorerKey = @cStorerkey      
         AND   SKU = @cSKU      
         
         IF @nPackedQty = @nExpectedQty
         BEGIN
            IF EXISTS (SELECT 1 FROM VAS WHERE storerkey =@cStorerkey and Brand =@cCompany)      
            BEGIN      
      
               DECLARE CUR_VAS CURSOR LOCAL READ_ONLY FAST_FORWARD FOR           
               SELECT VAS.Vaskey      
               FROM dbo.VAS VAS WITH (NOLOCK)          
               WHERE VAS.StorerKey = @cStorerKey          
                  AND VAS.Brand =@cCompany          
               ORDER BY VAS.VASKey      
               OPEN CUR_VAS          
               FETCH NEXT FROM CUR_VAS INTO @cVASKey      
               WHILE @@FETCH_STATUS <> -1          
               BEGIN      
                  SET @cPrev_VAS =''  
                  DECLARE CUR_VASDTL CURSOR LOCAL READ_ONLY FAST_FORWARD FOR        
                  SELECT RefDescr, UserDefine01, UserDefine02,UserDefine03,UserDefine04,UserDefine05        
                  FROM  dbo.VASDetail VDTL WITH (NOLOCK)       
                  WHERE  Vaskey =  @cVASKey        
                  OPEN CUR_VASDTL          
                  FETCH NEXT FROM CUR_VASDTL INTO @cRefDescr, @cUserdefine01, @cUserdefine02,@cUserdefine03,@cUserdefine04,@cUserdefine05          
                  WHILE @@FETCH_STATUS <> -1          
                  BEGIN      
                     SET @cRefOpt = 0      
  
                     IF @cRefDescr='PRICE'      
                     BEGIN      
                        IF EXISTS ( SELECT 1      
                                    FROM dbo.Orders WITH (NOLOCK)      
                                    WHERE StorerKey = @cStorerKey      
                                    AND   OrderKey = @cOrderKey      
                                    AND UserDefine05 - CASE WHEN ISNUMERIC(USERDEFINE02)=1 THEN USERDEFINE02 ELSE 0 END >@cUserdefine01)  
                        BEGIN      
                           SET @cVAS='Y'
                        END      
                        ELSE      
                        BEGIN      
                           SET @cVAS='N'      
                        END      
                     END      
                    
                     IF @cRefDescr='Date'      
                     BEGIN      
                        IF ISNULL(@cUserdefine02,'')=''      
                        BEGIN      
                           IF EXISTS ( SELECT 1      
                              FROM dbo.Orders WITH (NOLOCK)      
                              WHERE StorerKey = @cStorerKey      
                                 AND OrderKey = @cOrderKey      
                                 AND CONVERT(DATETIME,Orderdate) > CONVERT(DATETIME,@cUserdefine01))        
                           BEGIN      
                              SET @cVAS='Y'    
                           END      
                           ELSE      
                           BEGIN      
                              SET @cVAS='N'      
                           END      
                        END      
                        ELSE      
                        BEGIN      
                              IF EXISTS ( SELECT 1      
                              FROM dbo.Orders WITH (NOLOCK)      
                              WHERE StorerKey = @cStorerKey      
                                 AND OrderKey = @cOrderKey      
                                 AND (CONVERT(DATETIME,Orderdate) > CONVERT(DATETIME,@cUserdefine01)      
                                 AND CONVERT(DATETIME,Orderdate)   < CONVERT(DATETIME,@cUserdefine02))) 
                           BEGIN      
                              SET @cVAS='Y'  
                           END      
                           ELSE      
                           BEGIN      
                              SET @cVAS='N'      
                           END      
                        END      
                     END      
                    
                     IF @cRefDescr='SKU'      
                     BEGIN                       
                        IF EXISTS ( SELECT 1      
                           FROM dbo.Orderdetail OD  WITH (NOLOCK)      
                           WHERE orderkey = @cOrderKey        
                           AND SKU = @cUserdefine01
                           AND Storerkey = @cStorerkey)         
                        BEGIN      
                           SET @cVAS='Y'   
                        END      
                        ELSE      
                        BEGIN      
                           SET @cVAS='N'   
                        END      
                     END      
                    
                     IF @cRefDescr='PC'      
                     BEGIN      
                        IF EXISTS ( SELECT 1      
                           FROM dbo.Orderdetail WITH (NOLOCK)      
                           WHERE  orderkey = @cOrderKey        
                           AND ISNULL(LOTTABLE01,'')<>'')          
                        BEGIN      
                           SET @cVAS='Y'      
                           SET @cRefOpt ='1'      
                        END      
                        ELSE      
                        BEGIN      
                           SET @cVAS='N'      
                        END      
                     END      
                    
                     IF @cRefDescr='ORDER'      
                     BEGIN     
                        IF EXISTS ( SELECT 1      
                           FROM dbo.Orders WITH (NOLOCK)      
                           WHERE  orderkey = @cOrderKey        
                           AND MarkForKey = @cUserdefine02)       
                        BEGIN      
                           SET @cVAS='Y'                          
                        END      
                        ELSE      
                        BEGIN      
                           SET @cVAS='N'      
                        END      
                     END      
                    
                     IF      @cPrev_VAS='' AND @cVAS ='Y' BEGIN SET @cVAS ='Y' END  
                     ELSE IF @cPrev_VAS='Y' AND @cVAS ='Y' BEGIN SET @cVAS ='Y' END  
                     ELSE IF @cPrev_VAS='Y' AND @cVAS ='N' BEGIN SET @cVAS ='N' END  
                     ELSE IF @cPrev_VAS='N' AND @cVAS ='Y' BEGIN SET @cVAS ='N' END  
                     ELSE                                  BEGIN SET @cVAS ='N' END  
                    
                     SET @cPrev_VAS=@cVAS   
                    
                     FETCH NEXT FROM CUR_VASDTL INTO @cRefDescr, @cUserdefine01, @cUserdefine02,@cUserdefine03,@cUserdefine04,@cUserdefine05          
                  END      
                 
                  CLOSE CUR_VASDTL      
                  DEALLOCATE CUR_VASDTL    
               
                  IF @cVAS='Y'      
                  BEGIN      
                     SET @cLine14='1'      
      
                     IF @cRefOpt='1'      
                     BEGIN      
                        SELECT TOP 1 @cLine01=step       
                        FROM VASDETAIL (NOLOCK)      
                        WHERE VASKEY = @cVASKey      
                           
                        SELECT @cLine02=OrdSpecHdlgCode       
                        FROM VAS (NOLOCK)      
                        WHERE VASKEY = @cVASKey    
                        
                        SET @cLine04 = '%I_Field'      
      
                        DECLARE CUR_ODetail CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
                        SELECT Lottable01       
                        FROM OrderDetail (NOLOCK)      
                        WHERE Orderkey = @cOrderKey      
                           AND Storerkey = @cStorerkey 
                           AND ISNULL(Lottable01,'') <> ''
                        OPEN CUR_ODetail          
                        FETCH NEXT FROM CUR_ODetail INTO @cLottable01
                        WHILE @@FETCH_STATUS <> -1          
                        BEGIN      
                           EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,      
                           @cLine01, @cLine02, @cLottable01, @cLine04, '',      
                           '', '', '', '', '',      
                           '', '', '', @cLine14      
                           SET @nErrNo = 0   -- Reset error no 

                           FETCH NEXT FROM CUR_ODetail INTO @cLottable01
                        END

                        CLOSE CUR_ODetail      
                        DEALLOCATE CUR_ODetail    
                     END      
                     ELSE      
                     BEGIN      
                        SELECT TOP 1 @cLine01=step       
                        FROM VASDETAIL (NOLOCK)      
                        WHERE VASKEY = @cVASKey      
                           
                        SELECT @cLine03=OrdSpecHdlgCode       
                        FROM VAS (NOLOCK)      
                        WHERE VASKEY = @cVASKey      
      
                        SET @cLine04 = '%I_Field'    

                        EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,      
                        @cLine01, @cLine02, @cLine03, @cLine04, '',      
                        '', '', '', '', '',      
                        '', '', '', @cLine14      
                        SET @nErrNo = 0   -- Reset error no    
                     END      

  
                  END     
  
                  FETCH NEXT FROM CUR_VAS INTO @cVASKey
                  

               END
      
            END    
         END
      END      
   END      
      
QUIT: 

GO
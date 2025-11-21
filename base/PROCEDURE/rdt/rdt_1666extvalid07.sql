SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
            
/************************************************************************/      
/* Store procedure: rdt_1666ExtValid07                                  */      
/*                                                                      */      
/* Modifications log:                                                   */     
/* Copy from rdt_1666ExtValid01 ->rdt_1666ExtValid07                    */
/*                                                                      */      
/* Date        Rev  Author      Purposes                                */      
/* 2023-02-27  1.0  yeekung     WMS-21839 Created                       */      
/************************************************************************/      
      
CREATE   PROC [RDT].[rdt_1666ExtValid07] (      
   @nMobile        INT,      
   @nFunc          INT,      
   @cLangCode      NVARCHAR( 3),      
   @nStep          INT,      
   @nInputKey      INT,      
   @cFacility      NVARCHAR( 5),      
   @cStorerKey     NVARCHAR( 15),      
   @tExtValidate   VariableTable READONLY,      
   @nErrNo         INT           OUTPUT,      
   @cErrMsg        NVARCHAR( 20) OUTPUT      
)      
AS      
BEGIN      
   SET NOCOUNT ON      
   SET QUOTED_IDENTIFIER OFF      
   SET ANSI_NULLS OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF      
      
   DECLARE @cMbolKey       NVARCHAR( 10)      
   DECLARE @cOrderKey      NVARCHAR( 10)      
   DECLARE @cOtherMbolKey  NVARCHAR( 10)      
   DECLARE @cPalletID      NVARCHAR( 30)      
   DECLARE @cStatus        NVARCHAR( 10)      
   DECLARE @cDestinationCountry        NVARCHAR( 30)      
   DECLARE @cOtherDestinationCountry   NVARCHAR( 30)     
   DECLARE @cOrderCompany              NVARCHAR( 20)    
   DECLARE @cMBOLCompany               NVARCHAR( 20)   
   DECLARE @cMBOLCarrier               NVARCHAR( 20)  
   DECLARE @cOrderCarrier              NVARCHAR( 20)  
   DECLARE @cUserdefine03              NVARCHAR( 20)  
      
   -- Variable mapping      
   SELECT @cMbolKey = Value FROM @tExtValidate WHERE Variable = '@cMbolKey'      
   SELECT @cPalletID = Value FROM @tExtValidate WHERE Variable = '@cPalletID'      
      
   IF @nStep = 1 -- MBOLKey      
   BEGIN      
      IF @nInputKey = 1 -- ENTER      
      BEGIN      
         SET @cDestinationCountry = ''      
         SELECT @cDestinationCountry = DestinationCountry      
         FROM dbo.MBOL WITH (NOLOCK)      
         WHERE MbolKey = @cMbolKey      
      
         IF ISNULL( @cDestinationCountry, '') = ''      
         BEGIN      
            SET @nErrNo = 196851      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Dest Ctry      
            GOTO Quit      
         END      
      END      
   END      
      
   IF @nStep = 2 -- Pallet      
   BEGIN      
      SET @cStatus = ''      
      SELECT TOP 1       
         @cStatus = Status      
      FROM dbo.PALLETDETAIL WITH (NOLOCK)      
      WHERE PalletKey = @cPalletID      
      
      IF @cStatus <> '9'      
      BEGIN      
         SET @nErrNo = 196852      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Pallet Not Close      
         GOTO Quit      
      END      
      
      IF @nInputKey = 1 -- ENTER      
      BEGIN      
         CREATE TABLE #OrdersOnPallet (      
            RowRef      INT IDENTITY(1,1) NOT NULL,      
            OrderKey    NVARCHAR(10)  NULL,  
            userdefine03 NVARCHAR(20) NULL)     
      
         DECLARE @curORD CURSOR        
         SET @curORD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        
         SELECT DISTINCT UserDefine02,Userdefine03      
         FROM dbo.PalletDetail WITH (NOLOCK)      
         WHERE PalletKey = @cPalletID      
         AND   Status = '9'      
         OPEN @curORD      
         FETCH NEXT FROM @curORD INTO @cOrderKey,@cUserdefine03      
         WHILE @@FETCH_STATUS = 0      
         BEGIN      
            INSERT INTO #OrdersOnPallet ( OrderKey,Userdefine03) VALUES ( @cOrderKey,@cUserdefine03)      
      
            FETCH NEXT FROM @curORD INTO @cOrderKey,@cUserdefine03      
         END      
      
         IF EXISTS ( SELECT 1 FROM dbo.Orders O WITH (NOLOCK)      
                     JOIN #OrdersOnPallet T WITH (NOLOCK) ON ( O.OrderKey = T.OrderKey)      
                     WHERE O.Status = '9')      
         BEGIN      
            SET @nErrNo = 196853      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Orders Shipped      
            GOTO Quit      
         END      
      
         SET @cOtherMbolKey = ''      
         SET @cOtherDestinationCountry = ''    
         SET @cOrderCompany   = ''      
         SELECT TOP 1 @cOtherMbolKey = MBOLKey,       
                      @cOtherDestinationCountry = O.C_Country,    
                      @cOrderCompany   = (O.M_company),  
                      @cOrderCarrier = OI.DeliveryMode     --(yeekung02)  
         FROM dbo.Orders O WITH (NOLOCK)   
         JOIN dbo.Orderinfo OI WITH (NOLOCK) ON (OI.orderkey=O.orderkey)     
         JOIN #OrdersOnPallet T WITH (NOLOCK) ON ( O.OrderKey = T.OrderKey)      

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
         FROM  codelkup CD (NOLOCK)
         WHERE listname = 'THGCUSVCID' 
         and code = 'CUSERVICEID' 
         AND cd.Storerkey=@cStorerKey
         AND (CD.Long=@cOrderCarrier OR CD.short=@cOrderCarrier OR CD.UDF01=@cOrderCarrier OR CD.udf02=@cOrderCarrier
            OR CD.udf03=@cOrderCarrier  OR CD.udf04=@cOrderCarrier OR CD.udf05=@cOrderCarrier)

         IF EXISTS (SELECT 1 from PALLETDETAIL pd(NOLOCK) 
                     WHERE pd.palletkey=@cPalletID      
                        AND pd.StorerKey=@cStorerKey   
                        AND NOT EXISTS (SELECT 1 FROM #temp_deliverymode (NOLOCK) 
                                          WHERE pd.UserDefine03=long or pd.UserDefine03=short
                                          or pd.UserDefine03=udf01 or pd.UserDefine03=udf02 
                                          or pd.UserDefine03 =udf03 or pd.UserDefine03=UDF04
                                          or pd.UserDefine03=udf05) 
                     ) 
         BEGIN    
            SET @nErrNo = 196856              
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- wrongcourier             
            GOTO Quit      
         END    
      
         SET @cDestinationCountry = ''    
         SET @cMBOLCompany = ''    
               
         SELECT @cDestinationCountry = DestinationCountry,    
                @cMBOLCompany = TransMethod,  
                @cMBOLCarrier = CarrierKey      
         FROM dbo.MBOL WITH (NOLOCK)      
         WHERE MbolKey = @cMbolKey       

         IF @cOtherDestinationCountry <> @cDestinationCountry OR NOT EXISTS (
         SELECT 1 FROM #temp_deliverymode (NOLOCK) 
         WHERE @cMBOLCompany=@cOrderCompany+long or @cMBOLCompany=@cOrderCompany+short
         or @cMBOLCompany=@cOrderCompany+udf01 or @cMBOLCompany=@cOrderCompany+udf02 
         or @cMBOLCompany =@cOrderCompany+udf03 or @cMBOLCompany=@cOrderCompany+UDF04
         or @cMBOLCompany=@cOrderCompany+udf05)
         BEGIN      
            SET @nErrNo = 196855      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Wrong Country      
            GOTO Quit      
         END      
      END      
   END      
   Quit:      
      
END 

GO
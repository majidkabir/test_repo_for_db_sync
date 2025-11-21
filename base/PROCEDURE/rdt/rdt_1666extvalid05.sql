SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
            
/************************************************************************/      
/* Store procedure: rdt_1666ExtValid05                                  */      
/*                                                                      */      
/* Modifications log:                                                   */      
/*                                                                      */      
/* Date        Rev  Author      Purposes                                */      
/* 2021-11-07  1.0  Chermaine   WMS-18206 Created                       */    
/************************************************************************/      
      
CREATE PROC [RDT].[rdt_1666ExtValid05] (      
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
   DECLARE @cTransMethod               NVARCHAR( 30)          
   DECLARE @cOtherDestinationCountry   NVARCHAR( 30)     
   DECLARE @cOrderCompany              NVARCHAR( 20)    
   DECLARE @cMBOLCompany               NVARCHAR( 20)   
   DECLARE @cMBOLCarrier               NVARCHAR( 20)  
   DECLARE @cOrderCarrier              NVARCHAR( 20)  
   DECLARE @cUserdefine01              NVARCHAR( 30)  
   DECLARE @cShipperKey    NVARCHAR( 15)
   DECLARE @cPlatform      NVARCHAR( 20)
   DECLARE @cErrMsg1       NVARCHAR( 20)
   DECLARE @cErrMsg2       NVARCHAR( 20)
   DECLARE @cErrMsg3       NVARCHAR( 20)
   DECLARE @cDocType       NVARCHAR( 1)
   DECLARE @cCreateMbol    NVARCHAR(10)
   DECLARE @nMBolDetailCnt INT     
   
   SELECT 
      @cCreateMbol = V_String8 
   FROM rdt.RDTMOBREC WITH (NOLOCK) 
   WHERE mobile = @nMobile
   
   -- Variable mapping      
   SELECT @cMbolKey = Value FROM @tExtValidate WHERE Variable = '@cMbolKey'     
   SELECT @cPalletID = Value FROM @tExtValidate WHERE Variable = '@cPalletID'      
   
      
   IF @nStep = 2 -- Pallet      
   BEGIN      
      IF @nInputKey = 1 -- ENTER      
      BEGIN      
      	IF @cMbolKey <> '' OR @cCreateMbol = 'Y'
      	BEGIN
            IF EXISTS (SELECT 1 
                     FROM PALLETDETAIL PltDt WITH (NOLOCK)
                     JOIN MBOLDETAIL MB WITH (NOLOCK) ON (PltDt.UserDefine02 = MB.OrderKey)
                     WHERE PltDt.StorerKey = @cStorerKey
                     AND PltDt.PalletKey = @cPalletID
                     AND MB.MbolKey <> @cMbolKey)
            BEGIN
            	SET @nErrNo = 178601      
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --> MBOLKey     
               GOTO Quit    
            END
            
            SELECT 
               @nMBolDetailCnt = COUNT(*)  
            FROM MBOLDETAIL WITH (NOLOCK)          
            WHERE MbolKey = @cMbolKey
            
            IF @nMBolDetailCnt > 0    
            BEGIN 
            	--IF EXISTS (SELECT 1 
             --           FROM PALLETDETAIL PltDt WITH (NOLOCK)
             --           JOIN MBOLDETAIL MB WITH (NOLOCK) ON (PltDt.UserDefine02 = MB.OrderKey)
             --           WHERE PltDt.StorerKey = @cStorerKey
             --           AND PltDt.PalletKey = @cPalletID
             --           AND MB.MbolKey = @cMbolKey)
             --  BEGIN
            	--   SET @nErrNo = 178602      
             --     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- PltID Scanned     
             --     GOTO Quit   
             --  END
               
               SET @cDestinationCountry = ''      
               SELECT 
                  @cDestinationCountry = DestinationCountry,
                  @cTransMethod = TransMethod      
               FROM dbo.MBOL WITH (NOLOCK)      
               WHERE MbolKey = @cMbolKey     
            
               SELECT 
                  @cUserdefine01 = UserDefine01
               FROM PalletDetail
               WHERE PalletKey = @cPalletID  
               
               IF @cDestinationCountry + @cTransMethod <>  @cUserdefine01
               BEGIN      
                  SET @nErrNo = 178603      
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DiffUsrdefine      
                  GOTO Quit      
               END
            END
      	END   
      END      
   END           
   Quit:      
      
END 

GO
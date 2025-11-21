SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_842ExtInfo01                                    */  
/* Copyright      : LF                                                  */  
/*                                                                      */  
/* Purpose: LULU DTC Logic                                              */  
/*                                                                      */  
/* Modifications log:                                                   */  
/* Date        Rev  Author   Purposes                                   */  
/* 2016-06-16  1.0  ChewKP   SOS#371222 Created                         */  
/* 2022-11-06  1.1  James    WMS-21082 Add new param (james01)          */
/*                           Add new alert prompt                       */
/************************************************************************/  

CREATE   PROC [RDT].[rdt_842ExtInfo01] (  
   @nMobile        INT,              
   @nFunc          INT,              
   @cLangCode      NVARCHAR(3),      
   @nStep          INT,              
   @nAfterStep     INT,
   @nInputKey      INT,
   @cUserName      NVARCHAR( 18),     
   @cFacility      NVARCHAR( 5),      
   @cStorerKey     NVARCHAR( 15),     
   @cDropID        NVARCHAR( 20),     
   @cSKU           NVARCHAR( 20),
   @cOrderKey      NVARCHAR( 10),
   @cOutField01    NVARCHAR( 20) OUTPUT,  
   @cOutField02    NVARCHAR( 20) OUTPUT,  
   @cOutField03    NVARCHAR( 20) OUTPUT,  
   @cOutField04    NVARCHAR( 20) OUTPUT,  
   @cOutField05    NVARCHAR( 20) OUTPUT,  
   @cOutField06    NVARCHAR( 20) OUTPUT,  
   @tExtendedInfo  VARIABLETABLE READONLY,
   @nErrNo         INT OUTPUT,      
   @cErrMsg        NVARCHAR( 20) OUTPUT
) AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @cMDropID NVARCHAR(20)
          ,@nCount    INT
          ,@cOVAS       NVARCHAR( 30)
          ,@cC_Country  NVARCHAR( 30)
          ,@cType       NVARCHAR( 10)
          ,@cNotes      NVARCHAR( 4000)
          ,@cNotes2     NVARCHAR( 4000)
          ,@cErrMsg1     NVARCHAR( 20)
          ,@cErrMsg2     NVARCHAR( 20)
          ,@cErrMsg3     NVARCHAR( 20)
          ,@cErrMsg4     NVARCHAR( 20)
          ,@cErrMsg5     NVARCHAR( 20)
          ,@cPickSlipNo  NVARCHAR( 10)
          ,@nDropIDCount INT = 0
          
   SET @nErrNo   = 0  
   SET @cErrMsg  = ''  

   
  
  
 
   IF @nStep = 1 
   BEGIN
      SELECT TOP 1 @cOrderKey = OrderKey 
      FROM dbo.PickDetail PD WITH (NOLOCK)  
      WHERE PD.StorerKey = @cStorerKey 
        AND PD.DropID = @cDropID
        AND PD.Status = '5'  
        AND PD.CaseID = ''
        
      SELECT @nDropIDCount = Count(DISTINCT DropID )   
      FROM dbo.PickDetail WITH (NOLOCK)   
      WHERE StorerKey = @cStorerKey   
      AND OrderKey = @cOrderKey  
      AND CASEID = ''   
      AND Status = '5'  

      IF @nDropIDCount > 1
      BEGIN
         SET @nCount = 1 
         SET @cOutField01 = '' 
         SET @cOutField02 = '' 
         SET @cOutField03 = '' 
         SET @cOutField04 = '' 
         SET @cOutField05 = '' 
         SET @cOutField06 = '' 

         DECLARE C_TOTE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   
         SELECT DISTINCT DropID
         FROM dbo.PickDetail PD WITH (NOLOCK)  
         WHERE PD.StorerKey = @cStorerKey 
           AND PD.OrderKey  = @cOrderKey   
           AND PD.Status = '5'  
           AND PD.CaseID = ''
      
      
         OPEN C_TOTE  
         FETCH NEXT FROM C_TOTE INTO  @cMDropID
         WHILE (@@FETCH_STATUS <> -1)  
         BEGIN  
            IF @nCount = 1 
            BEGIN
               SET @cOutField01 = @cMDropID
            END   
            ELSE IF @nCount = 2 
            BEGIN
               SET @cOutField02 = @cMDropID
            ENd
            ELSE IF @nCount = 3
            BEGIN
               SET @cOutField03 = @cMDropID
            ENd
            ELSE IF @nCount = 4
            BEGIN
               SET @cOutField04 = @cMDropID
            ENd
            ELSE IF @nCount = 5
            BEGIN
               SET @cOutField05 = @cMDropID
            ENd
            ELSE IF @nCount = 6
            BEGIN
               SET @cOutField06 = @cMDropID
            ENd                  
         
            SET @nCount = @nCount + 1 
         
            IF @nCount > 6 
            BREAK 
         
            FETCH NEXT FROM C_TOTE INTO  @cMDropID   
         END
         CLOSE C_TOTE  
         DEALLOCATE C_TOTE  
      END
   END
   
   IF @nStep = 2 AND @nAfterStep IN ( 2, 3)
   BEGIN
   	IF @nInputKey = 1
   	BEGIN
         --(1)	In step 2, after SKU is input by user, prompt alert extracted 
         --from Codelkup.Notes (where listname = æLULUDRMSTRÆ AND Orders.Storerkey = Codelkup.Storerkey 
         --AND SKU.OVAS = Codelkup.Code AND Orders.C_Country = Codelkup.Short AND Orders.Type = Codelkup.Long)
         
         SELECT @cOVAS = OVAS
         FROM dbo.SKU WITH (NOLOCK)
         WHERE Sku = @cSKU
         AND   StorerKey = @cStorerKey
         
         SELECT 
            @cType = [Type],
            @cC_Country = C_Country
         FROM dbo.ORDERS WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey
         
         SELECT @cNotes = Notes
         FROM dbo.CODELKUP WITH (NOLOCK)
         WHERE LISTNAME = 'LULUDRMSTR' 
         AND   Code = @cOVAS
         AND   Short = @cC_Country
         AND   Long = @cType
         AND   Storerkey = @cStorerKey
         
         IF ISNULL( @cNotes, '') <> ''
         BEGIN  
            SET @nErrNo = 0  
            SET @cErrMsg1 = @cNotes  
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1  
            IF @nErrNo = 1  
            BEGIN  
               SET @cErrMsg1 = ''  
            END  
            
            SET @nErrNo = 0
         END  
   	END
   END
         
   IF @nStep = 3 AND @nAfterStep IN ( 1, 2)
   BEGIN
   	IF @nInputKey = 1
   	BEGIN
      --(2)	In step 3, after carton type and weight are input, prompt another alert extracted 
      --from CODELKUP.Notes2 (where listname = æLULUDRMSTRÆ AND Orders.Storerkey = Codelkup.Storerkey 
      --AND SKU.OVAS = Codelkup.Code AND Orders.C_Country = Codelkup.Short AND Orders.Type = Codelkup.Long)
         IF ISNULL( @cOrderKey, '') = ''
            SELECT TOP 1 @cOrderKey = PH.OrderKey
            FROM dbo.PackDetail PD WITH (NOLOCK)
            JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PD.PickSlipNo = PH.PickSlipNo)
            WHERE PD.StorerKey = @cStorerKey
            AND   PD.DropID = @cDropID
            AND   PH.[Status] = '9'
            ORDER BY 1
         
         SELECT TOP 1 @cOVAS = SKU.OVAS
         FROM dbo.ORDERDETAIL OD WITH (NOLOCK)
         JOIN dbo.SKU SKU WITH (NOLOCK) ON ( OD.Sku = SKU.Sku AND OD.StorerKey = SKU.StorerKey)
         WHERE OD.OrderKey = @cOrderKey
         ORDER BY 1 DESC

         -- Check if 1 orders any sku contain sku.ovas = 1, if yes, display alert
         IF ISNULL( @cOVAS, '') = '1'
         BEGIN
            SELECT 
               @cType = [Type],
               @cC_Country = C_Country
            FROM dbo.ORDERS WITH (NOLOCK)
            WHERE OrderKey = @cOrderKey
         
            SELECT @cNotes2 = Notes2
            FROM dbo.CODELKUP WITH (NOLOCK)
            WHERE LISTNAME = 'LULUDRMSTR' 
            AND   Code = @cOVAS
            AND   Short = @cC_Country
            AND   Long = @cType
            AND   Storerkey = @cStorerKey

            IF ISNULL( @cNotes2, '') <> ''
            BEGIN  
               SET @nErrNo = 0  
               SET @cErrMsg1 = @cNotes2  
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1  
               IF @nErrNo = 1  
               BEGIN  
                  SET @cErrMsg1 = ''  
               END  
            
               SET @nErrNo = 0
            END  
         END
   	END
   END
   GOTO QUIT      
Quit:      
        
      
END  


GO
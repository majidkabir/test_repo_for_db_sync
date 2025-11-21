SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
    
    
/******************************************************************************/      
/* Store procedure: isp_TPS_STDDecodeSP                                      */      
/* Copyright      : LFLogistics                                               */      
/*                                                                            */      
/* Date         Rev  Author     Purposes                                      */      
/* 2022-02-15   1.0  yeekung  WMS-17771 Created                               */      
/******************************************************************************/      
      
CREATE   PROC [API].[isp_TPS_STDDecodeSP] (      
   @json       NVARCHAR( MAX),      
   @jResult    NVARCHAR( MAX) OUTPUT,      
   @b_Success  INT = 1        OUTPUT,      
   @n_Err      INT = 0        OUTPUT,      
   @c_ErrMsg   NVARCHAR( 255) = ''  OUTPUT     
)      
AS      
      
SET NOCOUNT ON      
SET QUOTED_IDENTIFIER OFF      
SET ANSI_NULLS OFF      
SET CONCAT_NULL_YIELDS_NULL OFF      
BEGIN
   DECLARE @cStorerKey       NVARCHAR( 15),  
         @cFacility        NVARCHAR( 5),  
         @nFunc            NVARCHAR( 5),  
         @cUserName        NVARCHAR( 128),  
         @cOriUserName     NVARCHAR( 128),  
         @cScanNo          NVARCHAR( 50),  
         @cScanNoType      NVARCHAR( 30),  
         @cDropID          NVARCHAR( 50),  
         @cPickSlipNo      NVARCHAR( 30),  
         @cZone            NVARCHAR( 18),  
         @nCartonNo        INT,  
         @cCartonID        NVARCHAR( 20),  
         @cType            NVARCHAR( 30),  
         @nQTY             INT,  
         @cSKU             NVARCHAR( 20),  
         @cCartonType      NVARCHAR( 10),  
         @fCartonCube      FLOAT,  
         @fCartonWeight    FLOAT,
         @cLangCode        NVARCHAR(20),
         @cWorkstation     NVARCHAR(20),
         @cLabelNo         NVARCHAR(20),
         @cBarcode         NVARCHAR(60)
             
   --Decode Json Format    
   select @cStorerKey = StorerKey, @cFacility = Facility, @nFunc = Func, @cUserName = UserName, @cLangCode = LangCode,  
   @cScanNo = ScanNo,  @cWorkstation = Workstation,@cBarcode = Barcode 
   FROM OPENJSON(@json)    
   WITH (  
    StorerKey      NVARCHAR( 30),  
    Facility       NVARCHAR( 30),  
      Func           NVARCHAR( 5),  
      UserName       NVARCHAR( 128),  
      LangCode       NVARCHAR( 3),  
      ScanNo         NVARCHAR( 30),  
      CartonNo       INT,  
      Workstation    NVARCHAR( 30),  
      Barcode        NVARCHAR( 60)
   )   
       
   SET @b_Success = 1     
     
  
   IF EXISTS(SELECT 1 FROM UCC WITH (NOLOCK)    
            WHERE UCCNO = @cBarcode    
               AND storerKey = @cStorerKey
            )    
   BEGIN 
      IF EXISTS(SELECT 1 FROM UCC WITH (NOLOCK)    
            WHERE UCCNO = @cBarcode    
               AND storerKey = @cStorerKey
               AND Status < '5')    
      BEGIN
         SELECT @cSKU=sku
         FROM UCC (NOLOCK)
         WHERE UCCNO = @cBarcode    
            AND storerKey = @cStorerKey
            AND Status < '5'

         SET @jResult = ( select @cStorerKey AS StorerKey, @cFacility AS Facility, @nFunc AS Func, @cUserName AS UserName, @cLangCode AS LangCode,  
                        @cScanNo AS ScanNo, @nCartonNo AS CartonNo, @cWorkstation AS Workstation,@cBarcode AS Barcode, @cSKU AS SKU,'UCC' AS SKUTYPE
                        FOR JSON PATH,INCLUDE_NULL_VALUES) 
      END
   END
   ELSE  
   BEGIN  
    SET @jResult = (SELECT '' AS SKU, 'SKU' AS SKUTYPE  
                     FOR JSON PATH,INCLUDE_NULL_VALUES)
   END 
    
   SET @n_Err = 0    
   SET @c_ErrMsg = ''    
       
END    

GO
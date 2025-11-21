SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store procedure: rdt_876ExtInfo02                                    */    
/* Copyright      : LF                                                  */    
/*                                                                      */    
/* Call From: rdtfnc_SerialNoByOrder                                    */    
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author   Purposes                                   */    
/* 2019-08-05  1.0  James    WMS10007. Created                          */    
/************************************************************************/    

CREATE PROC [RDT].[rdt_876ExtInfo02] (    
   @nMobile          INT,  
   @nFunc            INT,   
   @cLangCode        NVARCHAR(3),   
   @nStep            INT,   
   @cStorerKey       NVARCHAR( 15),   
   @cExternOrderKey  NVARCHAR( 30),  
   @cOrderKey        NVARCHAR( 10),  
   @cSerialNo        NVARCHAR( 18),  
   @cSKU             NVARCHAR( 20),
   @cOutInfo01       NVARCHAR( 20)  OUTPUT,
   @nErrNo           INT            OUTPUT,   
   @cErrMsg          NVARCHAR( 20)  OUTPUT
) AS    
BEGIN    
   SET NOCOUNT ON            
   SET ANSI_NULLS OFF            
   SET QUOTED_IDENTIFIER OFF            
   SET CONCAT_NULL_YIELDS_NULL OFF            
   
   DECLARE @n_SumPDtlQty      INT
   DECLARE @n_SumSNPcsQty     INT
   DECLARE @n_SumSNCtnQty     INT
   DECLARE @c_ErrMsg1         NVARCHAR( 20)
   DECLARE @c_ErrMsg2         NVARCHAR( 20)
   DECLARE @n_InputKey        INT
   DECLARE @c_BUSR8           NVARCHAR( 30)

   SET @nErrNo   = 0            
   SET @cErrMsg  = ''     
   
   SELECT @n_InputKey = InputKey
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   IF @nFunc = 876          
   BEGIN     
      IF @nStep = '2'   
      BEGIN  
         IF @n_InputKey = 0
         BEGIN     
            IF EXISTS ( SELECT 1 
                        FROM dbo.SKU WITH (NOLOCK)
                        WHERE StorerKey = @cStorerKey
                        AND SKU = @cSKU
                        AND BUSR8 = '1')
            BEGIN
               SELECT @n_SumPDtlQty = ISNULL( SUM( Qty), 0)
               FROM dbo.PICKDETAIL PD WITH (NOLOCK)
               JOIN dbo.SKU SKU WITH (NOLOCK) ON ( PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
               WHERE PD.OrderKey = @cOrderKey
               AND   SKU.BUSR8 = '1'

               SELECT @n_SumSNPcsQty = ISNULL( SUM(SN.Qty), 0)
               FROM dbo.SerialNo SN WITH (NOLOCK) 
               JOIN dbo.SKU SKU WITH (NOLOCK) ON ( SN.StorerKey = SKU.StorerKey AND SN.SKU = SKU.SKU )
               WHERE SN.OrderKey = @cOrderKey
               AND   SKU.BUSR8 = '1'
               AND   SUBSTRING( SN.SerialNo, 4, 1) <> 'M'

               SELECT @n_SumSNCtnQty = ISNULL( SUM( SN.Qty * PA.CaseCnt), 0)
               FROM dbo.SerialNo SN WITH (NOLOCK) 
               JOIN dbo.SKU SKU WITH (NOLOCK) ON ( SN.StorerKey = SKU.StorerKey AND SN.SKU = SKU.SKU )
               JOIN dbo.Pack PA WITH (NOLOCK) ON ( SKU.PackKey = PA.PackKey)
               WHERE SN.OrderKey = @cOrderKey
               AND   SKU.BUSR8 = '1'
               AND   SUBSTRING( SN.SerialNo, 4, 1) = 'M'

               IF @n_SumPDtlQty = ( @n_SumSNPcsQty + @n_SumSNCtnQty)
               BEGIN
                  SET @c_ErrMsg1 = rdt.rdtgetmessage( 142451, @cLangCode, 'DSP')  --Orders QR Scan
                  SET @c_ErrMsg2 = rdt.rdtgetmessage( 142452, @cLangCode, 'DSP') -- Completed
            
                  EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
                     @c_ErrMsg1, @c_ErrMsg2

                  SET @nErrNo = 0
                  SET @cErrMsg = ''
               END
               ELSE IF @n_SumPDtlQty > ( @n_SumSNPcsQty + @n_SumSNCtnQty)
               BEGIN
                  SET @c_ErrMsg1 = rdt.rdtgetmessage( 142453, @cLangCode, 'DSP')  --Orders QR Scan
                  SET @c_ErrMsg2 = rdt.rdtgetmessage( 142454, @cLangCode, 'DSP') -- Not Complete
            
                  EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
                     @c_ErrMsg1, @c_ErrMsg2

                  SET @nErrNo = 0
                  SET @cErrMsg = ''
               END
               ELSE
               BEGIN
                  SET @c_ErrMsg1 = rdt.rdtgetmessage( 142455, @cLangCode, 'DSP')  --Over Scan
                  SET @c_ErrMsg2 = ''

                  EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
                     @c_ErrMsg1, @c_ErrMsg2

                  SET @nErrNo = 0
                  SET @cErrMsg = ''
               END
            END
         END
      END
   END        
   
   Quit:  
END     

GO
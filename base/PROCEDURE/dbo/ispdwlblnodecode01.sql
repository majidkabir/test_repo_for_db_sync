SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
    
/************************************************************************/    
/* Store procedure: ispDWLblNoDecode01                                  */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Purpose: Add serialno decode                                         */ 
/*                                                                      */    
/* Called from:                                                         */    
/*                                                                      */    
/* Exceed version: 5.4                                                  */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date        Rev  Author      Purposes                                */    
/* 01/04/2021  1.0  YeeKung     WMS-16718 Created                       */
/************************************************************************/    
    
CREATE PROCEDURE [dbo].[ispDWLblNoDecode01]    
   @c_LabelNo          NVARCHAR(40),    
   @c_Storerkey        NVARCHAR(15),    
   @c_ReceiptKey       NVARCHAR(10),    
   @c_POKey            NVARCHAR(10),    
   @c_LangCode         NVARCHAR(3),    
   @c_oFieled01        NVARCHAR(20) OUTPUT,    
   @c_oFieled02        NVARCHAR(20) OUTPUT,    
   @c_oFieled03        NVARCHAR(20) OUTPUT,    
   @c_oFieled04        NVARCHAR(20) OUTPUT,    
   @c_oFieled05        NVARCHAR(20) OUTPUT,    
   @c_oFieled06        NVARCHAR(20) OUTPUT,    
   @c_oFieled07        NVARCHAR(20) OUTPUT,    
   @c_oFieled08        NVARCHAR(20) OUTPUT,    
   @c_oFieled09        NVARCHAR(20) OUTPUT,    
   @c_oFieled10        NVARCHAR(20) OUTPUT,    
   @b_Success          INT = 1  OUTPUT,    
   @n_ErrNo            INT      OUTPUT,     
   @c_ErrMsg           NVARCHAR(250) OUTPUT    
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE @n_Func      INT,    
           @n_Step      INT,    
           @n_InputKey  INT ,
           @cTempSKU    NVARCHAR(20),
           @cPickSlipNO NVARCHAR(20)   
    
   IF ISNULL( @c_LabelNo, '') = ''    
      GOTO Quit    
    
   SELECT @n_Func = Func,     
          @n_Step = Step,    
          @n_InputKey = InputKey,
          @cPickSlipNO=V_PickSlipNo    
   FROM rdt.rdtMobRec WITH (NOLOCK)     
   WHERE UserName = sUser_sName()    
  
   SET  @b_Success  ='1'  

   IF ISNULL(@n_Func,'')=''  
   BEGIN  
      SET  @b_Success  ='1'  
      GOTO QUIT  
   END  
    
   IF @n_InputKey = 1    
   BEGIN    
      IF @n_Func=841  
      BEGIN  

         SELECT  @cTempSKU=sku
         FROM dbo.SerialNo (NOLOCK)
         WHERE SerialNo=@c_LabelNo
         AND storerkey=@c_Storerkey
            AND status <='1'

         IF ISNULL(@cTempSKU,'')=''
         BEGIN
            SET @c_oFieled01=@c_LabelNo

            SELECT @c_oFieled10=1
         END
         ELSE
         BEGIN
            IF EXISTS (SELECT 1 FROM dbo.PackSerialNo (NOLOCK) WHERE serialno=@c_LabelNo AND storerkey=@c_Storerkey and sku=@cTempSKU AND PickSlipNo=@cPickSlipNO)
            BEGIN
               SET @n_ErrNo = 166151    
               SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, 'ENG', 'DSP') --'InvalidBarcode'  
               GOTO QUIT  
            END
            
            SET @c_oFieled01=@cTempSKU 
            SET @c_oFieled09=@c_LabelNo
            SET @c_oFieled10=0
         END
         
      END
   END    
QUIT:    
END -- End Procedure    

GO
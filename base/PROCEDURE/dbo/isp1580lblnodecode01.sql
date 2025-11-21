SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: isp1580LblNoDecode01                                */  
/* Copyright      : LFLogistics                                         */  
/*                                                                      */  
/* Date         Rev  Author      Purposes                               */  
/* 11-Nov-2015  1.0  James       SOS356310 Created                      */  
/* 25-Jun-2018  1.1  James       WMS5311-Add function id, step (james01)*/
/************************************************************************/  
CREATE PROCEDURE [dbo].[isp1580LblNoDecode01]  
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

   DECLARE @cSKU    NVARCHAR( 20)  
   DECLARE @cQTY    NVARCHAR( 5)  
   DECLARE @nFunc   INT
   DECLARE @nStep   INT

   SET @c_oFieled01 = ''
   SET @c_oFieled05 = ''

   IF ISNULL( @c_LabelNo, '') = ''
      GOTO Quit

   SELECT @nFunc = Func, 
          @nStep = Step
   FROM rdt.rdtMobRec WITH (NOLOCK) 
   WHERE UserName = sUser_sName()

   IF @nFunc IN ( 1580, 1581)
   BEGIN
      IF @nStep = 3  -- TOID
      BEGIN
         SET @c_oFieled01 = @c_LabelNo
         GOTO Quit
      END
      
      IF @nStep = 5
      BEGIN
         SET @cSKU = ''  
         SET @cQTY = ''  

         -- The label consist of SKU + Qty or ALTSKU + Qty. 
         -- The last 2 characters are qty and the rest is SKU or AltSKU.
         SET @cSKU = LEFT( @c_LabelNo, LEN( RTRIM( @c_LabelNo)) - 3)
         SET @cQTY = RIGHT( RTRIM( @c_LabelNo), 3)

         -- Return SKU  
         SET @c_oFieled01 = @cSKU  

         -- Return QTY  
         IF rdt.rdtIsValidQTY( @cQTY, 1) = 1 -- 1=Check for zero QTY  
            SET @c_oFieled05 = CAST( @cQTY AS INT)
      END

   END
   QUIT:  
END -- End Procedure  

GO
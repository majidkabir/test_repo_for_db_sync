SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: isp1580LblNoDecode03                                */  
/* Copyright      : LFLogistics                                         */  
/*                                                                      */  
/* Date         Rev  Author      Purposes                               */  
/* 02-Jan-2019  1.0  James       WMS7323 Created                        */  
/************************************************************************/  
CREATE PROCEDURE [dbo].[isp1580LblNoDecode03]  
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

   IF ISNULL( @c_LabelNo, '') = ''
      GOTO Quit

   SELECT @nFunc = Func, 
          @nStep = Step
   FROM rdt.rdtMobRec WITH (NOLOCK) 
   WHERE UserName = sUser_sName()

   IF @nFunc = 1581
   BEGIN
      IF @nStep = 3  -- TOID
      BEGIN
         IF LEN( RTRIM( @c_LabelNo)) > 18
            SET @c_oFieled01 = RIGHT( RTRIM( @c_LabelNo), 18)
      END
      
   END
   QUIT:  
END -- End Procedure  

GO
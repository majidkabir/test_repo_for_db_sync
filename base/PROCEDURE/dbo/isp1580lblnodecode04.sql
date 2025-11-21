SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/    
/* Store procedure: isp1580LblNoDecode04                                */    
/* Copyright      : LFLogistics                                         */    
/*                                                                      */    
/* Date         Rev  Author      Purposes                               */    
/* 2019-07-04   1.0  James       WMS-9569 Created                       */    
/************************************************************************/    
CREATE PROCEDURE [dbo].[isp1580LblNoDecode04]    
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
  
   DECLARE @c_ActSKU    NVARCHAR( 20)    
   DECLARE @n_Func      INT  
   DECLARE @n_Step      INT  
   DECLARE @n_InputKey  INT  
   DECLARE @n_SKUCnt    INT  
   DECLARE @c_DefaultPieceRecvQTY   NVARCHAR( 5)  
  
   SET @c_oFieled01 = ''  
   SET @c_oFieled05 = ''  
  
   IF ISNULL( @c_LabelNo, '') = ''  
      GOTO Quit  
  
   SELECT @n_Func = Func,   
          @n_Step = Step,  
          @n_InputKey = InputKey  
   FROM rdt.rdtMobRec WITH (NOLOCK)   
   WHERE UserName = sUser_sName()  
  
   IF @n_Func = 1580  
   BEGIN  
      IF @n_Step = 3
	   BEGIN 
		   IF @n_InputKey = 1 
		   BEGIN
			   SELECT @c_oFieled01=@c_LabelNo
		   END 
	   END

      IF @n_Step = 5  
      BEGIN  
         IF @n_InputKey = 1  
         BEGIN  
          SET @b_Success = 1  
            SET @c_ActSKU = @c_LabelNo  
  
            EXEC [RDT].[rdt_GETSKUCNT]  
             @cStorerKey  = @c_StorerKey  
            ,@cSKU        = @c_ActSKU  
            ,@nSKUCnt     = @n_SKUCnt      OUTPUT  
            ,@bSuccess    = @b_Success     OUTPUT  
            ,@nErr        = @n_ErrNo       OUTPUT  
            ,@cErrMsg     = @c_ErrMsg      OUTPUT  
  
            -- Validate SKU/UPC  
            IF @n_SKUCnt = 0  
               GOTO Quit  
  
            -- Validate barcode return multiple SKU  
            IF @n_SKUCnt > 1  
               GOTO Quit  
  
            EXEC [RDT].[rdt_GETSKU]  
             @cStorerKey  = @c_StorerKey  
            ,@cSKU        = @c_ActSKU      OUTPUT  
            ,@bSuccess    = @b_Success     OUTPUT  
            ,@nErr        = @n_ErrNo       OUTPUT  
            ,@cErrMsg     = @c_ErrMsg      OUTPUT  
  
            IF EXISTS ( SELECT 1 FROM dbo.SKU WITH (NOLOCK)  
                        WHERE StorerKey = @c_StorerKey  
                        AND   SKU = @c_ActSKU  
                        AND   PickCode = 'M')  
               SET @c_oFieled05 = ''  
            ELSE  
            BEGIN  
               SET @c_DefaultPieceRecvQTY = rdt.RDTGetConfig( 0, 'DefaultPieceRecvQTY', @c_StorerKey)  
               IF @c_DefaultPieceRecvQTY = '0'  
                  SET @c_DefaultPieceRecvQTY = ''  
                 
               IF @c_DefaultPieceRecvQTY = ''  
                  SET @c_oFieled05 = '1'  
               ELSE  
               BEGIN  
                  IF rdt.rdtIsValidQTY( @c_DefaultPieceRecvQTY, 1) = 1 -- 1=Check for zero QTY    
                     SET @c_oFieled05 = @c_DefaultPieceRecvQTY  
               END  
            END  
  
            SET @c_oFieled01 = @c_ActSKU  
         END  
      END  
	
   END  
   QUIT:    
END -- End Procedure    

GO
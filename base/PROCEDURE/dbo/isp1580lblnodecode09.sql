SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/  
/* Store procedure: isp1580LblNoDecode09                                      */  
/* Copyright: LF Logistics                                                    */  
/*                                                                            */  
/* Purpose: Decode SSCC. Return SKU, Qty                                      */  
/*                                                                            */  
/* Date        Author    Ver.  Purposes                                       */  
/* 2021-03-31  James     1.0   WMS-16653 Created                              */ 
/* 2023-04-13  James     1.1   WMS-21975 Change I_Field02->V_Barcode (james01)*/
/******************************************************************************/  
  
CREATE   PROCEDURE [dbo].[isp1580LblNoDecode09] (  
   @c_LabelNo          NVARCHAR(60),        
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
) AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @n_Func      INT      
   DECLARE @n_Step      INT      
   DECLARE @n_InputKey  INT      
   DECLARE @c_SKU          NVARCHAR( 20)  
   DECLARE @c_Lottable01   NVARCHAR( 18)
   DECLARE @c_Lottable04   NVARCHAR( 18)  
   DECLARE @c_Lottable06   NVARCHAR( 30)
   
   IF ISNULL( @c_LabelNo, '') = ''      
      GOTO Quit      
   
   SELECT @n_Func = Func,       
          @n_Step = Step,      
          @n_InputKey = InputKey,
          @c_LabelNo = V_Barcode  
   FROM rdt.rdtMobRec WITH (NOLOCK)       
   WHERE UserName = sUser_sName()      

   IF LEN( RTRIM( @c_LabelNo)) < 37
      GOTO Quit
  
   IF @n_Func = 1580 -- Normal receiving  
   BEGIN  
      IF @n_Step = 5 -- SKU  
      BEGIN  
         IF @n_InputKey = 1 -- ENTER  
         BEGIN  
            --Process:
            --1.	Decode QR code scanned from left 15th digital to 24th digital into Lottable01.
            --2.	Decode QR code scanned from left 26th digital to 35th digital into Lottable04
            --3.	Decode QR code scanned from left 37th digital to end into Lottable06
            --4.	Decode QR code scanned from left 1st digital to 13th digital into SKU.
            SET @c_SKU = SUBSTRING( @c_LabelNo, 1, 13)
            SET @c_Lottable01 = SUBSTRING( @c_LabelNo, 15, 10)
            SET @c_Lottable04 = SUBSTRING( @c_LabelNo, 26, 10)
            SET @c_Lottable06 = SUBSTRING( @c_LabelNo, 37, LEN( RTRIM( @c_LabelNo)) - 36)
            
            SET @c_oFieled01 = @c_SKU  
            SET @c_oFieled03 = @c_Lottable06
            SET @c_oFieled07 = @c_Lottable01
            SET @c_oFieled10 = @c_Lottable04
         END  
      END  
   END  
Quit:  
  
END  

GO
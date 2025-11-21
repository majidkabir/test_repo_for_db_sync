SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
    
/************************************************************************/    
/* Store procedure: ispIkeaLblNoDecode01                                */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Purpose: Decode Label No Scanned. Not using rdt_Decode because in    */    
/*          rdtscndetail some storer setup ColStringExp which conflict  */    
/*          with existing setup (decode 2 times)                        */    
/*                                                                      */    
/* Called from:                                                         */    
/*                                                                      */    
/* Exceed version: 5.4                                                  */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date        Rev  Author      Purposes                                */    
/* 24-08-2018  1.0  James       WMS5311. Created                        */   
/* 09-06-2020  1.1  YeeKung     WMS13131. Add Func 841  (yeekung01)     */   
/************************************************************************/    
    
CREATE PROCEDURE [dbo].[ispIkeaLblNoDecode01]    
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
           @n_InputKey  INT    
    
   IF ISNULL( @c_LabelNo, '') = ''    
      GOTO Quit    
    
   SELECT @n_Func = Func,     
          @n_Step = Step,    
          @n_InputKey = InputKey    
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
      IF @n_Func = 523    
      BEGIN    
         IF @n_Step = 1 --ID    
         BEGIN    
            SET @c_oFieled01 = @c_LabelNo    
            GOTO Quit    
         END    
         ELSE IF @n_Step = 2  -- SKU    
         BEGIN    
            SET @c_oFieled01 = SUBSTRING( RTRIM( @c_LabelNo), 1, 13)    
            GOTO Quit    
         END    
         ELSE    
            GOTO Quit    
      END    
  
      IF @n_Func=841  
      BEGIN  
         SET @c_oFieled01 = SUBSTRING( RTRIM( @c_LabelNo), 1, 13)    
         SET @b_Success='1'  
         GOTO Quit    
      END  
   END    
QUIT:    
END -- End Procedure    

GO
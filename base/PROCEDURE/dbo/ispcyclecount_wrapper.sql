SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: ispCycleCount_Wrapper                               */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Backend process for CycleCount                              */  
/*                                                                      */  
/* Called from:                                                         */  
/*                                                                      */  
/* Exceed version: 5.4                                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author      Purposes                                */  
/* 24-Mar-2011 1.0  ChewKP      Created                                 */  
/* 19-Apr-2017 1.1  Ung         Fix recompile                           */
/* 12-Sep-2018 1.2  Ung         WMS-6163 Add ID                         */
/************************************************************************/  
  
CREATE PROC [dbo].[ispCycleCount_Wrapper] (  
   @c_SPName     NVARCHAR(250),  
   @c_SKU        NVARCHAR(20),  
   @c_Storerkey  NVARCHAR(15),  
   @c_Loc        NVARCHAR(10),  
   @c_ID         NVARCHAR(18),  
   @c_CCKey      NVARCHAR(10),  
   @c_CountNo    NVARCHAR(10),  
   @c_Ref01      NVARCHAR(20),  
   @c_Ref02      NVARCHAR(20),  
   @c_Ref03      NVARCHAR(20),  
   @c_Ref04      NVARCHAR(20),  
   @c_Ref05      NVARCHAR(20),  
   @n_Qty        INT,  
   @c_Lottable01Value  NVARCHAR(18),    
   @c_Lottable02Value  NVARCHAR(18),    
   @c_Lottable03Value  NVARCHAR(18),    
   @dt_Lottable04Value DateTime,    
   @dt_Lottable05Value DateTime,    
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
)  
AS   
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @cSQLStatement   nvarchar(2000),   
           @cSQLParms       nvarchar(2000)  
  
   DECLARE @b_debug  int   
   SET @b_debug = 0  
  
   IF @c_SPName = '' OR @c_SPName IS NULL  
   BEGIN  
      SET @b_Success = 0  
      SET @n_ErrNo = 66151      
      SET @c_ErrMsg = CONVERT(Char(5), @n_ErrNo) + ' Stored Proc Not Setup. (ispCycleCount_Wrapper)'  
      GOTO QUIT  
   END  
        
   IF @b_debug = 1  
   BEGIN  
     SELECT '@c_SPName', @c_SPName  
   END  
  
  
  
  
   IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPName) AND type = 'P')  
   BEGIN  
  
    SET @cSQLStatement = N'EXEC ' + RTrim(@c_SPName) +   
        ' @c_SKU,   @c_Storerkey, @c_Loc, @c_ID,  @c_CCKey, @c_CountNo,        ' +       
          ' @c_Ref01, @c_Ref02,     @c_Ref03, @c_Ref04, @c_Ref05,   @n_Qty,' +  
          ' @c_Lottable01Value, @c_Lottable02Value,     @c_Lottable03Value, @dt_Lottable04Value, @dt_Lottable05Value, ' +  
          ' @c_LangCode, ' +  
          ' @c_oFieled01 OUTPUT, @c_oFieled02 OUTPUT, @c_oFieled03 OUTPUT, ' +  
          ' @c_oFieled04 OUTPUT, @c_oFieled05 OUTPUT, @c_oFieled06 OUTPUT, ' +  
          ' @c_oFieled07 OUTPUT, @c_oFieled08 OUTPUT, @c_oFieled09 OUTPUT, ' +  
          ' @c_oFieled10 OUTPUT, @b_Success   OUTPUT, @n_ErrNo     OUTPUT, ' +  
          ' @c_ErrMsg    OUTPUT '  
   
    SET @cSQLParms = N'@c_SKU              NVARCHAR(20),        ' +  
                        '@c_Storerkey        NVARCHAR(15),        ' +  
                        '@c_Loc              NVARCHAR(10),        ' +  
                        '@c_ID               NVARCHAR(18),        ' +  
                        '@c_CCKey            NVARCHAR(10),        ' +  
                        '@c_CountNo          NVARCHAR(10),        ' +  
                        '@c_Ref01            NVARCHAR(20),        ' +  
                        '@c_Ref02            NVARCHAR(20),        ' +  
                        '@c_Ref03            NVARCHAR(20),        ' +  
                        '@c_Ref04            NVARCHAR(20),        ' +  
                        '@c_Ref05            NVARCHAR(20),        ' +  
                        '@n_Qty              INT,                ' +  
                        '@c_Lottable01Value  NVARCHAR(18),        ' +   
                        '@c_Lottable02Value  NVARCHAR(18),        ' +   
                        '@c_Lottable03Value  NVARCHAR(18),        ' +   
                        '@dt_Lottable04Value DateTime,           ' +   
                        '@dt_Lottable05Value DateTime,           ' +   
                        '@c_LangCode         NVARCHAR(3),            ' +  
                        '@c_oFieled01        NVARCHAR(20) OUTPUT, ' +   
                        '@c_oFieled02        NVARCHAR(20) OUTPUT, ' +   
                        '@c_oFieled03        NVARCHAR(20) OUTPUT, ' +   
                        '@c_oFieled04        NVARCHAR(20) OUTPUT, ' +   
                        '@c_oFieled05        NVARCHAR(20) OUTPUT, ' +   
                        '@c_oFieled06        NVARCHAR(20) OUTPUT, ' +   
                        '@c_oFieled07        NVARCHAR(20) OUTPUT, ' +   
                        '@c_oFieled08        NVARCHAR(20) OUTPUT, ' +   
                        '@c_oFieled09        NVARCHAR(20) OUTPUT, ' +   
                        '@c_oFieled10        NVARCHAR(20) OUTPUT, ' +    
                        '@b_Success          INT      OUTPUT,    ' +                       
                        '@n_ErrNo            INT      OUTPUT,    ' +  
                        '@c_ErrMsg           NVARCHAR(250) OUTPUT '   
                          
      
    EXEC sp_ExecuteSQL @cSQLStatement, @cSQLParms      
            ,@c_SKU                  
            ,@c_Storerkey                
            ,@c_Loc        
            ,@c_ID              
            ,@c_CCKey                    
            ,@c_CountNo             
            ,@c_Ref01                    
            ,@c_Ref02                    
            ,@c_Ref03                    
            ,@c_Ref04                    
            ,@c_Ref05                    
            ,@n_Qty  
            ,@c_Lottable01Value   
            ,@c_Lottable02Value   
            ,@c_Lottable03Value   
            ,@dt_Lottable04Value  
            ,@dt_Lottable05Value  
            ,@c_LangCode  
            ,@c_oFieled01  OUTPUT  
            ,@c_oFieled02  OUTPUT  
            ,@c_oFieled03  OUTPUT  
            ,@c_oFieled04  OUTPUT  
            ,@c_oFieled05  OUTPUT  
            ,@c_oFieled06  OUTPUT  
            ,@c_oFieled07  OUTPUT  
            ,@c_oFieled08  OUTPUT  
            ,@c_oFieled09  OUTPUT  
            ,@c_oFieled10  OUTPUT  
            ,@b_Success    OUTPUT  
            ,@n_ErrNo      OUTPUT  
            ,@c_ErrMsg     OUTPUT  
   END  
  
  
   IF @b_debug = 1  
   BEGIN  
     SELECT '@c_oFieled01', @c_oFieled01  
     SELECT '@c_oFieled02', @c_oFieled02  
     SELECT '@c_oFieled03', @c_oFieled03  
     SELECT '@c_oFieled04', @c_oFieled04  
     SELECT '@c_oFieled05', @c_oFieled05  
     SELECT '@c_oFieled06', @c_oFieled06  
     SELECT '@c_oFieled07', @c_oFieled07  
     SELECT '@c_oFieled08', @c_oFieled08  
     SELECT '@c_oFieled09', @c_oFieled09  
     SELECT '@c_oFieled10', @c_oFieled10  
     SELECT '@c_ErrMsg', @c_ErrMsg  
   END  
  
QUIT:  
END -- procedure  
  


GO
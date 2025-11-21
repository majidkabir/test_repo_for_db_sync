SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: RDT_PickGetTaskInLOC_Wrapper                        */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Picking fetch task customised stored proc                   */
/*                                                                      */
/* Called from:                                                         */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2014-05-20  1.0  James    SOS311720 Created                          */
/* 2014-06-10  1.1  James    Revamp error msg (james01)                 */
/************************************************************************/

CREATE PROC [RDT].[RDT_PickGetTaskInLOC_Wrapper] (
	@n_Mobile				INT, 
   @n_Func					INT,
	@c_LangCode	         NVARCHAR(3),
   @c_SPName            NVARCHAR( 250),
   @c_StorerKey         NVARCHAR( 15),
   @c_PickSlipNo        NVARCHAR( 10),
   @c_LOC               NVARCHAR( 10),
   @c_PrefUOM           NVARCHAR( 1),
   @c_PickType          NVARCHAR( 1),
   @c_DropID            NVARCHAR( 18),   
   @c_ID                NVARCHAR( 18)  OUTPUT,   
   @c_SKU               NVARCHAR( 20)  OUTPUT,  
   @c_UOM               NVARCHAR( 10)  OUTPUT,  
   @c_Lottable1         NVARCHAR( 18)  OUTPUT,  
   @c_Lottable2         NVARCHAR( 18)  OUTPUT,  
   @c_Lottable3         NVARCHAR( 18)  OUTPUT,  
   @d_Lottable4         DATETIME       OUTPUT,  
   @c_SKUDescr          NVARCHAR( 60)  OUTPUT,   
	@c_oFieled01         NVARCHAR( 20) 	OUTPUT,
	@c_oFieled02         NVARCHAR( 20) 	OUTPUT,
   @c_oFieled03         NVARCHAR( 20) 	OUTPUT,
   @c_oFieled04         NVARCHAR( 20) 	OUTPUT,
   @c_oFieled05         NVARCHAR( 20) 	OUTPUT,
   @c_oFieled06         NVARCHAR( 20) 	OUTPUT,
   @c_oFieled07         NVARCHAR( 20) 	OUTPUT,
   @c_oFieled08         NVARCHAR( 20) 	OUTPUT,
   @c_oFieled09         NVARCHAR( 20) 	OUTPUT,
   @c_oFieled10         NVARCHAR( 20) 	OUTPUT,
   @c_oFieled11         NVARCHAR( 20) 	OUTPUT,
   @c_oFieled12         NVARCHAR( 20) 	OUTPUT,
   @c_oFieled13         NVARCHAR( 20) 	OUTPUT,
   @c_oFieled14         NVARCHAR( 20) 	OUTPUT,
   @c_oFieled15         NVARCHAR( 20) 	OUTPUT,
   @b_Success          	INT = 1  		OUTPUT,
   @n_ErrNo            	INT      		OUTPUT, 
   @c_ErrMsg            NVARCHAR(250) 	OUTPUT
)
AS 
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQLStatement   nvarchar(2000), 
           @cSQLParms       nvarchar(2000)

   DECLARE @b_debug  int 
   SET @b_debug = 0

   IF @c_SPName = '' OR @c_SPName IS NULL
   BEGIN
      SET @b_Success = 0
      SET @n_ErrNo = 89451    
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'STOREDPROC Req'
      GOTO QUIT
   END
      
   IF @b_debug = 1
   BEGIN
     SELECT '@c_SPName', @c_SPName
   END

   IF @c_Storerkey = '' OR @c_Storerkey IS NULL
   BEGIN
      SET @b_Success = 0
      SET @n_ErrNo = 89452    
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'STORERKEY Req'
      GOTO QUIT
   END
      
   IF @b_debug = 1
   BEGIN
     SELECT '@c_Storerkey', @c_Storerkey
   END

   IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPName) AND type = 'P')
   BEGIN

	   SET @cSQLStatement = N'EXEC RDT.' + RTrim(@c_SPName) + 
			 ' @n_Mobile, 				@n_Func, 				@c_LangCode,'           +
			 ' @c_StorerKey,        @c_PickSlipNo,       @c_LOC, '               +
			 ' @c_PrefUOM,          @c_PickType,         @c_DropID, '            +
			 ' @c_ID        OUTPUT, @c_SKU       OUTPUT, @c_UOM       OUTPUT, '  + 
 			 ' @c_Lottable1 OUTPUT, @c_Lottable2 OUTPUT, @c_Lottable3 OUTPUT, '  + 
 			 ' @d_Lottable4 OUTPUT, @c_SKUDescr  OUTPUT, '                       +
          ' @c_oFieled01 OUTPUT, @c_oFieled02 OUTPUT, @c_oFieled03 OUTPUT,' 	+
          ' @c_oFieled04 OUTPUT, @c_oFieled05 OUTPUT, @c_oFieled06 OUTPUT,' 	+
          ' @c_oFieled07 OUTPUT, @c_oFieled08 OUTPUT, @c_oFieled09 OUTPUT,' 	+
          ' @c_oFieled10 OUTPUT, @c_oFieled11 OUTPUT, @c_oFieled12 OUTPUT,' 	+
          ' @c_oFieled13 OUTPUT, @c_oFieled14 OUTPUT, @c_oFieled15 OUTPUT,' 	+
          ' @b_Success   OUTPUT, @n_ErrNo     OUTPUT, @c_ErrMsg    OUTPUT '
	
	   SET @cSQLParms = N'@n_Mobile          	INT,        			 ' +
	                     '@n_Func        		INT,           		 ' +
                        '@c_LangCode         NVARCHAR( 3),         ' +
	                     '@c_StorerKey        NVARCHAR( 15),        ' +
                        '@c_PickSlipNo       NVARCHAR( 10),        ' +
                        '@c_LOC              NVARCHAR( 10),        ' +
                        '@c_PrefUOM          NVARCHAR( 1),        ' +
                        '@c_PickType         NVARCHAR( 1),        ' +
                        '@c_DropID           NVARCHAR( 18),        ' +
                        '@c_ID               NVARCHAR( 18) OUTPUT, ' +   
                        '@c_SKU              NVARCHAR( 20) OUTPUT, ' +   
                        '@c_UOM              NVARCHAR( 10) OUTPUT, ' +     
                        '@c_Lottable1        NVARCHAR( 18) OUTPUT, ' +     
                        '@c_Lottable2        NVARCHAR( 18) OUTPUT, ' +     
                        '@c_Lottable3        NVARCHAR( 18) OUTPUT, ' +     
                        '@d_Lottable4        DATETIME      OUTPUT, ' +     
                        '@c_SKUDescr         NVARCHAR( 60) OUTPUT, ' +      
	                     '@c_oFieled01        NVARCHAR( 20) OUTPUT, ' + 
	                     '@c_oFieled02        NVARCHAR( 20) OUTPUT, ' + 
	                     '@c_oFieled03        NVARCHAR( 20) OUTPUT, ' + 
	                     '@c_oFieled04        NVARCHAR( 20) OUTPUT, ' + 
	                     '@c_oFieled05        NVARCHAR( 20) OUTPUT, ' + 
	                     '@c_oFieled06        NVARCHAR( 20) OUTPUT, ' + 
	                     '@c_oFieled07        NVARCHAR( 20) OUTPUT, ' + 
	                     '@c_oFieled08        NVARCHAR( 20) OUTPUT, ' + 
	                     '@c_oFieled09        NVARCHAR( 20) OUTPUT, ' + 
	                     '@c_oFieled10        NVARCHAR( 20) OUTPUT, ' + 	
								'@c_oFieled11        NVARCHAR( 20) OUTPUT, ' + 	
								'@c_oFieled12        NVARCHAR( 20) OUTPUT, ' + 	
								'@c_oFieled13        NVARCHAR( 20) OUTPUT, ' + 	
								'@c_oFieled14        NVARCHAR( 20) OUTPUT, ' + 	
								'@c_oFieled15        NVARCHAR( 20) OUTPUT, ' + 	
                        '@b_Success          INT           OUTPUT, ' +                     
                        '@n_ErrNo            INT           OUTPUT, ' +
                        '@c_ErrMsg           NVARCHAR(250) OUTPUT  ' 
                        
	   EXEC sp_ExecuteSQL @cSQLStatement, @cSQLParms,    
             @n_Mobile
            ,@n_Func
            ,@c_LangCode
	         ,@c_StorerKey  
            ,@c_PickSlipNo 
            ,@c_LOC 
            ,@c_PrefUOM 
            ,@c_PickType 
            ,@c_DropID 
            ,@c_ID            OUTPUT   
            ,@c_SKU           OUTPUT  
            ,@c_UOM           OUTPUT  
            ,@c_Lottable1     OUTPUT  
            ,@c_Lottable2     OUTPUT  
            ,@c_Lottable3     OUTPUT  
            ,@d_Lottable4     OUTPUT  
            ,@c_SKUDescr      OUTPUT   
	         ,@c_oFieled01     OUTPUT
	         ,@c_oFieled02     OUTPUT
	         ,@c_oFieled03     OUTPUT
	         ,@c_oFieled04     OUTPUT
	         ,@c_oFieled05     OUTPUT
	         ,@c_oFieled06     OUTPUT
	         ,@c_oFieled07     OUTPUT
	         ,@c_oFieled08     OUTPUT
	         ,@c_oFieled09     OUTPUT
	         ,@c_oFieled10     OUTPUT
	         ,@c_oFieled11     OUTPUT
	         ,@c_oFieled12     OUTPUT
	         ,@c_oFieled13     OUTPUT
	         ,@c_oFieled14     OUTPUT
	         ,@c_oFieled15     OUTPUT
            ,@b_Success       OUTPUT
	         ,@n_ErrNo         OUTPUT
	         ,@c_ErrMsg        OUTPUT
   END

--   INSERT INTO TRACEINFO (TRACENAME, TIMEIN, COL1, COL2, COL3, COL4, COL5) VALUES 
--   ('MHD1', GETDATE(), @c_SKU, @c_UOM, @c_Lottable1, @c_Lottable2, @c_Lottable3)

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
     SELECT '@c_oFieled11', @c_oFieled10
     SELECT '@c_oFieled12', @c_oFieled10
     SELECT '@c_oFieled13', @c_oFieled10
     SELECT '@c_oFieled14', @c_oFieled10
     SELECT '@c_oFieled15', @c_oFieled10
     SELECT '@c_ErrMsg', @c_ErrMsg
   END

QUIT:
END -- procedure


GO
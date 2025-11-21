SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: RDT_GetSuggestedLoc_Wrapper                         */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Get Suggested Loc Wrapper SP                                */
/*                                                                      */
/* Called from:                                                         */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 27-Dec-2012 1.0  James       Created                                 */
/* 10-Jun-2014 1.1  James       Revamp error msg (james01)              */
/************************************************************************/

CREATE PROC [RDT].[RDT_GetSuggestedLoc_Wrapper] (
	@n_Mobile				INT, 
   @n_Func					INT,
	@c_LangCode	        	NVARCHAR(3),
   @c_SPName           	NVARCHAR( 250),
   @c_Storerkey         NVARCHAR( 15),
   @c_OrderKey          NVARCHAR( 10),
   @c_PickSlipNo        NVARCHAR( 10),
   @c_SKU               NVARCHAR( 20),
   @c_FromLoc           NVARCHAR( 10),
   @c_FromID            NVARCHAR( 18),
	@c_oFieled01        	NVARCHAR( 20) 	OUTPUT,
	@c_oFieled02        	NVARCHAR( 20) 	OUTPUT,
   @c_oFieled03        	NVARCHAR( 20) 	OUTPUT,
   @c_oFieled04        	NVARCHAR( 20) 	OUTPUT,
   @c_oFieled05        	NVARCHAR( 20) 	OUTPUT,
   @c_oFieled06        	NVARCHAR( 20) 	OUTPUT,
   @c_oFieled07        	NVARCHAR( 20) 	OUTPUT,
   @c_oFieled08        	NVARCHAR( 20) 	OUTPUT,
   @c_oFieled09        	NVARCHAR( 20) 	OUTPUT,
   @c_oFieled10        	NVARCHAR( 20) 	OUTPUT,
   @c_oFieled11        	NVARCHAR( 20) 	OUTPUT,
   @c_oFieled12        	NVARCHAR( 20) 	OUTPUT,
   @c_oFieled13        	NVARCHAR( 20) 	OUTPUT,
   @c_oFieled14        	NVARCHAR( 20) 	OUTPUT,
   @c_oFieled15        	NVARCHAR( 20) 	OUTPUT,
   @b_Success          	INT = 1  		OUTPUT,
   @n_ErrNo            	INT      		OUTPUT, 
   @c_ErrMsg           	NVARCHAR(250) 	OUTPUT
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
      SET @n_ErrNo = 89501    
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
      SET @n_ErrNo = 89502    
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
			 ' @n_Mobile, 				     @n_Func, 				     @c_LangCode,    '           +
			 ' @c_Storerkey,             @c_OrderKey,            @c_PickSlipNo,  '           +
			 ' @c_SKU,                   @c_FromLoc,             @c_FromID,      '           +
          ' @c_oFieled01      OUTPUT, @c_oFieled02    OUTPUT, @c_oFieled03    OUTPUT,' 	+
          ' @c_oFieled04      OUTPUT, @c_oFieled05    OUTPUT, @c_oFieled06    OUTPUT,' 	+
          ' @c_oFieled07      OUTPUT, @c_oFieled08    OUTPUT, @c_oFieled09    OUTPUT,' 	+
          ' @c_oFieled10      OUTPUT, @c_oFieled11    OUTPUT, @c_oFieled12    OUTPUT,' 	+
          ' @c_oFieled13      OUTPUT, @c_oFieled14    OUTPUT, @c_oFieled15    OUTPUT,' 	+
          ' @b_Success        OUTPUT, @n_ErrNo        OUTPUT, @c_ErrMsg       OUTPUT '
	
	   SET @cSQLParms = N'@n_Mobile          	INT,        			 ' +
	                     '@n_Func        		INT,           		 ' +
                        '@c_LangCode         NVARCHAR( 3),         ' +
                        '@c_Storerkey        NVARCHAR( 15),        ' +
                        '@c_OrderKey         NVARCHAR( 10),        ' +
                        '@c_PickSlipNo       NVARCHAR( 10),        ' +
                        '@c_SKU              NVARCHAR( 20),        ' +
                        '@c_FromLoc          NVARCHAR( 10),        ' +
                        '@c_FromID           NVARCHAR( 18),        ' +
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
                        '@c_ErrMsg           NVARCHAR(250) OUTPUT 	' 
                        
	   
	   EXEC sp_ExecuteSQL @cSQLStatement, @cSQLParms,    
             @n_Mobile
            ,@n_Func
            ,@c_LangCode
            ,@c_Storerkey
            ,@c_OrderKey
            ,@c_PickSlipNo
            ,@c_SKU     
            ,@c_FromLoc
            ,@c_FromID
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
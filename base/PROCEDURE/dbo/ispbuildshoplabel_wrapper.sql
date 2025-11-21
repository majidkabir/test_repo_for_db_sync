SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: ispBuildShopLabel_Wrapper                           */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Build IDX Shop Label wrapper                                */
/*                                                                      */
/* Called from:                                                         */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2014-04-02  1.0  James       SOS307345 Created                       */ 
/* 2014-10-28  1.1  James       SOS324404 Extend var length (james01)   */     
/************************************************************************/
CREATE PROC [dbo].[ispBuildShopLabel_Wrapper] (
   @c_SPName           NVARCHAR(250),
   @c_LoadKey          NVARCHAR( 10),
   @c_LabelType        NVARCHAR( 10),
   @c_StorerKey        NVARCHAR( 15),
   @c_DistCenter       NVARCHAR( 6),   -- (james01)
	@c_ShopNo	        NVARCHAR( 6),   -- (james01)
	@c_Section          NVARCHAR( 5) ,
	@c_Separate         NVARCHAR( 5) ,
   @n_BultoNo          INT,
   @c_LabelNo          NVARCHAR( 20) OUTPUT,
   @b_Success          INT = 1       OUTPUT,
   @n_ErrNo            INT           OUTPUT, 
   @c_ErrMsg           NVARCHAR(250) OUTPUT
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
      SET @n_ErrNo = 89851    
      SET @c_ErrMsg = CONVERT(Char(5), @n_ErrNo) + ' Stored Proc Not Setup. (ispBuildShopLabel_Wrapper)'
      GOTO QUIT
   END
      
   IF @b_debug = 1
   BEGIN
     SELECT '@c_SPName', @c_SPName
   END

   IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPName) AND type = 'P')
   BEGIN
	   SET @cSQLStatement = N'EXEC ' + RTrim(@c_SPName) + 
	       ' @cLoadKey,     @cLabelType,      @cStorerKey,      @cDistCenter,        @cShopNo, ' +
          ' @cSection,     @cSeparate,       @nBultoNo, ' +
          ' @cLabelNo OUTPUT, @bSuccess   OUTPUT, @nErrNo     OUTPUT, @cErrMsg    OUTPUT '
	
	   SET @cSQLParms = N'@cLoadKey          NVARCHAR( 10), ' +
                        '@cLabelType        NVARCHAR( 10), ' +
                        '@cStorerKey        NVARCHAR( 15), ' +
                        '@cDistCenter       NVARCHAR( 6),  ' + -- (james01)
                        '@cShopNo           NVARCHAR( 6),  ' + -- (james01)
	                     '@cSection          NVARCHAR( 5),  ' + 
	                     '@cSeparate         NVARCHAR( 5),  ' + 
	                     '@nBultoNo          INT,           ' + 
	                     '@cLabelNo          NVARCHAR(20)  OUTPUT, ' + 
                        '@bSuccess          INT           OUTPUT, ' +                     
                        '@nErrNo            INT           OUTPUT, ' +
                        '@cErrMsg           NVARCHAR(250) OUTPUT  ' 
                        
	   
	   EXEC sp_ExecuteSQL @cSQLStatement, @cSQLParms,    
            @c_LoadKey, 
            @c_LabelType, 
            @c_StorerKey, 
            @c_DistCenter, 
            @c_ShopNo, 
            @c_Section, 
            @c_Separate, 
            @n_BultoNo, 
            @c_LabelNo     OUTPUT, 
            @b_Success     OUTPUT, 
            @n_ErrNo       OUTPUT, 
            @c_ErrMsg      OUTPUT  
                        
   END


   IF @b_debug = 1
   BEGIN
     SELECT '@c_LoadKey',     @c_LoadKey
     SELECT '@c_LabelType',   @c_LabelType
     SELECT '@c_StorerKey',   @c_StorerKey
     SELECT '@c_DistCenter',  @c_DistCenter
     SELECT '@c_ShopNo',      @c_ShopNo
     SELECT '@c_Section',     @c_Section
     SELECT '@c_Separate',    @c_Separate
     SELECT '@n_BultoNo',     @n_BultoNo
     SELECT '@c_LabelNo',     @c_LabelNo
     SELECT '@b_Success',     @b_Success
     SELECT '@n_ErrNo',       @n_ErrNo
     SELECT '@c_ErrMsg',      @c_ErrMsg
   END

QUIT:
END -- procedure


GO
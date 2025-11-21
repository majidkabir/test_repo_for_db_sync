SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_PnPOrderCreation_Wrapper                        */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Pick confirm task wrapper                                   */
/*                                                                      */
/* Called from: rdtfnc_Pick                                             */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 11-Mar-2014 1.0  James       Created                                 */
/************************************************************************/

CREATE PROC [RDT].[rdt_PnPOrderCreation_Wrapper] (
	@n_Mobile				INT, 
   @n_Func					INT,
	@c_LangCode	        	NCHAR(3),
   @c_SPName           	NVARCHAR( 250),
   @c_Facility          NVARCHAR( 5),
   @c_StorerKey         NVARCHAR( 15),
   @c_Store             NVARCHAR( 15),
   @c_SKU               NVARCHAR( 20), 
   @n_Qty               INT, 
   @c_LabelNo           NVARCHAR( 20), 
   @c_DOID              NVARCHAR( 20),
   @c_Type              NVARCHAR( 1),
   @c_CartonType        NVARCHAR( 10),
   @c_OrderKey          NVARCHAR( 10)     OUTPUT,
   @c_SectionKey        NVARCHAR( 10)     OUTPUT,
   @b_Success           INT               OUTPUT,
   @n_ErrNo             INT               OUTPUT,
   @c_ErrMsg            NVARCHAR( 20)     OUTPUT
)
AS 
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQLStatement   nvarchar(2000), 
           @cSQLParms       nvarchar(2000) 

   DECLARE @c_UserName      NVARCHAR( 18)  

   DECLARE @b_debug  int 
   SET @b_debug = 0

   SELECT @c_UserName = UserName FROM RDT.RDTMOBREC WITH (NOLOCK) WHERE Mobile = @n_Mobile
   
   IF @c_SPName = '' OR @c_SPName IS NULL
   BEGIN
      SET @b_Success = 0
      SET @n_ErrNo = 89901    
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
      SET @n_ErrNo = 89902    
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
			 ' @nMobile, 				@nFunc, 				  @cLangCode,    ' +
			 ' @cFacility,          @cStorerKey,        @cStore,       ' +
			 ' @cSKU,               @nQty,              @cLabelNo,     ' +
			 ' @cDOID,              @cType,             @cCartonType,  ' +
			 ' @cOrderKey  OUTPUT,  @cSectionKey OUTPUT,             ' + 
			 ' @bSuccess   OUTPUT,  @nErrNo      OUTPUT, @cErrMsg   OUTPUT '
	
	   SET @cSQLParms = N'@nMobile          	INT,        			 ' +
	                     '@nFunc        		INT,           		 ' +
                        '@cLangCode          NVARCHAR( 3),         ' +
                        '@cFacility          NVARCHAR( 5),         ' +
                        '@cStorerKey         NVARCHAR( 15),        ' +
                        '@cStore             NVARCHAR( 15),        ' +
                        '@cSKU               NVARCHAR( 20),        ' +
                        '@nQty               INT,                  ' +
                        '@cLabelNo           NVARCHAR( 20),        ' +
                        '@cDOID              NVARCHAR( 20),        ' +
                        '@cType              NVARCHAR( 1),         ' +
                        '@cCartonType        NVARCHAR( 10),        ' +
                        '@cOrderKey          NVARCHAR( 10) OUTPUT, ' +
                        '@cSectionKey        NVARCHAR( 10) OUTPUT, ' +
                        '@bSuccess           INT           OUTPUT, ' +
                        '@nErrNo             INT           OUTPUT, ' +
                        '@cErrMsg            NVARCHAR( 20) OUTPUT  '

	   EXEC sp_ExecuteSQL @cSQLStatement, @cSQLParms,    
             @n_Mobile
            ,@n_Func
            ,@c_LangCode
            ,@c_Facility          
            ,@c_StorerKey         
            ,@c_Store          
            ,@c_SKU               
            ,@n_Qty              
            ,@c_LabelNo           
            ,@c_DOID               
            ,@c_Type            
            ,@c_CartonType  
            ,@c_OrderKey          OUTPUT
            ,@c_SectionKey        OUTPUT
            ,@b_Success           OUTPUT
            ,@n_ErrNo             OUTPUT
            ,@c_ErrMsg            OUTPUT
   END


QUIT:
END -- procedure


GO
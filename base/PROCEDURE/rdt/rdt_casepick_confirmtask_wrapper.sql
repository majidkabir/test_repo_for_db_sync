SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_CasePick_ConfirmTask_Wrapper                   */
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
               
CREATE PROC [RDT].[rdt_CasePick_ConfirmTask_Wrapper] (
	@n_Mobile				INT, 
   @n_Func					INT,
	@c_LangCode	        	NCHAR(3),
   @c_SPName           	NVARCHAR( 250),
   @c_StorerKey         NVARCHAR( 15),
   @c_UserName          NVARCHAR( 18),
   @c_Facility          NVARCHAR( 5),
   @c_Zone              NVARCHAR( 10),
   @c_SKU               NVARCHAR( 20),
   @c_LoadKey           NVARCHAR( 10),
   @c_LOC               NVARCHAR( 10),
   @c_LOT               NVARCHAR( 10),
   @c_ID                NVARCHAR( 18),
   @c_Status            NVARCHAR( 10),
   @c_PickSlipNo        NVARCHAR( 10),
   @c_PickUOM           NVARCHAR( 10),
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

   DECLARE @b_debug  int 
   SET @b_debug = 0

   IF @c_SPName = '' OR @c_SPName IS NULL
   BEGIN
      SET @b_Success = 0
      SET @n_ErrNo = 72991    
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
      SET @n_ErrNo = 72992    
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
			 ' @nMobile, 				@nFunc, 				  @cLangCode,    '                 +
			 ' @cStorerKey,         @cUserName,         @cFacility,    '                 +
			 ' @cZone,              @cSKU,              @cLoadKey,     '                 +
			 ' @cLOC,               @cLOT,              @cID,          '                 +
			 ' @cStatus,            @cPickSlipNo,       @cPickUOM,     '                 +
          ' @bSuccess    OUTPUT, @nErrNo      OUTPUT, @cErrMsg       OUTPUT '
	
	   SET @cSQLParms = N'@nMobile          	INT,        			 ' +
	                     '@nFunc        		INT,           		 ' +
                        '@cLangCode          NVARCHAR( 3),         ' +
                        '@cStorerKey         NVARCHAR( 15),        ' +
                        '@cUserName          NVARCHAR( 18),        ' +
                        '@cFacility          NVARCHAR( 5),         ' +
                        '@cZone              NVARCHAR( 10),        ' +
                        '@cSKU               NVARCHAR( 20),        ' +
                        '@cLoadKey           NVARCHAR( 10),        ' +
                        '@cLOC               NVARCHAR( 10),        ' +
                        '@cLOT               NVARCHAR( 10),        ' +
                        '@cID                NVARCHAR( 18),        ' +
                        '@cStatus            NVARCHAR( 10),        ' +
                        '@cPickSlipNo        NVARCHAR( 10),        ' +
                        '@cPickUOM           NVARCHAR( 10),        ' +
                        '@bSuccess           INT           OUTPUT, ' +
                        '@nErrNo             INT           OUTPUT, ' +
                        '@cErrMsg            NVARCHAR( 20) OUTPUT  '

	   EXEC sp_ExecuteSQL @cSQLStatement, @cSQLParms,    
             @n_Mobile
            ,@n_Func
            ,@c_LangCode
            ,@c_StorerKey         
            ,@c_UserName          
            ,@c_Facility          
            ,@c_Zone              
            ,@c_SKU               
            ,@c_LoadKey           
            ,@c_LOC               
            ,@c_LOT               
            ,@c_ID                
            ,@c_Status            
            ,@c_PickSlipNo        
            ,@c_PickUOM           
            ,@b_Success           OUTPUT
            ,@n_ErrNo             OUTPUT
            ,@c_ErrMsg            OUTPUT
   END


QUIT:
END -- procedure


GO
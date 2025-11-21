SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: RDT.rdt_Pick_ConfirmTask_Wrapper                    */
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
/* 25-Feb-2013 1.0  James       Created                                 */
/* 10-Jun-2014 1.1  James       Revamp error msg (james01)              */
/************************************************************************/

CREATE PROC [RDT].[rdt_Pick_ConfirmTask_Wrapper] (
	@n_Mobile				INT, 
   @n_Func					INT,
	@c_LangCode	        	NCHAR(3),
   @c_SPName           	NVARCHAR( 250),
   @c_PickSlipNo        NVARCHAR( 10),
   @c_DropID            NVARCHAR( 20),
   @c_LOC               NVARCHAR( 10),
   @c_ID                NVARCHAR( 18),
   @c_Storerkey         NVARCHAR( 15),
   @c_SKU               NVARCHAR( 20),
   @c_UOM               NVARCHAR( 10),
   @c_Lottable1         NVARCHAR( 18),
   @c_Lottable2         NVARCHAR( 18),
   @c_Lottable3         NVARCHAR( 18),
   @d_Lottable4         DATETIME,
   @n_TaskQTY           INT,   
   @n_PQTY              INT,   
   @c_UCCTask           NVARCHAR( 1),         -- Y = UCC, N = SKU/UPC  
   @c_PickType          NVARCHAR( 1),  
   @b_Success           INT               OUTPUT,
   @n_ErrNo             INT               OUTPUT,
   @c_ErrMsg            NVARCHAR( 20)      OUTPUT
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
      SET @n_ErrNo = 89551    
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
      SET @n_ErrNo = 89552    
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
			 ' @nMobile, 				@nFunc, 				   @cLangCode,    '                 +
			 ' @cPickSlipNo,        @cDropID,            @cLOC,         '                 +
			 ' @cID,                @cStorerKey,         @cSKU,         '                 +
			 ' @cUOM,               @cLottable1,         @cLottable2,   '                 +
			 ' @cLottable3,         @dLottable4,         @nTaskQTY,     '                 +
			 ' @nPQTY,              @cUCCTask,           @cPickType,    '                 +
          ' @bSuccess    OUTPUT, @nErrNo      OUTPUT, @cErrMsg       OUTPUT '
	
	   SET @cSQLParms = N'@nMobile          	INT,        			' +
	                     '@nFunc        		INT,           		' +
                        '@cLangCode         NVARCHAR( 3),         ' +
                        '@cPickSlipNo       NVARCHAR( 10),        ' +
                        '@cDropID           NVARCHAR( 20),        ' +
                        '@cLOC              NVARCHAR( 10),        ' +
                        '@cID               NVARCHAR( 18),        ' +
                        '@cStorerkey        NVARCHAR( 15),        ' +
                        '@cSKU              NVARCHAR( 20),        ' +
                        '@cUOM              NVARCHAR( 10),        ' +
                        '@cLottable1        NVARCHAR( 18),        ' +
                        '@cLottable2        NVARCHAR( 18),        ' +
                        '@cLottable3        NVARCHAR( 18),        ' +
                        '@dLottable4        DATETIME,             ' +
                        '@nTaskQTY          INT,                  ' +
                        '@nPQTY             INT,                  ' +
                        '@cUCCTask          NVARCHAR( 1),         ' +
                        '@cPickType         NVARCHAR( 1),         ' +
                        '@bSuccess          INT           OUTPUT, ' +
                        '@nErrNo            INT           OUTPUT, ' +
                        '@cErrMsg           NVARCHAR( 20) OUTPUT  '
                        
	   
	   EXEC sp_ExecuteSQL @cSQLStatement, @cSQLParms,    
             @n_Mobile
            ,@n_Func
            ,@c_LangCode
            ,@c_PickSlipNo        
            ,@c_DropID            
            ,@c_LOC               
            ,@c_ID                
            ,@c_Storerkey         
            ,@c_SKU               
            ,@c_UOM               
            ,@c_Lottable1         
            ,@c_Lottable2         
            ,@c_Lottable3         
            ,@d_Lottable4         
            ,@n_TaskQTY           
            ,@n_PQTY              
            ,@c_UCCTask           
            ,@c_PickType          
            ,@b_Success           OUTPUT
            ,@n_ErrNo             OUTPUT
            ,@c_ErrMsg            OUTPUT
   END


QUIT:
END -- procedure


GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: RDT.RDT_SortAndPackConfirmTask_Wrapper              */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Decode Label No Scanned                                     */
/*                                                                      */
/* Called from:                                                         */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2014-01-01  1.0  James       SOS299153 Created                       */
/* 2014-04-18  1.1  Chee        Add Parameter - @c_UCCNo (Chee01)       */
/* 2014-06-10  1.2  James       Revamp error msg (james01)              */
/************************************************************************/

CREATE PROC [RDT].[RDT_SortAndPackConfirmTask_Wrapper] (
	@n_Mobile				INT, 
   @n_Func					INT,
	@c_LangCode	         NVARCHAR(3),
   @c_SPName            NVARCHAR( 250),
   @c_PackByType        NVARCHAR( 10),
   @c_LoadKey           NVARCHAR( 10),
   @c_OrderKey          NVARCHAR( 10),
   @c_ConsigneeKey      NVARCHAR( 15),
   @c_Storerkey         NVARCHAR( 15),
   @c_SKU               NVARCHAR( 20),
   @n_Qty               INT,
   @c_PickSlipNo        NVARCHAR( 10),
   @c_LabelNo           NVARCHAR( 20),
   @c_CartonType        NVARCHAR( 10),
   @b_Success           INT = 1        OUTPUT,
   @n_ErrNo            	INT      		OUTPUT, 
   @c_ErrMsg            NVARCHAR(250) 	OUTPUT,
   @c_UCCNo             NVARCHAR(20)  = '' -- (Chee01)
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
      SET @n_ErrNo = 89601   
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
      SET @n_ErrNo = 89602  
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
			 ' @n_Mobile, 				@n_Func, 				@c_LangCode,'            +
			 ' @c_PackByType,       @c_LoadKey,          @c_OrderKey,'            +
			 ' @c_ConsigneeKey,     @c_Storerkey,        @c_SKU,'                 +
			 ' @n_Qty,              @c_LabelNo,          @c_CartonType,'          + 
          ' @b_Success   OUTPUT, @n_ErrNo     OUTPUT, @c_ErrMsg     OUTPUT '   + 
          CASE WHEN ISNULL(@c_UCCNo, '') <> '' THEN ', @c_UCCNo' ELSE '' END -- Chee01
	
	   SET @cSQLParms = N'@n_Mobile          	INT,                    ' +
	                     '@n_Func        		INT,           		   ' +
                        '@c_LangCode         NVARCHAR( 3),           ' +
                        '@c_PackByType       NVARCHAR( 10),          ' +
                        '@c_LoadKey          NVARCHAR( 10),          ' +
                        '@c_OrderKey         NVARCHAR( 10),          ' +
                        '@c_ConsigneeKey     NVARCHAR( 15),          ' +
                        '@c_Storerkey        NVARCHAR( 15),          ' +
                        '@c_SKU       	      NVARCHAR( 20),          ' +
                        '@n_Qty              INT,                    ' +
                        '@c_LabelNo          NVARCHAR( 20),          ' +
                        '@c_CartonType       NVARCHAR( 10),          ' +
                        '@b_Success          INT           OUTPUT,   ' +                     
                        '@n_ErrNo            INT           OUTPUT,   ' +
                        '@c_ErrMsg           NVARCHAR(250) OUTPUT,   ' + 
                        '@c_UCCNo            NVARCHAR(20)            ' -- Chee01
      
	   EXEC sp_ExecuteSQL @cSQLStatement, @cSQLParms,    
             @n_Mobile
            ,@n_Func
            ,@c_LangCode
            ,@c_PackByType
            ,@c_LoadKey
            ,@c_OrderKey
            ,@c_ConsigneeKey
            ,@c_Storerkey
            ,@c_SKU
            ,@n_Qty
            ,@c_LabelNo  
	         ,@c_CartonType
            ,@b_Success       OUTPUT
	         ,@n_ErrNo         OUTPUT
	         ,@c_ErrMsg        OUTPUT
            ,@c_UCCNo         -- Chee01
   END


   IF @b_debug = 1
   BEGIN
     SELECT '@b_Success', @b_Success
     SELECT '@n_ErrNo', @n_ErrNo
     SELECT '@c_ErrMsg', @c_ErrMsg
   END

QUIT:
END -- procedure


GO
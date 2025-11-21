SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispIICLblNoDecode01                                 */
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
/* 2021-01-07  1.0  James       WMS-16020. Created                      */
/* 2022-07-22  1.1  James       WMS-20209 1 ID 1 sku. SUM Qty (james01) */
/************************************************************************/

CREATE   PROCEDURE [dbo].[ispIICLblNoDecode01]
   @c_LabelNo          NVARCHAR(40),
   @c_Storerkey        NVARCHAR(15),
   @c_ReceiptKey       NVARCHAR(10),
   @c_POKey            NVARCHAR(10),
	@c_LangCode	        NVARCHAR(3),
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

   DECLARE @c_SKU       NVARCHAR( 20),
           @c_Lot01     NVARCHAR( 18), 
           @c_Lot02     NVARCHAR( 18), 
           @c_UserName  NVARCHAR( 18), 
           @c_WaveKey   NVARCHAR( 10), 
           @c_FromLoc   NVARCHAR( 10),
           @c_FromID    NVARCHAR( 18),
           @c_PackKey   NVARCHAR( 10),
           @c_ReplenishmentKey   NVARCHAR( 10),
           @n_Func      INT,
           @n_Step      INT,
           @n_InputKey  INT,
           @f_InnerPack FLOAT,
           @nQty        INT,
           @cFlowThruStep5 NVARCHAR( 1),
           @cInField03  NVARCHAR( 60)

   SELECT @n_Func = Func, 
          @n_Step = Step,
          @n_InputKey = InputKey,
          @c_FromLoc = V_Loc,    
          @c_FromID  = V_ID,    
          @c_WaveKey = V_String12,   
          @c_UserName = UserName,
          @cInField03 = I_Field03
   FROM rdt.rdtMobRec WITH (NOLOCK) 
   WHERE UserName = sUser_sName()
   
   SET @cFlowThruStep5 = rdt.RDTGetConfig( @n_Func, 'FlowThruStep5', @c_StorerKey)
   
   IF @cFlowThruStep5 = '1' AND @n_Step = 4 AND @n_InputKey = 1
   BEGIN
      SET @n_Step = 5
      SET @c_FromID = @cInField03   -- If flowthru turn on then from id not yet write onto rdtmobrec
   END
         
   IF @n_Step = 5
   BEGIN
      IF @n_InputKey = 1
      BEGIN
      	-- 1 Pallet 1 Sku
         SELECT TOP 1
            @c_ReplenishmentKey = ReplenishmentKey, 
            @c_SKU = SKU    
         FROM rdt.rdtReplenishmentLog WITH (NOLOCK)    
         WHERE StorerKey = @c_Storerkey     
         AND   WaveKey = @c_WaveKey    
         AND   FromLoc = @c_FromLoc    
         AND   ID  = @c_FromID    
         AND   Confirmed IN ( 'N', '1')     
         AND   AddWho = @c_UserName  
         ORDER BY 1
             
         SELECT @nQty = ISNULL( SUM( Qty), 0)    
         FROM rdt.rdtReplenishmentLog WITH (NOLOCK)    
         WHERE StorerKey = @c_Storerkey     
         AND   WaveKey = @c_WaveKey    
         AND   FromLoc = @c_FromLoc    
         AND   ID  = @c_FromID    
         AND   SKU = @c_SKU    
         AND   Confirmed IN ( 'N', '1')     
         AND   AddWho = @c_UserName  
                 
         SET @c_oFieled01 = @c_SKU
         SET @c_oFieled05 = 0
         SET @c_oFieled09 = @c_ReplenishmentKey   
         SET @c_oFieled10 = @nQty--@f_InnerPack
      END      
   END

QUIT:
END -- End Procedure


GO
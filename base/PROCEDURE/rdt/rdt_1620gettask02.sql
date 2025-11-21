SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_1620GETTASK02                                   */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Get next SKU to Pick                                        */  
/*                                                                      */
/* Called from: rdtfnc_Cluster_Pick                                     */  
/*                                                                      */  
/* Exceed version: 5.4                                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author      Purposes                                */  
/* 02-Sep-2016 1.0  James       SOS375742 - Created                     */  
/************************************************************************/  

CREATE PROC [RDT].[rdt_1620GETTASK02] (  
   @n_Mobile                  INT, 
   @n_Func                    INT, 
   @c_StorerKey               NVARCHAR( 15),  
   @c_UserName                NVARCHAR( 15),  
   @c_Facility                NVARCHAR( 5),  
   @c_PutAwayZone             NVARCHAR( 10),  
   @c_PickZone                NVARCHAR( 10),  
   @c_LangCode                NVARCHAR( 3),  
	@c_oFieled01               NVARCHAR( 20)      OUTPUT,
	@c_oFieled02               NVARCHAR( 20)      OUTPUT,
   @c_oFieled03               NVARCHAR( 20)      OUTPUT,
   @c_oFieled04               NVARCHAR( 20)      OUTPUT,
   @c_oFieled05               NVARCHAR( 20)      OUTPUT,
   @c_oFieled06               NVARCHAR( 20)      OUTPUT,
   @c_oFieled07               NVARCHAR( 20)      OUTPUT,
   @c_oFieled08               NVARCHAR( 20)      OUTPUT,
   @c_oFieled09               NVARCHAR( 20)      OUTPUT,
   @c_oFieled10               NVARCHAR( 20)      OUTPUT,
	@c_oFieled11               NVARCHAR( 20)      OUTPUT,
	@c_oFieled12               NVARCHAR( 20)      OUTPUT,
   @c_oFieled13               NVARCHAR( 20)      OUTPUT,
   @c_oFieled14               NVARCHAR( 20)      OUTPUT,
   @c_oFieled15               NVARCHAR( 20)      OUTPUT, 
   @b_Success                 INT                OUTPUT, 
   @nErrNo                    INT                OUTPUT,   
   @cErrMsg                   NVARCHAR( 20)      OUTPUT 
)
AS
BEGIN
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_err             INT
   DECLARE @c_errmsg          NVARCHAR( 250),
           @cORD_StorerKey    NVARCHAR( 15),    
           @nMultiStorer      INT               

   SET @nMultiStorer = 0
   IF EXISTS (SELECT 1 FROM dbo.StorerGroup WITH (NOLOCK) WHERE StorerGroup = @c_StorerKey)
      SET @nMultiStorer = 1

   SELECT TOP 1
      @c_oFieled01 = PD.Loc,
      @c_oFieled02 = PD.OrderKey,
      @c_oFieled03 = PD.SKU,
      @c_oFieled09 = PD.LOT,
      @c_oFieled10 = PD.PickSlipNo
   FROM RDT.RDTPickLock RPL WITH (NOLOCK)
   JOIN dbo.PickDetail PD WITH (NOLOCK) ON (RPL.StorerKey = PD.StorerKey AND RPL.OrderKey = PD.OrderKey)
   JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
   WHERE RPL.StorerKey = CASE WHEN @nMultiStorer = 1 THEN RPL.StorerKey ELSE @c_StorerKey END
      AND RPL.Status < '9'
      AND RPL.AddWho = @c_UserName
      AND PD.Status = '0'
      AND L.PutAwayZone = CASE WHEN @c_PutAwayZone = 'ALL' THEN L.PutAwayZone ELSE @c_PutAwayZone END
      AND L.PickZone = CASE WHEN ISNULL(@c_PickZone, '') = '' THEN L.PickZone ELSE @c_PickZone END
      AND L.Facility = @c_Facility
      AND NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock SKIP_RPL WITH (NOLOCK)
                      WHERE SKIP_RPL.OrderKey = PD.OrderKey
                      AND SKIP_RPL.StorerKey = RPL.StorerKey  
                      AND SKIP_RPL.SKU = PD.SKU
                      AND SKIP_RPL.AddWho = @c_UserName
                      AND SKIP_RPL.Status = 'X')
      -- Not to get the same loc within the same orders
      AND NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock SKIP_RPL2 WITH (NOLOCK)
                      WHERE SKIP_RPL2.OrderKey = PD.OrderKey
                      AND SKIP_RPL2.StorerKey = RPL.StorerKey  
                      AND SKIP_RPL2.AddWho <> @c_UserName
                      AND SKIP_RPL2.Status = '1'
                      AND SKIP_RPL2.LOC = pd.LOC )  
   ORDER BY L.LogicalLocation, PD.LOC, PD.SKU, RPL.OrderKey    

   IF @@ROWCOUNT = 0  
   BEGIN  
      -- Look for task for another storer within defined storergroup 
      IF @nMultiStorer = 1
      BEGIN
         SELECT TOP 1
            @c_oFieled01 = PD.Loc,
            @c_oFieled02 = PD.OrderKey,
            @c_oFieled03 = PD.SKU,
            @c_oFieled09 = PD.LOT,
            @c_oFieled10 = PD.PickSlipNo
         FROM dbo.PickDetail PD WITH (NOLOCK) 
         JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
         JOIN dbo.StorerGroup SG WITH (NOLOCK) ON (PD.StorerKey = SG.StorerKey AND SG.StorerGroup = @c_StorerKey)
         WHERE PD.Status = '0'
            AND L.PutAwayZone = CASE WHEN @c_PutAwayZone = 'ALL' THEN L.PutAwayZone ELSE @c_PutAwayZone END
            AND L.PickZone = CASE WHEN ISNULL(@c_PickZone, '') = '' THEN L.PickZone ELSE @c_PickZone END
            AND L.Facility = @c_Facility
            AND NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock SKIP_RPL WITH (NOLOCK)
                            WHERE SKIP_RPL.OrderKey = PD.OrderKey
                            AND SKIP_RPL.StorerKey = PD.StorerKey  
                            AND SKIP_RPL.SKU = PD.SKU
                            AND SKIP_RPL.AddWho = @c_UserName
                            AND SKIP_RPL.Status = 'X')
            -- Not to get the same loc within the same orders
            AND NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock SKIP_RPL2 WITH (NOLOCK)
                            WHERE SKIP_RPL2.OrderKey = PD.OrderKey
                            AND SKIP_RPL2.StorerKey = PD.StorerKey  -- TLTING02
                            AND SKIP_RPL2.AddWho <> @c_UserName
                            AND SKIP_RPL2.Status = '1'
                            AND SKIP_RPL2.LOC = PD.LOC )  -- james02
         ORDER BY L.LogicalLocation, PD.LOC, PD.SKU, PD.OrderKey    
      END
      
      IF @@ROWCOUNT = 0
      BEGIN
         SET @c_oFieled02 = ''  
         GOTO Quit  
      END
   END  
   
   IF @nMultiStorer = 1
      SELECT @cORD_StorerKey = StorerKey FROM dbo.Orders WITH (NOLOCK) WHERE OrderKey = @c_oFieled02
      
   SELECT @c_oFieled04 = SKU.DESCR,
      @c_oFieled05 = SKU.Style,
      @c_oFieled06 = SKU.Color,
      @c_oFieled07 = SKU.Size,
      @c_oFieled08 = SUBSTRING( SKU.DESCR, 1, 20)
   FROM dbo.SKU SKU WITH (NOLOCK)
   WHERE SKU.Storerkey = CASE WHEN @nMultiStorer = 1 THEN @cORD_StorerKey ELSE @c_StorerKey END
   AND SKU.SKU         = @c_oFieled03

   SET @c_oFieled06 = @c_oFieled06 + ' '

   SELECT
      @c_oFieled11 = ExternOrderKey,
      @c_oFieled12 = ConsigneeKey
   FROM dbo.Orders WITH (NOLOCK)
   WHERE StorerKey = CASE WHEN @nMultiStorer = 1 THEN @cORD_StorerKey ELSE @c_StorerKey END
      AND OrderKey = @c_oFieled02

Quit:
END


GO
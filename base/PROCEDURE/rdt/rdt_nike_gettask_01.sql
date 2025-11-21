SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/  
/* Store procedure: rdt_NIKE_GETTASK_01                                 */  
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
/* 07-Apr-2011 1.0  James       Created                                 */  
/* 06-Dec-2017 1.1  James       Bug fix (james01)                       */
/* 12-Jun-2018 1.2  James       WMS4338 - Add sorting condition to cater*/
/*                              for multiple sku 1 loc (james01)        */
/* 03-Jul-2018 1.3  James       Comment @cCurrSKU (james02)             */
/* 06-Jul-2018 1.4  James       INC0295949 Perf tunning (james03)       */
/************************************************************************/  

CREATE PROC [RDT].[rdt_NIKE_GETTASK_01] (  
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
   @b_Success                 INT            OUTPUT, 
   @nErrNo                    INT            OUTPUT,   
   @cErrMsg                   NVARCHAR( 20)   OUTPUT 
)  
AS  
BEGIN  
SET NOCOUNT ON  
SET QUOTED_IDENTIFIER OFF  
SET ANSI_NULLS OFF  
SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @cSize_Seq   NVARCHAR( 30),
           @cLoadKey    NVARCHAR( 10),
           @cWaveKey    NVARCHAR( 10),
           @cCurrSKU    NVARCHAR( 20)

   SELECT @cLoadKey = V_LoadKey, 
          @cWaveKey = V_String1,
          @cCurrSKU = V_SKU
   FROM rdt.rdtMOBREC WITH (NOLOCK)
   WHERE Mobile = @n_Mobile

   IF ISNULL( @cWaveKey, '') = ''
   BEGIN
      SELECT TOP 1   
         @c_oFieled01   = PD.Loc,   
         @c_oFieled02   = PD.OrderKey,  
         @c_oFieled03   = SKU.SKU,  
         @c_oFieled04   = SKU.DESCR,
         @c_oFieled05   = SKU.Style,
         @c_oFieled06   = SKU.Color,
         @c_oFieled07   = SKU.Size,
         @c_oFieled08   = SKU.BUSR7,
         @c_oFieled09   = PD.LOT,  
         @c_oFieled10   = PD.PickSlipNo 
      FROM RDT.RDTPickLock RPL WITH (NOLOCK)  
      JOIN dbo.PickDetail PD WITH (NOLOCK) ON (RPL.StorerKey = PD.StorerKey AND RPL.OrderKey = PD.OrderKey)  
      JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
      JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)  
      WHERE RPL.StorerKey = @c_StorerKey  
         AND RPL.Status < '5'  
         AND RPL.AddWho = @c_UserName  
         AND PD.Status = '0'  
         AND (( ISNULL( @c_PutAwayZone, '') = 'ALL') OR ( L.PutAwayZone = @c_PutAwayZone))
         AND (( ISNULL( @c_PickZone, '') = '') OR ( L.PickZone = @c_PickZone))
         AND L.Facility = @c_Facility  
         AND NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock SKIP_RPL WITH (NOLOCK) 
                         WHERE SKIP_RPL.OrderKey = PD.OrderKey
                         AND SKIP_RPL.SKU = PD.SKU
                         AND SKIP_RPL.AddWho = @c_UserName
                         AND SKIP_RPL.Status = 'X')
         -- Not to get the same loc within the same orders
         AND NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock SKIP_RPL2 WITH (NOLOCK)
                           WHERE SKIP_RPL2.OrderKey = PD.OrderKey
                           AND SKIP_RPL2.StorerKey = RPL.StorerKey  -- TLTING02
                           AND SKIP_RPL2.AddWho <> @c_UserName
                           AND SKIP_RPL2.Status = '1'
                           AND SKIP_RPL2.LOC = pd.LOC )  -- james02

      ORDER BY L.LogicalLocation, PD.LOC, SKU.Style, SKU.Color, SKU.BUSR6, SKU.SKU, PD.OrderKey

      IF @@ROWCOUNT = 0
      BEGIN
         SELECT TOP 1   
            @c_oFieled01   = PD.Loc,   
            @c_oFieled02   = PD.OrderKey,  
            @c_oFieled03   = SKU.SKU,  
            @c_oFieled04   = SKU.DESCR,
            @c_oFieled05   = SKU.Style,
            @c_oFieled06   = SKU.Color,
            @c_oFieled07   = SKU.Size,
            @c_oFieled08   = SKU.BUSR7,
            @c_oFieled09   = PD.LOT,  
            @c_oFieled10   = PD.PickSlipNo 
         FROM dbo.PickDetail PD WITH (NOLOCK) 
         JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PD.OrderKey = LPD.OrderKey
         JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
         JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)  
         WHERE PD.StorerKey = @c_StorerKey  
            AND PD.Status = '0'  
            AND (( ISNULL( @c_PutAwayZone, '') = 'ALL') OR ( L.PutAwayZone = @c_PutAwayZone))
            AND (( ISNULL( @c_PickZone, '') = '') OR ( L.PickZone = @c_PickZone))
            AND L.Facility = @c_Facility  
            AND LPD.LoadKey = @cLoadKey
            -- Cater for short pick or user change tote/dropid then sku not exists in rdtpicklock 
            --AND (( ISNULL( @cCurrSKU, '') = '') OR ( PD.SKU = @cCurrSKU))  
            -- Not to get the same loc within the same orders
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
         ORDER BY L.LogicalLocation, PD.LOC, SKU.Style, SKU.Color, SKU.BUSR6, SKU.SKU, PD.OrderKey
      END

      IF @@ROWCOUNT = 0
      BEGIN
         SELECT TOP 1   
            @c_oFieled01   = PD.Loc,   
            @c_oFieled02   = PD.OrderKey,  
            @c_oFieled03   = SKU.SKU,  
            @c_oFieled04   = SKU.DESCR,
            @c_oFieled05   = SKU.Style,
            @c_oFieled06   = SKU.Color,
            @c_oFieled07   = SKU.Size,
            @c_oFieled08   = SKU.BUSR7,
            @c_oFieled09   = PD.LOT,  
            @c_oFieled10   = PD.PickSlipNo 
         FROM dbo.PickDetail PD WITH (NOLOCK) 
         JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PD.OrderKey = LPD.OrderKey
         JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
         JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)  
         WHERE PD.StorerKey = @c_StorerKey  
            AND PD.Status = '0'  
            AND (( ISNULL( @c_PutAwayZone, '') = 'ALL') OR ( L.PutAwayZone = @c_PutAwayZone))
            AND (( ISNULL( @c_PickZone, '') = '') OR ( L.PickZone = @c_PickZone))
            AND L.Facility = @c_Facility  
            AND LPD.LoadKey = @cLoadKey
            -- Not to get the same loc within the same orders
            AND NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock SKIP_RPL WITH (NOLOCK)
                              WHERE SKIP_RPL.OrderKey = PD.OrderKey
                              AND SKIP_RPL.StorerKey = PD.StorerKey  
                              AND SKIP_RPL.SKU = PD.SKU
                              AND SKIP_RPL.AddWho = @c_UserName
                              AND SKIP_RPL.Status = 'X')
         ORDER BY L.LogicalLocation, PD.LOC, SKU.Style, SKU.Color, SKU.BUSR6, SKU.SKU, PD.OrderKey
      END
   END
   ELSE
   BEGIN
      SELECT TOP 1   
         @c_oFieled01   = PD.Loc,   
         @c_oFieled02   = PD.OrderKey,  
         @c_oFieled03   = SKU.SKU,  
         @c_oFieled04   = SKU.DESCR,
         @c_oFieled05   = SKU.Style,
         @c_oFieled06   = SKU.Color,
         @c_oFieled07   = SKU.Size,
         @c_oFieled08   = SKU.BUSR7,
         @c_oFieled09   = PD.LOT,  
         @c_oFieled10   = PD.PickSlipNo 
      FROM RDT.RDTPickLock RPL WITH (NOLOCK)  
      JOIN dbo.PickDetail PD WITH (NOLOCK) ON (RPL.StorerKey = PD.StorerKey AND RPL.OrderKey = PD.OrderKey)  
      JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
      JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)  
      WHERE RPL.StorerKey = @c_StorerKey  
         AND RPL.Status < '5'  
         AND RPL.AddWho = @c_UserName  
         AND PD.Status = '0'  
         AND (( ISNULL( @c_PutAwayZone, '') = 'ALL') OR ( L.PutAwayZone = @c_PutAwayZone))
         AND (( ISNULL( @c_PickZone, '') = '') OR ( L.PickZone = @c_PickZone))
         AND L.Facility = @c_Facility  
         AND NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock SKIP_RPL WITH (NOLOCK) 
                         WHERE SKIP_RPL.OrderKey = PD.OrderKey
                         AND SKIP_RPL.SKU = PD.SKU
                         AND SKIP_RPL.AddWho = @c_UserName
                         AND SKIP_RPL.Status = 'X')
         -- Not to get the same loc within the same orders
         AND NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock SKIP_RPL2 WITH (NOLOCK)
                           WHERE SKIP_RPL2.OrderKey = PD.OrderKey
                           AND SKIP_RPL2.StorerKey = RPL.StorerKey  -- TLTING02
                           AND SKIP_RPL2.AddWho <> @c_UserName
                           AND SKIP_RPL2.Status = '1'
                           AND SKIP_RPL2.LOC = pd.LOC )  -- james02

      ORDER BY L.LogicalLocation, PD.LOC, SKU.Style, SKU.Color, SKU.BUSR6, SKU.SKU, PD.OrderKey

      IF @@ROWCOUNT = 0
      BEGIN
         SELECT TOP 1   
            @c_oFieled01   = PD.Loc,   
            @c_oFieled02   = PD.OrderKey,  
            @c_oFieled03   = SKU.SKU,  
            @c_oFieled04   = SKU.DESCR,
            @c_oFieled05   = SKU.Style,
            @c_oFieled06   = SKU.Color,
            @c_oFieled07   = SKU.Size,
            @c_oFieled08   = SKU.BUSR7,
            @c_oFieled09   = PD.LOT,  
            @c_oFieled10   = PD.PickSlipNo 
         FROM dbo.PickDetail PD WITH (NOLOCK) 
         --JOIN dbo.Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey
         JOIN dbo.ORDERDETAIL OD WITH (NOLOCK) ON PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber
         JOIN dbo.Orders O WITH (NOLOCK) ON OD.OrderKey = O.OrderKey AND PD.StorerKey = O.StorerKey
         JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
         JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)  
         WHERE PD.StorerKey = @c_StorerKey  
            AND PD.Status = '0'  
            AND OD.StorerKey = @c_StorerKey
            AND (( ISNULL( @c_PutAwayZone, '') = 'ALL') OR ( L.PutAwayZone = @c_PutAwayZone))
            AND (( ISNULL( @c_PickZone, '') = '') OR ( L.PickZone = @c_PickZone))
            AND L.Facility = @c_Facility  
            AND (( ISNULL( @cWaveKey, '') = '') OR ( O.UserDefine09 = @cWaveKey))
            AND (( ISNULL( @cLoadKey, '') = '') OR ( O.LoadKey = @cLoadKey))
            -- Cater for short pick or user change tote/dropid then sku not exists in rdtpicklock 
            --AND (( ISNULL( @cCurrSKU, '') = '') OR ( PD.SKU = @cCurrSKU))  
            -- Not to get the same loc within the same orders
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
         ORDER BY L.LogicalLocation, PD.LOC, SKU.Style, SKU.Color, SKU.BUSR6, SKU.SKU, PD.OrderKey
      END

      IF @@ROWCOUNT = 0
      BEGIN
         SELECT TOP 1   
            @c_oFieled01   = PD.Loc,   
            @c_oFieled02   = PD.OrderKey,  
            @c_oFieled03   = SKU.SKU,  
            @c_oFieled04   = SKU.DESCR,
            @c_oFieled05   = SKU.Style,
            @c_oFieled06   = SKU.Color,
            @c_oFieled07   = SKU.Size,
            @c_oFieled08   = SKU.BUSR7,
            @c_oFieled09   = PD.LOT,  
            @c_oFieled10   = PD.PickSlipNo 
         FROM dbo.PickDetail PD WITH (NOLOCK) 
         JOIN dbo.Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey
         JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
         JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)  
         WHERE PD.StorerKey = @c_StorerKey  
            AND PD.Status = '0'  
            AND (( ISNULL( @c_PutAwayZone, '') = 'ALL') OR ( L.PutAwayZone = @c_PutAwayZone))
            AND (( ISNULL( @c_PickZone, '') = '') OR ( L.PickZone = @c_PickZone))
            AND L.Facility = @c_Facility  
            AND (( ISNULL( @cWaveKey, '') = '') OR ( O.UserDefine09 = @cWaveKey))
            AND (( ISNULL( @cLoadKey, '') = '') OR ( O.LoadKey = @cLoadKey))
            -- Not to get the same loc within the same orders
            AND NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock SKIP_RPL WITH (NOLOCK)
                              WHERE SKIP_RPL.OrderKey = PD.OrderKey
                              AND SKIP_RPL.StorerKey = PD.StorerKey  
                              AND SKIP_RPL.SKU = PD.SKU
                              AND SKIP_RPL.AddWho = @c_UserName
                              AND SKIP_RPL.Status = 'X')
         ORDER BY L.LogicalLocation, PD.LOC, SKU.Style, SKU.Color, SKU.BUSR6, SKU.SKU, PD.OrderKey
      END
   END

   SELECT 
      @c_oFieled11   = ExternOrderKey,  
      @c_oFieled12   = ConsigneeKey  
   FROM dbo.Orders WITH (NOLOCK) 
   WHERE StorerKey = @c_StorerKey  
      AND OrderKey = @c_oFieled02
END 

GO
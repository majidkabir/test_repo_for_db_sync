SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/  
/* Store procedure: rdt_1620GETTASK07                                   */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Search pick task for same sku -> same style -> any pick task*/  
/*                                                                      */
/* Called from: rdtfnc_Cluster_Pick                                     */  
/*                                                                      */  
/* Exceed version: 5.4                                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author      Purposes                                */  
/* 2021-09-17  1.0  James       WMS-17913. Created                      */  
/************************************************************************/  

CREATE PROC [RDT].[rdt_1620GETTASK07] (  
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

   DECLARE @c_LOC    NVARCHAR( 10)
   DECLARE @n_Step   INT
   DECLARE @c_SKU    NVARCHAR( 20)
   DECLARE @c_Style  NVARCHAR( 20)
   DECLARE @n_RowCnt INT
   
   SELECT @n_Step = Step, 
          @c_LOC = V_LOC,
          @c_SKU = V_SKU
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @n_Mobile
   
   IF @n_Step = 6
   BEGIN
      SET @c_LOC = ''      

      SELECT TOP 1
         @c_oFieled01   = PD.Loc,   
         @c_oFieled02   = PD.OrderKey,  
         @c_oFieled03   = PD.SKU,  
         @c_oFieled09   = PD.LOT,  
         @c_oFieled10   = PD.PickSlipNo 
      FROM RDT.RDTPickLock RPL WITH (NOLOCK)
      JOIN dbo.PickDetail PD WITH (NOLOCK) ON (RPL.StorerKey = PD.StorerKey AND RPL.OrderKey = PD.OrderKey)
      JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
      WHERE RPL.StorerKey = @c_StorerKey
         AND RPL.Status < '9'
         AND RPL.AddWho = @c_UserName
         AND PD.Status = '0'
         AND (( ISNULL( @c_PutAwayZone, '') = 'ALL') OR ( L.PutAwayZone = @c_PutAwayZone))
         AND (( ISNULL(@c_PickZone, '') = '') OR ( L.PickZone = @c_PickZone))
         AND L.Facility = @c_Facility
         AND L.LOC >= @c_LOC
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
      SELECT @n_RowCnt = @@ROWCOUNT
      
      IF @n_RowCnt = 0  
      BEGIN  
         GOTO Quit  
      END  
   END
   ELSE
   BEGIN
      -- Search same sku pick task
      SELECT TOP 1
         @c_oFieled01   = PD.Loc,   
         @c_oFieled02   = PD.OrderKey,  
         @c_oFieled03   = PD.SKU,  
         @c_oFieled09   = PD.LOT,  
         @c_oFieled10   = PD.PickSlipNo 
      FROM RDT.RDTPickLock RPL WITH (NOLOCK)
      JOIN dbo.PickDetail PD WITH (NOLOCK) ON (RPL.StorerKey = PD.StorerKey AND RPL.OrderKey = PD.OrderKey)
      JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
      WHERE RPL.StorerKey = @c_StorerKey
         AND RPL.Status < '9'
         AND RPL.AddWho = @c_UserName
         AND PD.Status = '0'
         AND PD.SKU = @c_SKU
         AND (( ISNULL( @c_PutAwayZone, '') = 'ALL') OR ( L.PutAwayZone = @c_PutAwayZone))
         AND (( ISNULL(@c_PickZone, '') = '') OR ( L.PickZone = @c_PickZone))
         AND L.Facility = @c_Facility
         --AND L.LOC >= @c_LOC
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
      SELECT @n_RowCnt = @@ROWCOUNT
      
      -- Serach same sku style pick task
      IF @n_RowCnt = 0
      BEGIN
         SELECT @c_Style = Style
         FROM dbo.SKU WITH (NOLOCK)
         WHERE StorerKey = @c_StorerKey
         AND   Sku = @c_SKU

         SELECT TOP 1
            @c_oFieled01   = PD.Loc,   
            @c_oFieled02   = PD.OrderKey,  
            @c_oFieled03   = PD.SKU,  
            @c_oFieled09   = PD.LOT,  
            @c_oFieled10   = PD.PickSlipNo 
         FROM RDT.RDTPickLock RPL WITH (NOLOCK)
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON (RPL.StorerKey = PD.StorerKey AND RPL.OrderKey = PD.OrderKey)
         JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
         JOIN dbo.SKU SKU WITH (NOLOCK) ON ( PD.Storerkey = SKU.StorerKey AND PD.Sku = SKU.Sku)
         WHERE RPL.StorerKey = @c_StorerKey
            AND RPL.Status < '9'
            AND RPL.AddWho = @c_UserName
            AND PD.Status = '0'
            AND (( ISNULL( @c_PutAwayZone, '') = 'ALL') OR ( L.PutAwayZone = @c_PutAwayZone))
            AND (( ISNULL(@c_PickZone, '') = '') OR ( L.PickZone = @c_PickZone))
            AND L.Facility = @c_Facility
            --AND L.LOC >= @c_LOC
            AND SKU.Style = @c_Style
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
         SELECT @n_RowCnt = @@ROWCOUNT
         --IF @n_Mobile = 54
         --INSERT INTO traceinfo (tracename, TimeIn, Col1, Col2, Col3, Col4, Col5, Step1, Step2, Step3, Step4) VALUES
         --('1620', GETDATE(), @c_StorerKey, @c_UserName, @c_PutAwayZone, @c_PickZone, @c_Facility, @c_Style, @c_SKU, @c_LOC, @n_RowCnt)
      END

      -- Search any pick task
      IF @n_RowCnt = 0
      BEGIN
         SELECT TOP 1
            @c_oFieled01   = PD.Loc,   
            @c_oFieled02   = PD.OrderKey,  
            @c_oFieled03   = PD.SKU,  
            @c_oFieled09   = PD.LOT,  
            @c_oFieled10   = PD.PickSlipNo 
         FROM RDT.RDTPickLock RPL WITH (NOLOCK)
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON (RPL.StorerKey = PD.StorerKey AND RPL.OrderKey = PD.OrderKey)
         JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
         WHERE RPL.StorerKey = @c_StorerKey
            AND RPL.Status < '9'
            AND RPL.AddWho = @c_UserName
            AND PD.Status = '0'
            AND (( ISNULL( @c_PutAwayZone, '') = 'ALL') OR ( L.PutAwayZone = @c_PutAwayZone))
            AND (( ISNULL(@c_PickZone, '') = '') OR ( L.PickZone = @c_PickZone))
            AND L.Facility = @c_Facility
            --AND L.LOC >= @c_LOC
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
         SELECT @n_RowCnt = @@ROWCOUNT
         
         -- No pick task
         IF @n_RowCnt = 0  
         BEGIN  
            GOTO Quit  
         END  
      END

   END
   
   SELECT 
      @c_oFieled04   = SKU.DESCR,
      @c_oFieled05   = SKU.Style,
      @c_oFieled06   = SKU.Color,
      @c_oFieled07   = SKU.Size,
      @c_oFieled08   = SKU.BUSR7
   FROM dbo.SKU SKU WITH (NOLOCK)
   WHERE SKU.Storerkey = @c_StorerKey
   AND   SKU.SKU = @c_oFieled03

   SELECT
      @c_oFieled11 = ExternOrderKey,
      @c_oFieled12 = ConsigneeKey
   FROM dbo.Orders WITH (NOLOCK)
   WHERE StorerKey = @c_StorerKey
   AND   OrderKey = @c_oFieled02

   Quit:
END

GO
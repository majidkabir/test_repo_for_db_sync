SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_1620GETTASK10                                   */  
/* Copyright      : MAERSK                                              */  
/*                                                                      */  
/* Purpose: Use Codelkup to determine pick seq                          */
/*                                                                      */
/* Called from: rdtfnc_Cluster_Pick                                     */  
/*                                                                      */  
/* Exceed version: 5.4                                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author      Purposes                                */  
/* 2023-06-04  1.0  James       WMS-22591. Created                      */  
/************************************************************************/  

CREATE   PROC [RDT].[rdt_1620GETTASK10] (  
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

   DECLARE @c_LoadKey      NVARCHAR( 10) = '',
           @n_PickBySeq    INT = 0
   
   DECLARE @c_Style         NVARCHAR( 20) = ''
   DECLARE @c_Size          NVARCHAR( 10) = ''
   DECLARE @c_LastSKU       NVARCHAR( 20) = ''
   DECLARE @n_PD_Qty        INT = 0
   DECLARE @n_Debug         INT = 0
   DECLARE @n_SkipSearch    INT = 0

   SELECT @c_LoadKey    = V_LoadKey,
          @c_UserName   = UserName
   FROM rdt.RDTMOBREC WITH (NOLOCK) 
   WHERE Mobile = @n_Mobile

   -- Check last picked sku.itemclass (material)
   SELECT TOP 1 @c_LastSKU = SKU
   FROM rdt.rdtPickLock WITH (NOLOCK)
   WHERE LoadKey = @c_LoadKey
   AND   AddWho = @c_UserName
   AND   [Status] = '5'
   ORDER BY RowRef DESC
   	
   IF @c_LastSKU <> ''
   BEGIN
   	SELECT @c_Style = Style
   	FROM dbo.SKU WITH (NOLOCK)
   	WHERE StorerKey = @c_StorerKey
   	AND   Sku = @c_LastSKU
   		
      -- Continue from last style and look for smallest size
      SELECT TOP 1
         @c_Size = SKU.Size
      FROM RDT.RDTPickLock RPL WITH (NOLOCK)
      JOIN dbo.PickDetail PD WITH (NOLOCK) ON (RPL.StorerKey = PD.StorerKey AND RPL.OrderKey = PD.OrderKey)
      JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
      JOIN dbo.SKU SKU WITH (NOLOCK) ON ( PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
      WHERE RPL.StorerKey = @c_StorerKey
         AND RPL.Status < '9'
         AND RPL.AddWho = @c_UserName
         AND PD.Status = '0'
         AND (( ISNULL( @c_PutAwayZone, '') = 'ALL') OR ( L.PutAwayZone = @c_PutAwayZone))
         AND (( ISNULL(@c_PickZone, '') = '') OR ( L.PickZone = @c_PickZone))
         AND L.Facility = @c_Facility
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
      ORDER BY SKU.Size
         
      -- If still got same size to continue pick
      IF ISNULL( @c_Size, '') <> ''
         SET @n_SkipSearch = 1
   END

   IF @n_SkipSearch = 0
   BEGIN
      -- Look for smallest style
      SELECT TOP 1
         @c_Style = SKU.Style
      FROM RDT.RDTPickLock RPL WITH (NOLOCK)
      JOIN dbo.PickDetail PD WITH (NOLOCK) ON (RPL.StorerKey = PD.StorerKey AND RPL.OrderKey = PD.OrderKey)
      JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
      JOIN dbo.SKU SKU WITH (NOLOCK) ON ( PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
      WHERE RPL.StorerKey = @c_StorerKey
         AND RPL.Status < '9'
         AND RPL.AddWho = @c_UserName
         AND PD.Status = '0'
         AND (( ISNULL( @c_PutAwayZone, '') = 'ALL') OR ( L.PutAwayZone = @c_PutAwayZone))
         AND (( ISNULL(@c_PickZone, '') = '') OR ( L.PickZone = @c_PickZone))
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
      ORDER BY SKU.Style

      IF @n_Debug = 1
         SELECT @c_Style '@c_Style'

      -- Look for smallest size (SKU.Busr6)
      SELECT TOP 1
         @c_Size = SKU.Size
      FROM RDT.RDTPickLock RPL WITH (NOLOCK)
      JOIN dbo.PickDetail PD WITH (NOLOCK) ON (RPL.StorerKey = PD.StorerKey AND RPL.OrderKey = PD.OrderKey)
      JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
      JOIN dbo.SKU SKU WITH (NOLOCK) ON ( PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
      JOIN dbo.CODELKUP CLK WITH (NOLOCK) ON ( SKU.Size = CLK.Code AND SKU.StorerKey = CLK.Storerkey)
      WHERE RPL.StorerKey = @c_StorerKey
         AND RPL.Status < '9'
         AND RPL.AddWho = @c_UserName
         AND PD.Status = '0'
         AND (( ISNULL( @c_PutAwayZone, '') = 'ALL') OR ( L.PutAwayZone = @c_PutAwayZone))
         AND (( ISNULL(@c_PickZone, '') = '') OR ( L.PickZone = @c_PickZone))
         AND L.Facility = @c_Facility
         AND SKU.Style = @c_Style
         AND CLK.LISTNAME = 'PUMASIZESQ'
         AND CLK.Storerkey = @c_StorerKey
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
      ORDER BY CLK.Short

      
      IF @n_Debug = 1
         SELECT @c_Size '@c_Size'
   END
   
   SELECT TOP 1
      @c_oFieled01 = PD.Loc,
      @c_oFieled02 = PD.OrderKey,
      @c_oFieled03 = PD.SKU,
      @c_oFieled09 = PD.LOT,
      @c_oFieled10 = PD.PickSlipNo
   FROM RDT.RDTPickLock RPL WITH (NOLOCK)
   JOIN dbo.PickDetail PD WITH (NOLOCK) ON (RPL.StorerKey = PD.StorerKey AND RPL.OrderKey = PD.OrderKey)
   JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
   JOIN dbo.SKU SKU WITH (NOLOCK) ON ( PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
   WHERE RPL.StorerKey = @c_StorerKey
      AND RPL.Status < '9'
      AND RPL.AddWho = @c_UserName
      AND PD.Status = '0'
      AND (( ISNULL( @c_PutAwayZone, '') = 'ALL') OR ( L.PutAwayZone = @c_PutAwayZone))
      AND (( ISNULL(@c_PickZone, '') = '') OR ( L.PickZone = @c_PickZone))
      AND L.Facility = @c_Facility
      AND SKU.Style = @c_Style
      AND SKU.Size = @c_Size
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
   GROUP BY L.LogicalLocation, PD.Loc, PD.OrderKey, PD.SKU, PD.LOT, PD.PickSlipNo
   ORDER BY L.LogicalLocation, PD.LOC, PD.SKU, PD.OrderKey    
      
   IF @@ROWCOUNT = 0  
   BEGIN  
      SET @c_oFieled02 = ''  
      GOTO Quit  
   END  

   SELECT @c_oFieled04 = SKU.DESCR,
      @c_oFieled05 = SKU.Style,
      @c_oFieled06 = SKU.Color,
      @c_oFieled07 = SKU.Size,
      @c_oFieled08 = SKU.BUSR7
   FROM dbo.SKU SKU WITH (NOLOCK)
   WHERE SKU.Storerkey = @c_StorerKey
   AND   SKU.SKU = @c_oFieled03

   SELECT
      @c_oFieled11 = ExternOrderKey,
      @c_oFieled12 = ConsigneeKey
   FROM dbo.Orders WITH (NOLOCK)
   WHERE StorerKey = @c_StorerKey
   AND   OrderKey = @c_oFieled02

   SELECT
      @c_oFieled13 = Lottable02,
      @c_oFieled14 = Lottable04
   FROM dbo.LOTATTRIBUTE WITH (NOLOCK)
   WHERE Lot = @c_oFieled09
   
   Quit:
END 

GO